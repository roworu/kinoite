from defaults import TEST_USER

def test_ssh_login(ssh_command):
    ssh_command("true")

def test_logged_in_user(ssh_command):
    result = ssh_command("id -un")
    assert result.stdout.strip() == TEST_USER, \
        f"Wrong user used for SSH session. Expected: {TEST_USER}, actual: {result.stdout.strip()}"

