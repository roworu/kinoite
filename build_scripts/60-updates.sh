#!/usr/bin/env bash

set -ouex pipefail

###
### disable auto-updates
###

systemctl disable rpm-ostreed-automatic.timer
systemctl disable flatpak-system-update.timer

systemctl --global disable flatpak-user-update.timer

# kctl update checker from system_files/base/usr/lib/systemd/user/kctl-update-notify.timer
systemctl --global enable kctl-update-notify.timer

# drop fedora flatpak remote (flathub is the only supported remote)

mapfile -t fedora_flatpaks < <(flatpak list --system --app --columns=application,origin | awk -F'\t' '$2 == "fedora" {print $1}')
if [ "${#fedora_flatpaks[@]}" -gt 0 ]; then
	flatpak uninstall --system -y "${fedora_flatpaks[@]}"
fi

flatpak remote-delete fedora --system --force
