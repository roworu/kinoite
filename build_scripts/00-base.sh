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
### nvidia driver + kernel module rebuild (kinoite-nvidia flavor only)
###

KERNEL_VERSION=$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' -quit)

if [ -f /usr/lib/dracut/dracut.conf.d/99-nvidia.conf ]; then
	dnf5 -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-nvidia.repo

	dnf5 -y install akmods
	# akmod-nvidia's %post scriptlet auto-triggers a build via akmodsbuild, which
	# refuses to run as root -- install it with scriptlets suppressed *before*
	# anything else's dependency resolution can pull it in normally (and thus
	# fail its %post as a side effect). The kmod is built explicitly below instead.
	dnf5 -y install --setopt=tsflags=noscripts akmod-nvidia
	dnf5 -y install nvidia-driver nvidia-driver-cuda xorg-x11-nvidia nvidia-settings nvidia-xconfig
	akmods --force --kernels "${KERNEL_VERSION}" --kmod nvidia

	# akmods reports build failures as a "[FAILED]" log line but still exits 0,
	# so a broken compile would otherwise ship silently with no nvidia module at all
	if ! find "/usr/lib/modules/${KERNEL_VERSION}" -iname 'nvidia.ko*' -print -quit | grep -q .; then
		echo "ERROR: nvidia kmod build failed for kernel ${KERNEL_VERSION}" >&2
		find /var/cache/akmods -iname '*.log' -exec sh -c 'echo "=== $1 ==="; cat "$1"' _ {} \; >&2
		exit 1
	fi

	rm -fv /etc/yum.repos.d/fedora-nvidia.repo
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

	fedora-flathub-remote
)

dnf5 -y group remove "${groups_to_remove[@]}"
dnf5 -y remove "${packages_to_remove[@]}"
