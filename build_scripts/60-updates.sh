#!/usr/bin/env bash

set -ouex pipefail

curl -fsSL https://dl.flathub.org/repo/flathub.flatpakrepo -o /etc/flatpak/remotes.d/flathub.flatpakrepo

###
### disable auto-updates
###

if systemctl list-unit-files rpm-ostreed-automatic.timer &>/dev/null; then
	systemctl disable rpm-ostreed-automatic.timer
fi

if systemctl list-unit-files flatpak-system-update.timer &>/dev/null; then
	systemctl disable flatpak-system-update.timer
fi

if systemctl --global list-unit-files flatpak-user-update.timer &>/dev/null; then
	systemctl --global disable flatpak-user-update.timer
fi

# kctl update checker from system_files/base/usr/lib/systemd/user/kctl-update-notify.timer
systemctl --global enable kctl-update-notify.timer
