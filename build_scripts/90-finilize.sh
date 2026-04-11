#!/usr/bin/env bash

set -ouex pipefail

# 1) detect kernel version and paths
KERNEL_VERSION=$(ls /usr/lib/modules | head -n1)
KERNEL_IMAGE="/usr/lib/modules/$KERNEL_VERSION/vmlinuz"
SIGN_DIR="/secureboot"

# 2) sign kernel + modules
sign_kernel_and_modules() {
  # install required tools
  dnf5 -y install sbsigntools

  # sign kernel image
  sbsign \
    --key "$SIGN_DIR/MOK.key" \
    --cert "$SIGN_DIR/MOK.pem" \
    --output "${KERNEL_IMAGE}.signed" \
    "$KERNEL_IMAGE"

  mv "${KERNEL_IMAGE}.signed" "$KERNEL_IMAGE"

  # sign all kernel modules
  find "/lib/modules/$KERNEL_VERSION" -type f -name '*.ko.xz' -print0 | while IFS= read -r -d '' comp; do
    uncompressed="${comp%.xz}"

    # 1) decompress module
    if xz -d --keep "$comp"; then
      echo "Decompressed $comp → $uncompressed"
    else
      echo "Warning: failed to decompress $comp, skipping"
      continue
    fi

    # 2) sign module (don't fail whole script if one module fails)
    /usr/src/kernels/"$KERNEL_VERSION"/scripts/sign-file \
      sha512 "$SIGN_DIR/MOK.key" "$SIGN_DIR/MOK.pem" "$uncompressed" || true

    # 3) cleanup compressed original
    rm -f "$comp"

    # 4) recompress
    if xz -z "$uncompressed"; then
      echo "Recompressed and signed $uncompressed"
    else
      echo "Warning: failed to recompress $uncompressed"
    fi
  done

  # remove private key after signing
  rm -f "$SIGN_DIR/MOK.key"
}

# 3) build initramfs
build_initramfs() {
  echo "Building initramfs for kernel version: $KERNEL_VERSION"

  # sanity check
  if [ ! -d "/usr/lib/modules/$KERNEL_VERSION" ]; then
    echo "Error: modules missing for kernel $KERNEL_VERSION"
    exit 1
  fi

  # generate module dependencies
  depmod -a "$KERNEL_VERSION"

  # dracut build
  export DRACUT_NO_XATTR=1
  /usr/bin/dracut \
    --no-hostonly \
    --kver "$KERNEL_VERSION" \
    --reproducible \
    --zstd -v \
    --add ostree \
    -f "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"

  chmod 0600 "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"
}

# 4) cleanup final image
cleanup() {
    find /etc/yum.repos.d/ -maxdepth 1 -type f -name '*.repo' ! -name 'fedora.repo' ! -name 'fedora-updates.repo' ! -name 'fedora-updates-testing.repo' -exec rm -f {} +
    rm -rfv /tmp/*
    rm -rfv /var/log/dnf5.log
}

build_initramfs
sign_kernel_and_modules
cleanup