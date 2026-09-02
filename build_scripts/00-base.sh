#!/usr/bin/env bash

set -ouex pipefail
shopt -s nullglob

# Each RUN in the Containerfile gets its own fresh tmpfs mounts for /tmp and
# /var, which don't come up 1777 by default. akmods build step needs
# both writable to create its scratch/BUILD dirs, or it fails with
# "Permission denied" creating temp files
mkdir -p /var/tmp /tmp
chmod 1777 /var/tmp /tmp

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

mapfile -t stale_nvidia_kmods < <(rpm -qa --queryformat '%{NAME}\n' | grep -E '^kmod-nvidia(-|$)')
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

KERNEL_VERSION=$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' -quit)

if rpm -q nvidia-driver-libs &>/dev/null; then
	sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/negativo17-fedora-nvidia.repo
	sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/nvidia-container-toolkit.repo

	dnf5 -y install akmods
	dnf5 -y install --setopt=tsflags=noscripts akmod-nvidia
	akmods --force --kernels "${KERNEL_VERSION}" --kmod nvidia

	# akmods reports build failures as a "[FAILED]" log line but still exits 0,
	# so a broken compile would otherwise ship silently with no nvidia module at all
	if ! find "/usr/lib/modules/${KERNEL_VERSION}" -iname 'nvidia.ko*' -print -quit | grep -q .; then
		echo "ERROR: nvidia kmod build failed for kernel ${KERNEL_VERSION}" >&2
		find /var/cache/akmods -iname '*.log' -exec sh -c 'echo "=== $1 ==="; cat "$1"' _ {} \; >&2
		exit 1
	fi
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

    # users should install browser of choice using flatpak + discover
	firefox firefox-langpacks 
)

dnf5 -y group remove "${groups_to_remove[@]}"
dnf5 -y remove "${packages_to_remove[@]}"
