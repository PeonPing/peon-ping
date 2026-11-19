"""Execute the manual rename example against isolated state files."""
import builtins
import errno
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from unittest.mock import patch


class RenameSkillTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        text = (Path(__file__).resolve().parents[1] /
                'skills/peon-ping-rename/SKILL.md').read_text()
        cls.command = re.search(r'```bash\n(python3 -c ".*?\n")\n```',
                                text, re.S).group(1)
        cls.code = cls.command[len('python3 -c "'):-1]

    def setUp(self):
        self.home = tempfile.TemporaryDirectory()
        self.addCleanup(self.home.cleanup)
        self.state = Path(self.home.name) / '.claude/hooks/peon-ping/.state.json'
        self.state.parent.mkdir(parents=True)
        self.original = b'{"session_names": {"other": "Keep"}, "last_played": {"x": 2}}\n'
        self.state.write_bytes(self.original)

    def run_example(self):
        return subprocess.run(['bash', '-c', self.command],
                              env={**os.environ, 'HOME': self.home.name},
                              capture_output=True, text=True)

    def assert_unchanged(self):
        self.assertEqual(self.state.read_bytes(), self.original)
        self.assertEqual(list(self.state.parent.iterdir()), [self.state])

    def execute_with_fault(self, target, error):
        with patch.dict(os.environ, HOME=self.home.name), patch(target, side_effect=error):
            with self.assertRaises(type(error)):
                exec(compile(self.code, '<rename-skill>', 'exec'), {})
        self.assert_unchanged()

    def test_existing_state_preserves_other_names_and_fields(self):
        result = self.run_example()
        self.assertEqual(result.returncode, 0, result.stderr)
        state = json.loads(self.state.read_text())
        self.assertEqual(state['session_names'],
                         {'other': 'Keep', 'SESSION_ID_HERE': 'My Session Name'})
        self.assertEqual(state['last_played'], {'x': 2})
        self.assertEqual(list(self.state.parent.iterdir()), [self.state])

    def test_missing_file_starts_fresh(self):
        self.state.unlink()
        result = self.run_example()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.state.read_text()),
                         {'session_names': {'SESSION_ID_HERE': 'My Session Name'}})

    def test_corrupt_json_stops_without_overwriting(self):
        self.original = b'{"session_names": {"other": "Keep"},'
        self.state.write_bytes(self.original)
        self.assertNotEqual(self.run_example().returncode, 0)
        self.assert_unchanged()

    def test_invalid_encoding_stops_without_overwriting(self):
        self.original = b'\xff'
        self.state.write_bytes(self.original)
        self.assertNotEqual(self.run_example().returncode, 0)
        self.assert_unchanged()

    def test_invalid_state_shape_stops_without_overwriting(self):
        self.original = b'{"session_names": []}'
        self.state.write_bytes(self.original)
        self.assertNotEqual(self.run_example().returncode, 0)
        self.assert_unchanged()

    def assert_read_error(self, error):
        real_open = builtins.open

        def fail_state_read(path, *args, **kwargs):
            mode = args[0] if args else kwargs.get('mode', 'r')
            if os.fspath(path) == str(self.state) and mode == 'r':
                raise error
            return real_open(path, *args, **kwargs)

        with patch.dict(os.environ, HOME=self.home.name), patch('builtins.open', side_effect=fail_state_read):
            with self.assertRaises(type(error)):
                exec(compile(self.code, '<rename-skill>', 'exec'), {})
        self.assert_unchanged()

    def test_permission_error_stops_without_overwriting(self):
        self.assert_read_error(PermissionError(errno.EACCES, 'synthetic read denied'))

    def test_io_error_stops_without_overwriting(self):
        self.assert_read_error(OSError(errno.EIO, 'synthetic read failure'))

    def test_temporary_file_creation_failure_preserves_original(self):
        self.execute_with_fault('tempfile.mkstemp', OSError(errno.ENOSPC, 'synthetic full disk'))

    def test_partial_serialization_failure_preserves_original(self):
        def fail_after_write(state, stream, **kwargs):
            stream.write('{')
            raise OSError(errno.ENOSPC, 'synthetic full disk')

        with patch.dict(os.environ, HOME=self.home.name), patch('json.dump', side_effect=fail_after_write):
            with self.assertRaises(OSError):
                exec(compile(self.code, '<rename-skill>', 'exec'), {})
        self.assert_unchanged()

    def test_replace_failure_preserves_original(self):
        self.execute_with_fault('os.replace', PermissionError(errno.EACCES, 'synthetic replace denied'))


if __name__ == '__main__':
    unittest.main()
