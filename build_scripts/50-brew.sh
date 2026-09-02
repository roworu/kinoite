#!/usr/bin/env bash

set -ouex pipefail

systemctl enable brew-setup.service
echo 'HOMEBREW_NO_AUTO_UPDATE=1' >>/etc/environment
