#!/usr/bin/env bash

echo "::group:: ===$(basename "$0")==="

set -ouex pipefail
shopt -s nullglob

###
###  dnf
###

FEDORA_VERSION="$(rpm -E %fedora)"
dnf5 -y copr enable bieszczaders/kernel-cachyos-lto "fedora-${FEDORA_VERSION}-x86_64"
dnf5 -y copr enable bieszczaders/kernel-cachyos-addons "fedora-${FEDORA_VERSION}-x86_64"

# Keep Fedora kernel packages from replacing Cachy kernel during upgrades.
dnf5 -y config-manager setopt "*fedora*".exclude="kernel-core-* kernel-modules-* kernel-uki-virt-*"
dnf5 -y config-manager setopt "*updates*".exclude="kernel-core-* kernel-modules-* kernel-uki-virt-*"

# shell setup
dnf5 -y install zsh fastfetch

ZSH_PATH=/usr/bin/zsh

grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" >> /etc/shells

if grep -q '^SHELL=' /etc/default/useradd; then
  sed -i "s|^SHELL=.*|SHELL=${ZSH_PATH}|" /etc/default/useradd
else
  echo "SHELL=${ZSH_PATH}" >> /etc/default/useradd
fi

# virtualization tools, for ui install virt-manager from flatpak
dnf5 -y install qemu-kvm libvirt virt-install guestfs-tools

# flatpak setup
flatpak remote-add --if-not-exists --system flathub /etc/flatpak/remotes.d/flathub.flatpakrepo
flatpak remote-modify --system --enable flathub

###
### image info
###

DATE=$(date +%Y%m%d)

sed -i -f - /usr/lib/os-release <<EOF
s|^NAME=.*|NAME=\"kyawthuite\"|
s|^ID=.*|ID=\"kyawthuite\"|
s|^VERSION=.*|VERSION=\"${FEDORA_VERSION}.${DATE}\"|
s|^PRETTY_NAME=.*|PRETTY_NAME=\"kyawthuite ${FEDORA_VERSION}.${DATE}\"|
s|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME="kyawthuite"|

EOF

###
### kernel install
###

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

###
### services
###

system_services=(
  podman.socket
  systemd-resolved.service
  libvirtd.service
)

user_services=(
  podman.socket
)

mask_services=(
  flatpak-add-fedora-repos.service
  systemd-remount-fs.service
  # speed up boot time
  NetworkManager-wait-online.service
  # to not mess with custom kernel installation
  akmods-keygen.target
  akmods-keygen@akmods-keygen.service
  # disable automatic updates (both timers and services)
  bootc-fetch-apply-updates.timer
  rpm-ostree-automatic.timer
  bootc-fetch-apply-updates.service
  rpm-ostree-automatic.service
)

# enable/disable system services
systemctl enable "${system_services[@]}"
systemctl mask "${mask_services[@]}"
systemctl --global enable "${user_services[@]}"

preset_file="/usr/lib/systemd/system-preset/01-kyawthuite.preset"
touch "$preset_file"
for service in "${system_services[@]}"; do
  echo "enable $service" >> "$preset_file"
done

# enable user services
mkdir -p "/etc/systemd/user-preset/"
preset_file="/etc/systemd/user-preset/01-kyawthuite.preset"
touch "$preset_file"
for service in "${user_services[@]}"; do
  echo "enable $service" >> "$preset_file"
done

systemctl --global preset-all
