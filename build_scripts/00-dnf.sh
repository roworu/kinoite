#!/usr/bin/env bash

set -ouex pipefail

echo -n "max_parallel_downloads=10" >>/etc/dnf/dnf.conf

## copr
# to not update overwrite cachy kernel with default one during updates:
dnf5 -y config-manager setopt "*fedora*".exclude="kernel-core-* kernel-modules-* kernel-uki-virt-*"
dnf5 -y config-manager setopt "*updates*".exclude="kernel-core-* kernel-modules-* kernel-uki-virt-*"
dnf5 -y config-manager setopt "*fedora-multimedia*".exclude="akmod-nvidia kmod-nvidia"

# cli tools
dnf5 -y install zsh fastfetch

# virtualization tools (virt manager, virt viewer, etc.)
dnf5 -y install @virtualization

# flatpak setup
flatpak remote-add --if-not-exists --system flathub /etc/flatpak/remotes.d/flathub.flatpakrepo
flatpak remote-modify --system --enable flathub
