"""Reproduce overlapping local playback with owned, long-lived audio fixtures."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SoundConcurrencyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.native = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.native.cleanup)
        cls.player = Path(cls.native.name) / "sound-player"
        # The shipped afplay and peon-play are native executables. An env/Python
        # script changes its ps command after launch, which correctly makes its
        # recorded ownership identity ineligible for interruption.
        source = Path(__file__).parent / "fixtures" / "sound-player.c"
        result = subprocess.run(["cc", "-Wall", "-Wextra", "-Werror", str(source),
                                 "-o", str(cls.player)], capture_output=True, text=True)
        if result.returncode:
            raise AssertionError(f"Cannot compile native audio fixture:\n{result.stderr}")

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.folder = Path(self.temp.name)
        self.bin = self.folder / "bin"
        self.bin.mkdir()
        (self.folder / "alive").mkdir()
        self.fixture = self.folder / "scripts" / "peon-play"
        self.fixture.parent.mkdir()
        shutil.copy2(self.player, self.fixture)
        # Arrange for every old read/kill transaction to observe the same prior
        # PID before any contender can launch+publish its replacement.
        cat = self.bin / "cat"
        cat.write_text('''#!/usr/bin/env python3
import fcntl, os, pathlib, sys, time
p=pathlib.Path(sys.argv[1])
data=p.read_text() if p.exists() else ''
if p.name == '.sound.pid':
    root=p.parent
    with (root/'barrier').open('a+') as f:
        fcntl.flock(f,fcntl.LOCK_EX)
        f.seek(0); n=int(f.read() or '0')+1
        f.seek(0); f.truncate(); f.write(str(n)); f.flush()
    deadline=time.monotonic()+3
    while time.monotonic()<deadline and int((root/'barrier').read_text() or '0')<6:
        time.sleep(.01)
sys.stdout.write(data)
''')
        cat.chmod(0o755)
        source = (ROOT / "peon.sh").read_text()
        resolver = source.split("find_bundled_script() {", 1)[1].split("\n}\n", 1)[0]
        audio = source.split("# --- Kill any previously playing peon-ping sound ---", 1)[1].split("# --- Live tmux client context", 1)[0]
        self.runner = self.folder / "play.sh"
        self.runner.write_text("find_bundled_script() {" + resolver + "\n}\n" + audio + '\nplay_sound fixture.wav 0\n')
        self.env = dict(os.environ, PEON_DIR=str(self.folder), PEON_PLATFORM="mac",
                        PEON_TEST="0", USE_SOUND_EFFECTS_DEVICE="true",
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"])

    def tearDown(self):
        children = self.folder / "children"
        if children.exists():
            for pid in children.read_text().splitlines():
                try:
                    command = subprocess.check_output(
                        ["ps", "-p", pid, "-o", "command="], text=True, stderr=subprocess.DEVNULL)
                    if str(self.fixture) in command:
                        os.kill(int(pid), signal.SIGTERM)
                except (ProcessLookupError, subprocess.CalledProcessError):
                    pass
        self.temp.cleanup()

    def test_concurrent_events_leave_only_the_latest_sound_playing(self):
        (self.folder / ".sound.pid").write_text("99999999\n")
        runners = [subprocess.Popen(["bash", str(self.runner)], env=self.env,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.PIPE) for _ in range(6)]
        for runner in runners:
            _, stderr = runner.communicate(timeout=8)
            self.assertEqual(runner.returncode, 0, stderr.decode())
        # A player is an actual fixture process, not the launcher or mocked log.
        deadline = time.monotonic() + 2
        while not list((self.folder / "alive").iterdir()) and time.monotonic() < deadline:
            time.sleep(.01)
        time.sleep(.1)  # allow already-sent SIGTERM handlers to remove their markers
        playing = list((self.folder / "alive").iterdir())
        self.assertEqual(len(playing), 1,
                         f"active fixture PIDs: {sorted(p.name for p in playing)}")
        self.assertEqual((self.folder / ".sound.pid").read_text().strip(), playing[0].name)

    def test_incomplete_identity_record_cannot_authorize_a_signal(self):
        with subprocess.Popen([sys.executable, "-c", "import time; time.sleep(10)"],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) as unrelated:
            (self.folder / ".sound.pid").write_text(str(unrelated.pid))
            (self.folder / ".sound.identity").write_text(json.dumps({"pid": unrelated.pid}))
            result = subprocess.run(["bash", str(self.runner)], env=self.env,
                                    capture_output=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr.decode())
            self.assertIsNone(unrelated.poll())
            unrelated.terminate()
            unrelated.wait(timeout=2)

    def test_stale_pid_file_cannot_kill_an_unowned_process(self):
        with subprocess.Popen([sys.executable, "-c", "import time; time.sleep(10)"],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) as unrelated:
            (self.folder / ".sound.pid").write_text(str(unrelated.pid))
            # All the single runner's old read can proceed without waiting.
            (self.folder / "barrier").write_text("6")
            result = subprocess.run(["bash", str(self.runner)], env=self.env,
                                    capture_output=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr.decode())
            self.assertIsNone(unrelated.poll())
            unrelated.terminate()
            unrelated.wait(timeout=2)


if __name__ == "__main__":
    import sys
    unittest.main()
