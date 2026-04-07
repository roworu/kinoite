#!/usr/bin/env bash

set -ouex pipefail

dnf5 -y copr enable bieszczaders/kernel-cachyos-lto
dnf5 -y copr enable bieszczaders/kernel-cachyos-addons

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

rm -rf /usr/lib/modules/*
rm -rf /boot/*

# install and lock cachy kernel
kernel_packages=(
    kernel-cachyos-lto
    kernel-cachyos-lto-core
    kernel-cachyos-lto-devel-matched
    kernel-cachyos-lto-modules
)
dnf5 -y install "${packages[@]}"
dnf5 versionlock add "${packages[@]}"

# upgrade image
dnf5 -y distro-sync
