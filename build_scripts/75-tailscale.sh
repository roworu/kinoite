#!/usr/bin/env bash

set -ouex pipefail

# install tailscale, keep disabled;
# user enables with
# systemctl enable --now tailscaled

dnf5 -y config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
dnf5 -y install tailscale
rm -fv /etc/yum.repos.d/tailscale.repo
systemctl disable tailscaled.service

# disable extra logging
printf '%s\n' 'TS_NO_LOGS_NO_SUPPORT=true' >>/etc/default/tailscaled
