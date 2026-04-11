#!/usr/bin/env bash

set -ouex pipefail
shopt -s nullglob

###
###  dnf
###

FEDORA_VERSION="$(rpm -E %fedora)"
dnf5 -y copr enable bieszczaders/kernel-cachyos-lto "fedora-${FEDORA_VERSION}-x86_64"
dnf5 -y copr enable bieszczaders/kernel-cachyos-addons "fedora-${FEDORA_VERSION}-x86_64"

dnf5 -y config-manager setopt "*fedora*".exclude="kernel-core-* kernel-modules-* kernel-uki-virt-*"
dnf5 -y config-manager setopt "*updates*".exclude="kernel-core-* kernel-modules-* kernel-uki-virt-*"

dnf5 -y install zsh git

###
### kernel install
###

pushd /usr/lib/kernel/install.d
printf '%s\n' '#!/bin/sh' 'exit 0' > 05-rpmostree.install
printf '%s\n' '#!/bin/sh' 'exit 0' > 50-dracut.install
chmod +x  05-rpmostree.install 50-dracut.install
popd

for pkg in kernel kernel-core kernel-modules kernel-modules-core; do
  dnf5 -y remove $pkg
done
rm -rf /usr/lib/modules/*
rm -rf /boot/*

# install and lock cachy kernel
packages=(
  kernel-cachyos-lto
  kernel-cachyos-lto-core
  kernel-cachyos-lto-devel-matched
  kernel-cachyos-lto-modules
)
dnf5 -y install "${packages[@]}"
dnf5 versionlock add "${packages[@]}"

dnf5 -y remove firefox firefox-langpacks \
    plasma-welcome plasma-drkonqi plasma-welcome-fedora plasma-discover-kns kcharselect

# remove update tray icon
rm -vf /etc/xdg/autostart/org.kde.discover.notifier.desktop

# remove some apps from start menu
rm -vf /usr/share/applications/org.kde.kdebugsettings.desktop
rm -vf /usr/share/applications/org.kde.khelpcenter.desktop
rm -vf /usr/share/applications/htop.desktop
rm -vf /usr/share/applications/nvtop.desktop
