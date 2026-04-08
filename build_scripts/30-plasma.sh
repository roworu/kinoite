#!/usr/bin/env bash

echo "::group:: ===$(basename "$0")==="

set -ouex pipefail

# swap system firefox to flatpak version
dnf5 -y remove firefox firefox-langpacks
flatpak install -y flathub org.mozilla.firefox

# remove update tray icon
rm /etc/xdg/autostart/org.kde.discover.notifier.desktop || true

rm -vf /usr/share/applications/org.kde.kdebugsettings.desktop || true
rm -vf /usr/share/applications/org.kde.khelpcenter.desktop || true
rm -vf /usr/share/applications/org.kde.plasma-welcome.desktop || true
rm -vf /usr/share/applications/htop.desktop || true
rm -vf /usr/share/applications/nvtop.desktop || true

# wallpapers
ln -sf /usr/share/wallpapers/kw-wallpaper.jxl /usr/share/backgrounds/default.jxl
ln -sf /usr/share/wallpapers/kw-wallpaper-darker.jxl /usr/share/backgrounds/default-dark.jxl
rm -f /usr/share/backgrounds/default.xml