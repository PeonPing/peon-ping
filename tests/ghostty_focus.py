"""Exercise the actual Ghostty focus predicate with a controlled AppleEvent boundary."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class GhosttyFocusTests(unittest.TestCase):
    def focused(self, active_tty, session_tty="/dev/ttys042"):
        with tempfile.TemporaryDirectory() as folder:
            osascript = Path(folder) / "osascript"
            osascript.write_text('''#!/bin/bash
case "$*" in
  *"working directory"*) printf 'same-title\\t/same/cwd' ;;
  *"tty of"*) printf '%s' "$ACTIVE_TTY" ;;
esac
''')
            osascript.chmod(0o755)
            source = (ROOT / "peon.sh").read_text()
            predicate = source.split("_ghostty_terminal_is_current() {", 1)[1].split("\n}", 1)[0]
            program = "_ghostty_terminal_is_current() {" + predicate + "\n}\n_ghostty_terminal_is_current"
            env = dict(os.environ, PATH=folder + os.pathsep + os.environ["PATH"],
                       ACTIVE_TTY=active_tty, PEON_SESSION_TTY=session_tty,
                       TITLE="same-title", PROJECT="same-title", CWD="/same/cwd")
            return subprocess.run(["bash", "-c", program], env=env, capture_output=True).returncode == 0

    def test_same_title_and_cwd_cannot_hide_background_terminal(self):
        # Restoring title/cwd equality as identity suppresses the wrong terminal.
        self.assertFalse(self.focused("/dev/ttys099"))

    def test_exact_tty_identifies_focused_terminal(self):
        self.assertTrue(self.focused("/dev/ttys042"))

    def test_unsupported_ghostty_tty_property_does_not_suppress(self):
        self.assertFalse(self.focused(""))

    def test_missing_session_identity_does_not_suppress(self):
        self.assertFalse(self.focused("/dev/ttys042", session_tty=""))


if __name__ == "__main__":
    unittest.main()
