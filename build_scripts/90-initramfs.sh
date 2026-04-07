#!/usr/bin/env bash

echo "::group:: ===$(basename "$0")==="

set -ouex pipefail

# 1) detect kernel version and paths
KVER=$(ls /usr/lib/modules | head -n1)
KIMAGE="/usr/lib/modules/$KVER/vmlinuz"
SIGN_DIR="/secureboot"

# 2) sign kernel + modules
sign_kernel_and_modules() {
  # install required tools
  dnf5 -y install sbsigntools

  # sign kernel image
  sbsign \
    --key "$SIGN_DIR/MOK.key" \
    --cert "$SIGN_DIR/MOK.pem" \
    --output "${KIMAGE}.signed" \
    "$KIMAGE"

  mv "${KIMAGE}.signed" "$KIMAGE"

  # sign all kernel modules
  find "/lib/modules/$KVER" -type f -name '*.ko.xz' -print0 | while IFS= read -r -d '' comp; do
    uncompressed="${comp%.xz}"

    # 1) decompress module
    if xz -d --keep "$comp"; then
      echo "Decompressed $comp → $uncompressed"
    else
      echo "Warning: failed to decompress $comp, skipping"
      continue
    fi

    # 2) sign module (don't fail whole script if one module fails)
    /usr/src/kernels/"$KVER"/scripts/sign-file \
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
  echo "Building initramfs for kernel version: $KVER"

  # sanity check
  if [ ! -d "/usr/lib/modules/$KVER" ]; then
    echo "Error: modules missing for kernel $KVER"
    exit 1
  fi

  # generate module dependencies
  depmod -a "$KVER"

  # dracut build
  export DRACUT_NO_XATTR=1
  /usr/bin/dracut \
    --no-hostonly \
    --kver "$KVER" \
    --reproducible \
    --zstd -v \
    --add ostree \
    -f "/usr/lib/modules/$KVER/initramfs.img"

  # secure permissions
  chmod 0600 "/usr/lib/modules/$KVER/initramfs.img"
}

build_initramfs
sign_kernel_and_modules
