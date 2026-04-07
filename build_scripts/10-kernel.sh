#!/usr/bin/env bash

set -ouex pipefail

shopt -s nullglob

# disable rpm/dracut kernel hooks
pushd /usr/lib/kernel/install.d
printf '%s\n' '#!/bin/sh' 'exit 0' > 05-rpmostree.install
printf '%s\n' '#!/bin/sh' 'exit 0' > 50-dracut.install
chmod +x  05-rpmostree.install 50-dracut.install
popd

# remove stock kernels and modules
for pkg in kernel kernel-core kernel-modules kernel-modules-core; do
  rpm --erase $pkg --nodeps
done

# install and lock cachy kernel
packages=(
  kernel-cachyos-lto
  kernel-cachyos-lto-core
  kernel-cachyos-lto-devel-matched
  kernel-cachyos-lto-modules
)
rm -rf "/usr/lib/modules/$(ls /usr/lib/modules | head -n1)"
dnf5 -y install "${packages[@]}"
dnf5 versionlock add "${packages[@]}"
rm -rf /boot/*
