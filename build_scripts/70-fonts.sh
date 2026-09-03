#!/usr/bin/env bash

set -ouex pipefail

dnf5 -y install --nogpgcheck --repofrompath "terra,https://repos.fyralabs.com/terra\$releasever" terra-release
dnf5 -y --setopt=terra.gpgcheck=0 install ubuntumono-nerd-fonts jetbrainsmono-nerd-fonts
dnf5 -y remove terra-release terra-gpg-keys

fc-cache -f
