#!/usr/bin/env bash

echo "::group:: ===$(basename "$0")==="

set -ouex pipefail

dnf5 -y remove firefox firefox-langpacks

# remove update tray icon
rm -vf /etc/xdg/autostart/org.kde.discover.notifier.desktop

# remove some apps from start menu
rm -vf /usr/share/applications/org.kde.kdebugsettings.desktop
rm -vf /usr/share/applications/org.kde.khelpcenter.desktop
rm -vf /usr/share/applications/org.kde.plasma-welcome.desktop
rm -vf /usr/share/applications/htop.desktop
rm -vf /usr/share/applications/nvtop.desktop

# wallpapers
# ln -sf /usr/share/wallpapers/kw-wallpaper.jxl /usr/share/backgrounds/default.jxl
# ln -sf /usr/share/wallpapers/kw-wallpaper-darker.jxl /usr/share/backgrounds/default-dark.jxl
# rm -f /usr/share/backgrounds/default.xml