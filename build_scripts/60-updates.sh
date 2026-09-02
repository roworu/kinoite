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
