#!/usr/bin/env bash
echo "::group:: ===$(basename "$0")==="

set -ouex pipefail

# swap system firefox to flatpak version
dnf5 -y remove firefox firefox-langpacks
flatpak install --noninteractive --system flathub org.mozilla.firefox

# remove some apps from start menu
rm -vf /usr/share/applications/htop.desktop
rm -vf /usr/share/applications/nvtop.desktop