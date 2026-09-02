#!/usr/bin/env bash

set -ouex pipefail
shopt -s nullglob

###
### kernel install
###

dnf5 -y copr enable bieszczaders/kernel-cachyos-lto

dnf5 -y config-manager setopt '*fedora*.exclude=kernel-core-* kernel-modules-* kernel-uki-virt-*'
dnf5 -y config-manager setopt '*updates*.exclude=kernel-core-* kernel-modules-* kernel-uki-virt-*'

pushd /usr/lib/kernel/install.d
printf '%s\n' '#!/bin/sh' 'exit 0' >05-rpmostree.install
printf '%s\n' '#!/bin/sh' 'exit 0' >50-dracut.install
chmod +x 05-rpmostree.install 50-dracut.install
popd

# drop any prebuilt out-of-tree kmod tied to the kernel we're about to remove
# (the upstream kinoite-nvidia base ships kmod-nvidia matched to its own kernel)
mapfile -t stale_nvidia_kmods < <(rpm -qa 'kmod-nvidia-*')
if [ "${#stale_nvidia_kmods[@]}" -gt 0 ]; then
	dnf5 -y remove "${stale_nvidia_kmods[@]}"
fi

for pkg in kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra kernel-uki-virt; do
	if rpm -q "$pkg" >/dev/null 2>&1; then
		dnf5 -y remove "$pkg"
	fi
done
find /usr/lib/modules -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
find /boot -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +

kernel_packages=(
	kernel-cachyos-lto
	kernel-cachyos-lto-core
	kernel-cachyos-lto-devel-matched
	kernel-cachyos-lto-modules

)

dnf5 -y install "${kernel_packages[@]}"
dnf5 versionlock add "${kernel_packages[@]}"

dnf5 -y copr enable bieszczaders/kernel-cachyos-addons
dnf5 -y install ananicy-cpp
systemctl enable ananicy-cpp.service

###
### nvidia kernel module rebuild (kinoite-nvidia flavor only)
###

# The kinoite-nvidia base image ships nvidia userspace + a kmod-nvidia
# prebuilt for its own kernel. That kmod is gone now (removed with the
# kernel above), so rebuild it from source against the CachyOS kernel using
# the negativo17-fedora-nvidia repo the base image already has configured.

KERNEL_VERSION=$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' -quit)

if rpm -q nvidia-driver &>/dev/null; then
	dnf5 -y install akmods
	dnf5 -y install --setopt=tsflags=noscripts --enablerepo=negativo17-fedora-nvidia akmod-nvidia
	akmods --force --kernels "${KERNEL_VERSION}" --kmod nvidia
fi

###
### minimize image
###

groups_to_remove=(
	libreoffice
)

packages_to_remove=(
	libreoffice-core
	kmahjongg kmines kpat
	akregator kmail headerthemeeditor ktn neochat pimdataexporter sieveeditor
	kmousetool kmouth im-chooser korganizer kaddressbook khelpcenter
	dragon elisa-player kamoso kolourpaint skanpage k3b gcdmaster qrca ktorrent
	kdeconnect nwg-panel mediawriter krusader digikam showfoto uuctl
	kleopatra kcharselect kde-connect plasma-welcome kdebugsettings
	kjournald gnome-abrt kfind cockpit-system
)

dnf5 -y group remove "${groups_to_remove[@]}"
dnf5 -y remove "${packages_to_remove[@]}"
