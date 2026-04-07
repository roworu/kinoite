#!/usr/bin/env bash

set -ouex pipefail

dnf5 -y copr enable bieszczaders/kernel-cachyos-lto fedora-${FEDORA_VERSION}-x86_64
dnf5 -y copr enable bieszczaders/kernel-cachyos-addons fedora-${FEDORA_VERSION}-x86_64

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
dnf5 -y install "${kernel_packages[@]}"
dnf5 versionlock add "${kernel_packages[@]}"

# upgrade image
dnf5 -y distro-sync
