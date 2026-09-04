#!/usr/bin/env bash

set -ouex pipefail

KERNEL_VERSION=$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' -quit)

mkdir -p /var/tmp
chmod 1777 /var/tmp

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

version() {
	# add versions to /usr/lib/os-release so grub could use then
	[ -n "${IMAGE_VERSION:-}" ] || return 0

	sed -i \
		-e "s|^VERSION=.*|VERSION=\"${IMAGE_VERSION} (Kinoite)\"|" \
		-e "s|^PRETTY_NAME=.*|PRETTY_NAME=\"Fedora Linux ${IMAGE_VERSION} (Kinoite)\"|" \
		-e "s|^OSTREE_VERSION=.*|OSTREE_VERSION='${IMAGE_VERSION}'|" \
		/usr/lib/os-release
}

cleanup() {

	cleanup_packages=(
		kernel-cachyos-lto-devel-matched
	)

	if rpm -q nvidia-driver-libs &>/dev/null; then
		cleanup_packages+=(
			akmods
			akmod-nvidia
		)
	fi

	dnf5 -y remove "${cleanup_packages[@]}"
	dnf5 -y clean all

	rm -rfv /etc/yum.repos.d/*cachyos*
	rm -rfv /run/akmods /run/dnf /run/selinux-policy /tmp/*

	# from 00-base.sh kernel installation
	rm -fv /usr/lib/kernel/install.d/05-rpmostree.install
	rm -fv /usr/lib/kernel/install.d/50-dracut.install

}

version
build_initramfs
cleanup
