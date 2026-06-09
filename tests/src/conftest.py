import os
import time
import pytest
import subprocess

from pathlib import Path

from defaults import TEST_USER as DEFAULT_TEST_USER

TEST_HOST = os.getenv("TEST_SSH_HOST", "127.0.0.1")
TEST_PORT = os.getenv("TEST_SSH_PORT", "2222")
TEST_USER = os.getenv("TEST_SSH_USER", DEFAULT_TEST_USER)
TEST_KEY = Path(os.getenv("TEST_SSH_KEY", "/ssh/test_user"))

assert TEST_KEY.is_file(), f"SSH key not found: {TEST_KEY}"


@pytest.fixture(scope="session")
def wait_for_ssh():

    deadline = time.time() + int(os.getenv("TEST_SSH_WAIT_SECONDS", "600"))

    while time.time() < deadline:

        result = subprocess.run(
            [
                "ssh",
                "-i", str(TEST_KEY),
                "-o", "BatchMode=yes",
                "-o", "StrictHostKeyChecking=no",
                "-o", "ConnectTimeout=5",
                "-p", TEST_PORT,
                f"{TEST_USER}@{TEST_HOST}",
                "true",
            ],
            capture_output=True,
        )

        if result.returncode == 0:
            return
        else:
            time.sleep(5)

    raise TimeoutError("SSH host did not become available")


@pytest.fixture(scope="session")
def ssh_command(wait_for_ssh):

    def run(command: str, check: bool = True):

        result = subprocess.run(
            [
                "ssh",
                "-i", str(TEST_KEY),
                "-o", "BatchMode=yes",
                "-o", "StrictHostKeyChecking=no",
                "-p", TEST_PORT,
                f"{TEST_USER}@{TEST_HOST}",
                command,
            ], capture_output=True, text=True,
        )

        if check and result.returncode != 0:
            raise AssertionError(
                f"Command failed: {command}\n"
                f"Return code: {result.returncode}\n"
                f"STDOUT:\n{result.stdout}\n"
                f"STDERR:\n{result.stderr}"
            )

        return result

    return run