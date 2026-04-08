#!/usr/bin/env bash

_log() {
    level="info"

    if [ "${1:-}" = "error" ]; then
        level="error"
        shift
    fi

    if [ "$level" = "error" ]; then
        color='\033[1;31m'   # red
    else
        color='\033[1;34m'   # blue
    fi

    printf "%b%s%b\n" "$color" "$*" '\033[0m'
}

_confirmation() {

    text="${1:-}"
    _log "$text"
    read -r ans
    case "$ans" in
      y|Y) exec sys-upgrade ;;
      *) echo "Aborted."; exit 0 ;;
    esac
}

sys-update() {
    _confirmation "This will just check for system updates, but not apply them. Continue? [y/N]: "
    _log "==> Checking bootc..."
    output=$(sudo bootc upgrade --check || true)

    if echo "$output" | grep -qi "update available"; then
        version=$(echo "$output" | awk -F': ' '/Version:/ {print $2}')
        if [[ -z "${version:-}" ]]; then
            _log error "Unable to determine bootc update version. Please run: sudo bootc upgrade --check"
            return 1
        fi
        _log "bootc update available: ${version}"
    else
        _log "bootc: up to date"
    fi

    _log "==> Checking flatpak..."
    flatpak_output=$(flatpak remote-ls --updates 2>&1)
    flatpak_status=$?
    if [[ $flatpak_status -ne 0 ]]; then
        _log error "Unable to check flatpak updates. Please run: flatpak remote-ls --updates"
        return 1
    fi
    flatpak_updates=$(printf '%s\n' "$flatpak_output" | wc -l | tr -d ' ')
    if [[ ! "$flatpak_updates" =~ ^[0-9]+$ ]]; then
        _log error "Unable to count flatpak updates. Please run: flatpak remote-ls --updates"
        return 1
    fi
    if [[ "$flatpak_updates" -eq 0 ]]; then
        _log "flatpak: no updates"
    else
        _log "flatpak updates: $flatpak_updates"
    fi

    _log "==> Checking brew..."
    if ! brew update >/dev/null 2>&1; then
        _log error "Unable to update brew metadata. Please run: brew update"
        return 1
    fi
    brew_output=$(brew outdated 2>&1)
    brew_status=$?
    if [[ $brew_status -ne 0 ]]; then
        _log error "Unable to count brew updates. Please run: brew outdated"
        return 1
    fi
    brew_updates=$(printf '%s\n' "$brew_output" | wc -l | tr -d ' ')
    if [[ ! "$brew_updates" =~ ^[0-9]+$ ]]; then
        _log error "Unable to count brew updates. Please run: brew outdated"
        return 1
    fi
    if [[ "$brew_updates" -eq 0 ]]; then
        _log "brew: no updates"
    else
        _log "brew updates: $brew_updates"
    fi
}

sys-upgrade() {

    _confirmation "This will check for system updates, and if any - immediatly apply them. Continue? [y/N]: "
    _log "==> Upgrading bootc..."
    sudo bootc upgrade

    _log "==> Upgrading flatpak..."
    flatpak update -y

    _log "==> Upgrading brew..."
    brew upgrade --force

    _log "==> Upgrade complete!"
}

sys-upgrade-reboot() {
    _confirmation "This will check for system updates, and if any - immediatly apply them, then reboot. Continue? [y/N]: "
    sys-upgrade
    _log "==> Rebooting..."
    sudo reboot
}

sys-cleanup() {
    _confirmation "This will cleanup unused brew and flatpak files. Continue? [y/N]: "
    _log "==> Cleaning flatpak unused runtimes..."
    flatpak uninstall --unused -y

    _log "==> Cleaning brew files..."
    brew cleanup

}

# to use it, call these functions directly from shell, like that:
# > sys-update
