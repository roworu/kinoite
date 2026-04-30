#!/usr/bin/env bash

set -euo pipefail

###
### envs
###

qemu_pid=''
workdir=''
output_dir=''
serial_log=''
config_toml=''
ssh_key=''
ssh_pub=''
qcow2_image=''

###
### utility functions
###

log() {
  echo "[+] $*" >&2
}

die() {
  echo "[!] $*" >&2
  exit 1
}

cleanup() {
  if [[ -n "${qemu_pid}" ]] && kill -0 "${qemu_pid}" >/dev/null 2>&1; then
    kill "${qemu_pid}" || true
    wait "${qemu_pid}" || true
  fi

  [[ -n "${workdir}" ]] && rm -rf "${workdir}"
}

trap cleanup EXIT

###
### 1) prepare testing environment
###

prepare_env() {
  log "Preparing environment"

  workdir="$(mktemp -d)"
  output_dir="${workdir}/output"
  serial_log="${workdir}/serial.log"
  config_toml="${workdir}/config.toml"
  ssh_key="${workdir}/id_ed25519"
  ssh_pub="${ssh_key}.pub"

  mkdir -p "${output_dir}"

  # SSH key
  ssh-keygen -q -N '' -t ed25519 -f "${ssh_key}"

  cat > "${config_toml}" <<EOF
[[customizations.user]]
name = "integration"
password = "integration"
key = "$(cat "${ssh_pub}")"
groups = ["wheel"]
EOF
}

###
### 2) build testing vm image
###

build_image() {
  log "Loading container image"

  local loaded_image
  loaded_image="$(podman load -i /input/raw-img.tar | awk -F': ' '/Loaded image:/ {print $2}' | tail -n1)"

  [[ -z "${loaded_image}" ]] && die "Failed to load image archive"

  local candidate_image="test-target:latest"
  podman tag "${loaded_image}" "${candidate_image}"

  log "Building qcow2 image"

  podman run \
    --rm \
    --privileged \
    --pull=always \
    -v "${config_toml}:/config.toml:ro" \
    -v "${output_dir}:/output" \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    -v /run/containers/storage:/run/containers/storage \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type qcow2 \
    --rootfs btrfs \
    --use-librepo=True \
    --config /config.toml \
    "${candidate_image}"

  qcow2_image="${output_dir}/qcow2/disk.qcow2"
  [[ -f "${qcow2_image}" ]] || die "qcow2 image not produced"
}

###
### 3) start testing vm
###

start_vm() {
  log "Starting VM"

  local ovmf_code='/usr/share/edk2/ovmf/OVMF_CODE.fd'
  [[ -f "$ovmf_code" ]] || ovmf_code='/usr/share/OVMF/OVMF_CODE.fd'
  [[ -f "$ovmf_code" ]] || die "OVMF firmware not found"

  qemu-system-x86_64 \
    -name "integration-vm" \
    -machine q35 \
    -accel tcg,thread=multi \
    -cpu max \
    -smp 4 \
    -m 8192 \
    -bios "$ovmf_code" \
    -display none \
    -device virtio-net-pci,netdev=n1 \
    -netdev user,id=n1,hostfwd=tcp::2222-:22 \
    -drive if=virtio,format=qcow2,file="${qcow2_image}" \
    -serial "file:${serial_log}" \
    -daemonize \
    -pidfile "${workdir}/qemu.pid"

  qemu_pid="$(cat "${workdir}/qemu.pid")"
}

###
### 4) wait for ssh to become ready
###

wait_for_ssh() {
  log "Waiting for SSH"

  local ssh_opts=(
    -i "${ssh_key}"
    -o BatchMode=yes
    -o ConnectTimeout=5
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -p 2222
  )

  for _ in $(seq 1 120); do
    if ssh "${ssh_opts[@]}" integration@127.0.0.1 true >/dev/null 2>&1; then
      log "SSH is ready"
      return 0
    fi
    sleep 5
  done

  die "SSH did not become ready"
}

###
### 5) run tests
###

run_tests() {
  local flavor="$1"

  log "Running tests for flavor=${flavor}"

  local expected_packages=()

  case "${flavor}" in
    nvidia)
      expected_packages=(nvidia-driver kernel-cachyos-lto)
      ;;
    *)
      expected_packages=(kernel-cachyos-lto)
      ;;
  esac

  local expected_arg
  expected_arg="$(IFS=,; echo "${expected_packages[*]}")"

ssh \
  -i "${ssh_key}" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -p 2222 \
  integration@127.0.0.1 \
  "EXPECTED_PACKAGES='${expected_arg}' bash -s" <<'EOF'

set -euo pipefail

log() {
  echo "[guest] $*"
}

IFS=',' read -r -a expected_packages <<< "${EXPECTED_PACKAGES}"

has_package() {
  dnf5 -q list installed "$1" >/dev/null 2>&1
}

check_packages() {
  log "Checking expected packages"

  for pkg in "${expected_packages[@]}"; do
    if ! has_package "$pkg"; then
      echo "Missing package: $pkg" >&2
      exit 1
    fi
  done

}

check_graphical() {
  log "Waiting for graphical target"

  for _ in $(seq 1 60); do
    if systemctl is-active --quiet display-manager.service &&
       systemctl is-active --quiet graphical.target &&
       pgrep -x sddm >/dev/null; then
      log "Graphical session is up"
      return 0
    fi
    sleep 5
  done

  log "Graphical target failed, dumping diagnostics"
  systemctl --no-pager --failed || true
  systemctl status display-manager.service --no-pager || true

  exit 1
}

check_packages
check_graphical

EOF
}

###
### entrypoint
###

main() {
  [[ "$#" -eq 1 ]] || die "usage: $0 <flavor>"

  local flavor="$1"

  prepare_env
  build_image
  start_vm
  wait_for_ssh
  run_tests "${flavor}"

  log "All tests passed"
}

main "$@"
