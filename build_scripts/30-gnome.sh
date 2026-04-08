#!/usr/bin/env bash
echo "::group:: ===$(basename "$0")==="

set -ouex pipefail

rm -vf /usr/share/applications/htop.desktop || true
rm -vf /usr/share/applications/nvtop.desktop || true