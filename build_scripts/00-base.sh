#!/usr/bin/env bash

set -ouex pipefail
shopt -s nullglob

###
### base packages
###

base_packages=(
	cmake
	ccache
	gcc
	gcc-c++
	openblas
)
dnf5 -y install "${base_packages[@]}"

###
###  kernel install
###

FEDORA_VERSION="$(rpm -E %fedora)"
dnf5 -y copr enable bieszczaders/kernel-cachyos-lto "fedora-${FEDORA_VERSION}-x86_64"

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


dnf5 -y copr enable bieszczaders/kernel-cachyos-addons "fedora-${FEDORA_VERSION}-x86_64"
dnf5 -y install ananicy-cpp
systemctl enable ananicy-cpp.service

###
### nvidia drivers install
###

install_nvidia_drivers() {

	nvidia_driver_packages=(
		nvidia-driver-cuda
		cuda-devel
		libnvidia-fbc
		libva-nvidia-driver
		nvidia-driver
		nvidia-modprobe
		nvidia-persistenced
		nvidia-settings
	)
	mkdir -p /var/tmp
	chmod 1777 /var/tmp

	KERNEL_VERSION=$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' -quit)

	dnf5 config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-nvidia.repo
	dnf5 config-manager setopt fedora-nvidia.enabled=0
	sed -i '/^enabled=/a\priority=90' /etc/yum.repos.d/fedora-nvidia.repo

	# install and build akmods manually
	dnf5 -y install akmods
	dnf5 -y install --setopt=tsflags=noscripts --enablerepo=fedora-nvidia akmod-nvidia
	akmods --force --kernels "${KERNEL_VERSION}" --kmod "nvidia"
	dnf5 -y install --enablerepo=fedora-nvidia "${nvidia_driver_packages[@]}"
	dnf5 versionlock add "${nvidia_driver_packages[@]}"

	# add nvidia-container
	# FIXME
	# remove certs hadnling once https://github.com/NVIDIA/libnvidia-container/issues/367 is fixed

	dnf5 config-manager addrepo --from-repofile=https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo
	dnf5 config-manager setopt nvidia-container-toolkit.sslcacert=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem # tmp
	dnf5 config-manager setopt nvidia-container-toolkit.enabled=0
	dnf5 config-manager setopt nvidia-container-toolkit.gpgcheck=1
	dnf5 -y install --enablerepo=nvidia-container-toolkit nvidia-container-toolkit

}

if [ "${INSTALL_NVIDIA:-}" = "TRUE" ]; then
	install_nvidia_drivers
fi
