"""Observe notify.sh's real terminal bytes through an isolated pseudo-terminal."""
import os
from pathlib import Path
import pty
import select
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class GhosttyNotificationTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.folder = Path(self.scratch.name)
        self.bin = self.folder / "bin"
        self.bin.mkdir()
        notifier = self.bin / "terminal-notifier"
        notifier.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$PEON_DIR/notifier-args"\n')
        notifier.chmod(0o755)
        self.master, self.slave = pty.openpty()
        self.env = dict(os.environ, PEON_PLATFORM="mac", PEON_NOTIF_STYLE="standard",
                        PEON_SYNC="1", PEON_DIR=str(self.folder), TERM_PROGRAM="ghostty",
                        PEON_SESSION_TTY=os.ttyname(self.slave), PEON_BUNDLE_ID="com.mitchellh.ghostty",
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"])
        for key in ("TMUX", "HERDR_ENV", "HERDR_PANE_ID", "HERDR_SOCKET_PATH", "HERDR_BIN_PATH",
                    "PEON_CLICK_COMMAND", "PEON_CMUX_CLI", "PEON_CMUX_WORKSPACE_ID", "PEON_CMUX_SURFACE_ID"):
            self.env.pop(key, None)

    def tearDown(self):
        os.close(self.master)
        os.close(self.slave)
        self.scratch.cleanup()

    def notify(self, message="Ready", title="Project"):
        subprocess.run(["bash", str(ROOT / "scripts/notify.sh"), message, title, "blue"],
                       env=self.env, check=True, capture_output=True, timeout=5)
        return os.read(self.master, 4096) if select.select([self.master], [], [], 0)[0] else b""

    def test_direct_ghostty_writes_notification_to_agent_surface(self):
        # App-only Notification Center activation cannot identify the origin tab;
        # the emitted OSC belongs to the actual agent PTY instead of hook stdout.
        self.assertEqual(self.notify(), b"\x1b]777;notify;Project;Ready\x07")
        self.assertFalse((self.folder / "notifier-args").exists())

    def test_terminal_control_bytes_cannot_end_notification_early(self):
        self.assertEqual(self.notify("Ready\x07\x1b]52;clipboard", "Project;name"),
                         b"\x1b]777;notify;Project name;Ready]52;clipboard\x07")

    def test_herdr_keeps_notification_off_swallowed_pane_tty(self):
        self.env["HERDR_ENV"] = "1"
        self.assertEqual(self.notify(), b"")
        self.assertIn("-message\nReady", (self.folder / "notifier-args").read_text())

    def test_tmux_preserves_inner_pane_click_command(self):
        self.env["TMUX"] = "/tmp/fixture,1,0"
        self.env["PEON_CLICK_COMMAND"] = "printf focus-pane"
        self.assertEqual(self.notify(), b"")
        args = (self.folder / "notifier-args").read_text().splitlines()
        self.assertEqual(shlex.split(args[args.index("-execute") + 1]),
                         ["/bin/bash", "-lc", "printf focus-pane"])

    def test_unwritable_session_tty_uses_notification_center(self):
        self.env["PEON_SESSION_TTY"] = str(self.folder / "missing-tty")
        self.assertEqual(self.notify(), b"")
        self.assertIn("-activate\ncom.mitchellh.ghostty", (self.folder / "notifier-args").read_text())
        self.assertFalse((self.folder / "missing-tty").exists())


if __name__ == "__main__":
    unittest.main()
