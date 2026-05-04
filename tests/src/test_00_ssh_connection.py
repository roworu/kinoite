import os

def test_ssh_login(ssh_command):
    result = ssh_command("true")
    assert result.returncode == 0, \
        f"Failed to open SSH connection. Full response: {result}"

def test_logged_in_user(ssh_command):
    test_user = os.environ.get("TEST_SSH_USER", "test_user")
    result = ssh_command("id -un")
    assert result.stdout.strip() == test_user, \
        f"Wrong user used for SSH session. Expected: {test_user}, actual: {result.stdout.strip()}"

