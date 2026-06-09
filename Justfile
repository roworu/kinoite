# taken from https://github.com/ublue-os/image-template/blob/main/Justfile

export image_name := env("IMAGE_NAME", "kinoite")
export default_tag := env("DEFAULT_TAG", "latest")
export bib_image := env("BIB_IMAGE", "quay.io/centos-bootc/bootc-image-builder:latest")
export fedora_version := env("FEDORA_VERSION", "44")
export testing_env := env("TESTING_ENVIRONMENT", "FALSE")
export vm_gpu := env("VM_GPU", "TRUE")

alias build-vm := build-qcow2
alias rebuild-vm := rebuild-qcow2
alias run-vm := run-vm-qcow2

[private]
default:
    @just --list

###
### Syntax
###

# Check Just syntax across all .just files and Justfile
[group('Just')]
check:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
        echo "Checking syntax: $file"
        just --unstable --fmt --check -f "$file"
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just syntax across all .just files and Justfile
[group('Just')]
fix:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
        echo "Fixing syntax: $file"
        just --unstable --fmt -f "$file"
    done
    echo "Fixing syntax: Justfile"
    just --unstable --fmt -f Justfile || { exit 1; }

###
### Utility
###

# Remove build artifacts and output directory
[group('Utility')]
clean:
    #!/usr/bin/bash
    set -eoux pipefail
    touch _build
    find *_build* -exec rm -rf {} \;
    rm -f previous.manifest.json changelog.md output.env
    rm -rf output/

# Run a command with sudo if not already root
[group('Utility')]
[private]
sudoif command *args:
    #!/usr/bin/bash
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    sudoif {{ command }} {{ args }}

# Lint shell scripts with shellcheck
[group('Utility')]
lint:
    #!/usr/bin/env bash
    set -eoux pipefail
    if ! command -v shellcheck &> /dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    /usr/bin/find . -iname "*.sh" -type f -exec shellcheck "{}" ';'

# Format shell scripts with shfmt
[group('Utility')]
format:
    #!/usr/bin/env bash
    set -eoux pipefail
    if ! command -v shfmt &> /dev/null; then
        echo "shfmt could not be found. Please install it."
        exit 1
    fi
    /usr/bin/find . -iname "*.sh" -type f -exec shfmt --write "{}" ';'

###
### Build Container Image
###

# Build the container image (always pulls latest base)
[group('Build Container Image')]
build $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail

    BUILD_ARGS=()
    if [[ -z "$(git status -s)" ]]; then
        BUILD_ARGS+=("--build-arg" "SHA_HEAD_SHORT=$(git rev-parse --short HEAD)")
    fi

    podman build \
        "${BUILD_ARGS[@]}" \
        --pull=newer \
        --build-arg FEDORA_VERSION="${fedora_version}" \
        --build-arg TESTING_ENVIRONMENT="${testing_env}" \
        --target "${target_image}" \
        --tag "${target_image}:${tag}" \
        .

###
### Build VM Image
###

# Ensure a locally-built image is available to rootful podman (copies or pulls as needed)
[private]
_rootful_load_image $target_image=image_name $tag=default_tag:
    #!/usr/bin/bash
    set -eoux pipefail

    if [[ -n "${SUDO_USER:-}" || "${UID}" -eq "0" ]]; then
        echo "Already root or running under sudo, no need to load image from user podman."
        exit 0
    fi

    set +e
    resolved_tag=$(podman inspect -t image "${target_image}:${tag}" | jq -r '.[].RepoTags.[0]')
    return_code=$?
    set -e

    USER_IMG_ID=$(podman images --filter reference="${target_image}:${tag}" --format "{{{{.ID}}}}")

    if [[ $return_code -eq 0 ]]; then
        ID=$(just sudoif podman images --filter reference="${target_image}:${tag}" --format "{{{{.ID}}}}")
        if [[ "$ID" != "$USER_IMG_ID" ]]; then
            COPYTMP=$(mktemp -p "${PWD}" -d -t _build_podman_scp.XXXXXXXXXX)
            just sudoif TMPDIR="${COPYTMP}" podman image scp "${UID}@localhost::${target_image}:${tag}" "root@localhost::${target_image}:${tag}"
            rm -rf "${COPYTMP}"
        fi
    else
        just sudoif podman pull "${target_image}:${tag}"
    fi

# Convert a container image to a bootable disk image via bootc-image-builder
[private]
_build-bib $target_image $tag $type $config: (_rootful_load_image target_image tag)
    #!/usr/bin/env bash
    set -euo pipefail

    BUILDTMP=$(mktemp -p "${PWD}" -d -t _build-bib.XXXXXXXXXX)

    sudo podman run \
        --rm \
        -it \
        --privileged \
        --pull=newer \
        --net=host \
        --security-opt label=type:unconfined_t \
        -v "$(pwd)/${config}:/config.toml:ro" \
        -v "${BUILDTMP}:/output" \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        "${bib_image}" \
        --type "${type}" \
        --use-librepo=True \
        --rootfs=btrfs \
        "${target_image}:${tag}"

    mkdir -p output
    sudo mv -f "${BUILDTMP}"/* output/
    sudo rmdir "${BUILDTMP}"
    sudo chown -R "${USER}:${USER}" output/

# Build container image then convert to bootable disk image
[private]
_rebuild-bib $target_image $tag $type $config: (build target_image tag) && (_build-bib target_image tag type config)

# Build a qcow2 VM image from the current container image
[group('Build VM Image')]
build-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "qcow2" "disk_config/disk.toml")

# Rebuild container image then build qcow2 VM image
[group('Build VM Image')]
rebuild-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "qcow2" "disk_config/disk.toml")

###
### Run VM
###

# Run a VM image using qemu container (builds the image if not present)
[private]
_run-vm $target_image $tag $type $config:
    #!/usr/bin/bash
    set -eoux pipefail

    image_file="output/${type}/disk.${type}"
    if [[ "${type}" == iso ]]; then
        image_file="output/bootiso/install.iso"
    fi

    if [[ ! -f "${image_file}" ]]; then
        just "build-${type}" "${target_image}" "${tag}"
    fi

    port=8006
    while grep -q ":${port}" <<< "$(ss -tunalp)"; do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"

    run_args=(
        --rm --privileged
        --pull=newer
        --publish "127.0.0.1:${port}:8006"
        --publish "127.0.0.1:2222:22"
        --env "CPU_CORES=4"
        --env "RAM_SIZE=8G"
        --env "DISK_SIZE=64G"
        --env "TPM=Y"
    )

    case "${vm_gpu,,}" in
        1|true|yes|y)  run_args+=(--env "GPU=Y") ;;
        0|false|no|n)  ;;
        *)
            echo "Unsupported VM_GPU value: ${vm_gpu}" >&2
            exit 1
            ;;
    esac

    run_args+=(
        --device=/dev/kvm
        --volume "${PWD}/${image_file}:/boot.${type}"
    )

    (sleep 30 && xdg-open "http://localhost:${port}") &
    podman run "${run_args[@]}" docker.io/qemux/qemu

# Run the qcow2 VM (builds if not present)
[group('Run VM')]
run-vm-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "qcow2" "disk_config/disk.toml")
