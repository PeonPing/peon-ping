"""Compile and exercise the real macOS player with silent audio, no global setup."""
from pathlib import Path
import signal
import struct
import subprocess
import sys
import tempfile
import time
import unittest
import wave

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(sys.platform == "darwin", "requires macOS AVFoundation")
class PlayerTailTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scratch = tempfile.TemporaryDirectory()
        cls.folder = Path(cls.scratch.name)
        cls.player = cls.folder / "peon-play"
        subprocess.run(["swiftc", "-O", "-o", str(cls.player),
                        str(ROOT / "scripts/peon-play.swift"),
                        "-framework", "AVFoundation", "-framework", "CoreAudio",
                        "-framework", "AudioToolbox"], check=True, capture_output=True)
        cls.clip = cls.folder / "silent.wav"
        with wave.open(str(cls.clip), "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(48000)
            wav.writeframes(struct.pack("<h", 0) * 9600)

    @classmethod
    def tearDownClass(cls):
        cls.scratch.cleanup()

    def playback_duration(self, *options):
        started = time.monotonic()
        result = subprocess.run([str(self.player), "-v", "0", "-p", "0", *options, str(self.clip)],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        return time.monotonic() - started

    def test_default_tail_keeps_output_pipeline_alive_after_file(self):
        # Removing the tail scheduling or completing on the file instead of the
        # tail makes the default path exit as early as -t 0.
        # Warm the real output device before comparing: its first engine start
        # may spend hundreds of milliseconds waking hardware.
        self.playback_duration("-t", "0")
        without_tail = self.playback_duration("-t", "0")
        default_tail = self.playback_duration()
        self.assertGreater(default_tail - without_tail, 0.35)

    def test_new_sound_can_interrupt_tail_immediately(self):
        # Losing the SIGTERM handler would make a new event wait for the silent
        # tail or exit as a killed process, instead of the normal clean stop.
        with subprocess.Popen([str(self.player), "-v", "0", "-p", "0", "-t", "5000", str(self.clip)],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) as child:
            time.sleep(0.7)
            self.assertIsNone(child.poll(), child.stderr.read() if child.poll() is not None else "")
            child.send_signal(signal.SIGTERM)
            _, stderr = child.communicate(timeout=2)
            self.assertEqual(child.returncode, 0, stderr)


if __name__ == "__main__":
    unittest.main()
