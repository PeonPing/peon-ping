"""Behavioral coverage for keeping Codex hooks in one representation."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


HELPER = Path(__file__).resolve().parents[1] / 'scripts' / 'codex-config.py'


class CodexJsonConfigTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.config = self.root / 'config.toml'
        self.hooks = self.root / 'hooks.json'
        self.install_dir = self.root / 'install with spaces'
        self.adapter = self.install_dir / 'adapters' / 'codex.sh'
        self.config.write_text('model = "test-model"\n')

    def invoke(self, action='install'):
        command = [sys.executable, str(HELPER), action, '--config', str(self.config),
                   '--install-dir', str(self.install_dir)]
        if action == 'install':
            command += ['--adapter', str(self.adapter)]
        return subprocess.run(command, cwd=self.root, capture_output=True, text=True)

    def write_hooks(self, document):
        self.hooks.write_text(json.dumps(document))

    def handlers(self):
        return [handler for groups in json.loads(self.hooks.read_text(encoding='utf-8-sig'))['hooks'].values()
                for group in groups for handler in group['hooks']]

    def test_existing_json_receives_seven_hooks_without_changing_toml(self):
        self.write_hooks({'description': 'My hooks', 'hooks': {'Stop': [
            {'hooks': [{'type': 'command', 'command': 'echo user-stop'}]}]}})
        original = self.config.read_bytes()
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.config.read_bytes(), original)
        self.assertEqual(len(self.handlers()), 8)
        self.assertIn({'type': 'command', 'command': 'echo user-stop'}, self.handlers())
        self.assertEqual(json.loads(self.hooks.read_text())['description'], 'My hooks')
        for handler in self.handlers()[1:]:
            self.assertIn(str(self.adapter), handler['command'])
            self.assertEqual(handler['timeout'], 30)

    def test_json_install_is_idempotent_and_clean_preserves_sibling_handlers(self):
        self.write_hooks({'hooks': {}})
        self.assertEqual(self.invoke().returncode, 0)
        self.assertEqual(len(self.handlers()), 7)
        first = self.hooks.read_bytes()
        self.assertEqual(self.invoke().returncode, 0)
        self.assertEqual(self.hooks.read_bytes(), first)
        document = json.loads(self.hooks.read_text())
        document['hooks']['Stop'][0]['hooks'].append({'type': 'command', 'command': 'echo keep'})
        self.write_hooks(document)
        self.assertEqual(self.invoke('clean').returncode, 0)
        self.assertEqual(self.handlers(), [{'type': 'command', 'command': 'echo keep'}])
        self.assertEqual(self.config.read_text(), 'model = "test-model"\n')

    def test_json_clean_works_without_a_toml_file_and_preserves_other_installations(self):
        self.config.unlink()
        self.write_hooks({'hooks': {'Stop': [{'hooks': [
            {'type': 'command', 'command': f'bash "{self.adapter}"'},
            {'type': 'command', 'command': f'bash "{self.adapter}.bak"'},
            {'type': 'command', 'command': 'bash /other/adapters/codex.sh'},
        ]}]}})
        result = self.invoke('clean')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.handlers()), 2)
        self.assertFalse(self.config.exists())

    def test_invalid_json_refuses_without_changing_either_file(self):
        for content in ('{"hooks":', '[]', '{"hooks": []}', '{"hooks": {"Stop": null}}'):
            with self.subTest(content=content):
                self.hooks.write_text(content)
                original = self.config.read_bytes()
                result = self.invoke()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('hooks.json', result.stderr)
                self.assertNotIn('Traceback', result.stderr)
                self.assertEqual(self.hooks.read_text(), content)
                self.assertEqual(self.config.read_bytes(), original)

    def test_owned_toml_hooks_move_to_existing_json_without_duplicate_events(self):
        self.assertEqual(self.invoke().returncode, 0)
        self.write_hooks({'hooks': {}})
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('[[hooks.', self.config.read_text())
        self.assertEqual(len(self.handlers()), 7)

    def test_foreign_inline_hooks_refuse_mixed_representation_without_writes(self):
        self.config.write_text('model = "test-model"\n[[hooks.Stop]]\n[[hooks.Stop.hooks]]\n'
                               'type = "command"\ncommand = "echo private-stop"\n')
        self.write_hooks({'hooks': {}})
        before = (self.config.read_bytes(), self.hooks.read_bytes())
        result = self.invoke()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('both', result.stderr)
        self.assertEqual((self.config.read_bytes(), self.hooks.read_bytes()), before)

    def test_json_accepts_bom_and_preserves_symlink_and_mode(self):
        target = self.root / 'tracked-hooks.json'
        target.write_text('\ufeff{"hooks": {}}', encoding='utf-8')
        target.chmod(0o600)
        self.hooks.symlink_to(target)
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.hooks.is_symlink())
        self.assertEqual(target.stat().st_mode & 0o777, 0o600)
        self.assertEqual(len(self.handlers()), 7)
        self.assertEqual(self.invoke('clean').returncode, 0)
        self.assertEqual(json.loads(target.read_text())['hooks'], {})

    def test_quoted_and_dotted_toml_hook_keys_refuse_json_collision(self):
        definitions = (
            '[["hooks".Stop]]\n[["hooks".Stop.hooks]]\ntype="command"\ncommand="echo keep"\n',
            "[['hooks'.Stop]]\n[['hooks'.Stop.hooks]]\ntype='command'\ncommand='echo keep'\n",
            'hooks.Stop = [{hooks=[{type="command",command="echo keep"}]}]\n',
            '"h\\u006foks".Stop = [{hooks=[{type="command",command="echo keep"}]}]\n',
            '[["h\\U0000006foks".Stop]]\n[["h\\U0000006foks".Stop.hooks]]\ncommand="echo keep"\n',
        )
        self.write_hooks({'hooks': {}})
        for definition in definitions:
            with self.subTest(definition=definition):
                self.config.write_text(definition)
                before = (self.config.read_bytes(), self.hooks.read_bytes())
                result = self.invoke()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('both', result.stderr)
                self.assertEqual((self.config.read_bytes(), self.hooks.read_bytes()), before)


if __name__ == '__main__':
    unittest.main()
