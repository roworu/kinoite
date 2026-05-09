from defaults import PLASMA_DE_PACKAGES, \
    XDG_DIRS

def test_graphical_target_is_default(ssh_command):
    result = ssh_command("systemctl get-default")
    assert result.returncode == 0, \
        f"Command returned bad returncode: {result.returncode}. Full response: {result}"

    assert result.stdout.strip() == "graphical.target", \
        f"Graphical.target not found as systemctl default. Full response {result.stdout}"


def test_display_manager_is_active(ssh_command):
    result = ssh_command("systemctl is-active display-manager.service")
    actual_state = result.stdout.strip()

    assert result.returncode == 0, \
        f"Command returned bad returncode: {result.returncode}. Full response: {result}"

    assert actual_state == "active", \
        f"display-manager.service expected to be active, actual state: {actual_state}. Full response: {result.stdout}"


def test_sddm_is_active(ssh_command):
    result = ssh_command("systemctl is-active plasmalogin.service")
    actual_state = result.stdout.strip()

    assert result.returncode == 0, \
        f"Command returned bad returncode: {result.returncode}. Full response: {result}"

    assert actual_state == "active", \
        f"sddm.service expected to be active, actual state: {actual_state}. Full response: {result.stdout}"


def test_sddm_is_selected_display_manager(ssh_command):
    result = ssh_command("readlink -f /etc/systemd/system/display-manager.service")
    actual_unit = result.stdout.strip()

    assert result.returncode == 0, \
        f"Command returned bad returncode: {result.returncode}. Full response: {result}"

    assert actual_unit.endswith("/plasmalogin.service"), \
        f"display-manager.service expected to point to plasmalogin.service, actual target: {actual_unit}"


def test_plasma_de_packages_installed(ssh_command):
    for package in PLASMA_DE_PACKAGES:
        ssh_command(f"rpm -q {package}")


def test_xdg_user_dirs_exist(ssh_command):
    for xdg_dir in XDG_DIRS:
        ssh_command(f'test -d "$HOME/{xdg_dir}"')


def test_graphical_session_exists(ssh_command):
    result = ssh_command("loginctl show-session $(loginctl | awk '/seat0/ {print $1}') -p Type")

# do we want to still check for x11 session?
#    assert "Type=x11" in result.stdout or "Type=wayland" in result.stdout, \
#        f"No active graphical session found: {result.stdout}"

    assert "Type=wayland" in result.stdout, \
        f"No active graphical session found: {result.stdout}"

