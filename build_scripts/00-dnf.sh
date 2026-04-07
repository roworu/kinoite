#!/usr/bin/env bash

set -ouex pipefail

shopt -s nullglob

dnf5 -y install dnf5-plugins

echo -n "max_parallel_downloads=10" >>/etc/dnf/dnf.conf

dnf5 -y copr enable bieszczaders/kernel-cachyos-lto "fedora-${FEDORA_VERSION}-x86_64"
dnf5 -y copr enable bieszczaders/kernel-cachyos-addons "fedora-${FEDORA_VERSION}-x86_64"

# Keep Fedora kernel packages from replacing Cachy kernel during upgrades.
dnf5 -y config-manager setopt "*fedora*".exclude="kernel-core-* kernel-modules-* kernel-uki-virt-*"
dnf5 -y config-manager setopt "*updates*".exclude="kernel-core-* kernel-modules-* kernel-uki-virt-*"

# cli tools
# dnf5 -y install zsh fastfetch

# virtualization tools (virt manager, virt viewer, etc.)
# dnf5 -y install @virtualization

# flatpak setup
# flatpak remote-add --if-not-exists --system flathub /etc/flatpak/remotes.d/flathub.flatpakrepo
# flatpak remote-modify --system --enable flathub
