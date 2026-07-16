#!/usr/bin/env python3
"""Safely register and remove peon-ping's inline Codex hooks."""

import argparse
import json
import os
import re
import shlex
import stat
import tempfile


BEGIN_MARKER = '# peon-ping Codex hooks begin'
END_MARKER = '# peon-ping Codex hooks end'
EVENTS = (
    ('SessionStart', 'startup|resume|clear'),
    ('UserPromptSubmit', ''),
    ('PermissionRequest', ''),
    ('PreCompact', 'manual|auto'),
    ('SubagentStart', ''),
    ('SubagentStop', ''),
    ('Stop', ''),
)
PATH_CHARS = set('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~:/-')
TABLE_RE = re.compile(r'^\s*(\[\[|\[)\s*(.*?)\s*(\]\]|\])\s*(?:#.*)?(?:\r?\n)?$')
INSTALL_DIR_RE = re.compile(r'^\s*#\s*install_dir\s*=\s*(.*?)\s*(?:\r?\n)?$')
COMMAND_RE = re.compile(r'^\s*(command|command_windows)\s*=\s*(.*?)\s*(?:\r?\n)?$')


def normalize_path(value):
    value = str(value or '').strip().strip('"').strip("'")
    value = value.replace('\\\\', '\\').replace('\\', '/')
    return value.rstrip('/')


def path_variants(path):
    variants = {normalize_path(path)} if path else set()
    home = os.path.expanduser('~')
    if path.startswith(home):
        variants.add(normalize_path('~' + path[len(home):]))
    return {value for value in variants if value}


def text_has_path_token(text, path):
    text = normalize_path(text)
    path = normalize_path(path)
    start = 0
    while path:
        index = text.find(path, start)
        if index < 0:
            return False
        before = text[index - 1] if index else ''
        after_index = index + len(path)
        after = text[after_index] if after_index < len(text) else ''
        if (not before or before not in PATH_CHARS) and (not after or after not in PATH_CHARS):
            return True
        start = index + 1
    return False


class CodexConfigEditor:
    def __init__(self, install_dir):
        self.install_dir = normalize_path(install_dir)
        self.install_markers = path_variants(self.install_dir)
        self.adapter_markers = set()
        for adapter_name in ('codex.sh', 'codex.ps1'):
            self.adapter_markers.update(
                path_variants(os.path.join(self.install_dir, 'adapters', adapter_name))
            )

    def is_current_adapter_text(self, text):
        if not re.search(r'adapters[\\/]+codex\.(?:sh|ps1)', text, re.IGNORECASE):
            return False
        return any(text_has_path_token(text, marker) for marker in self.adapter_markers)

    def _remove_owned_marker_comments(self, text):
        lines = text.splitlines(keepends=True)
        remove = set()
        outside_multiline = []
        multiline_state = None
        for line in lines:
            outside_multiline.append(multiline_state is None)
            multiline_state = self._advance_multiline_state(line, multiline_state)
        begin_indexes = [
            index
            for index, line in enumerate(lines)
            if outside_multiline[index] and line.strip() == BEGIN_MARKER
        ]

        for position, begin_index in enumerate(begin_indexes):
            limit = begin_indexes[position + 1] if position + 1 < len(begin_indexes) else len(lines)
            end_index = None
            for index in range(begin_index + 1, limit):
                if outside_multiline[index] and lines[index].strip() == END_MARKER:
                    end_index = index
                    break
            region_end = end_index + 1 if end_index is not None else limit
            region = ''.join(lines[begin_index:region_end])
            explicit_install_dirs = []
            for index in range(begin_index + 1, region_end):
                match = INSTALL_DIR_RE.match(lines[index]) if outside_multiline[index] else None
                if match:
                    explicit_install_dirs.append(normalize_path(match.group(1)))

            owned = any(value in self.install_markers for value in explicit_install_dirs)
            if not owned:
                owned = self.is_current_adapter_text(region)
            if not owned:
                continue

            remove.add(begin_index)
            if end_index is not None:
                remove.add(end_index)
            for index in range(begin_index + 1, region_end):
                match = INSTALL_DIR_RE.match(lines[index]) if outside_multiline[index] else None
                if match and normalize_path(match.group(1)) in self.install_markers:
                    remove.add(index)

        return ''.join(line for index, line in enumerate(lines) if index not in remove)

    @staticmethod
    def _advance_multiline_state(line, state):
        index = 0
        while index <= len(line) - 3:
            if state:
                marker = state
                found = line.find(marker, index)
                if found < 0:
                    return state
                if marker == '"""':
                    backslashes = 0
                    cursor = found - 1
                    while cursor >= 0 and line[cursor] == '\\':
                        backslashes += 1
                        cursor -= 1
                    if backslashes % 2:
                        index = found + 3
                        continue
                state = None
                index = found + 3
                continue

            basic = line.find('"""', index)
            literal = line.find("'''", index)
            candidates = [(basic, '"""'), (literal, "'''")]
            candidates = [(found, marker) for found, marker in candidates if found >= 0]
            if not candidates:
                return None
            found, marker = min(candidates)
            comment = line.find('#', index, found)
            if comment >= 0:
                return None
            state = marker
            index = found + 3
        return state

    @classmethod
    def _split_sections(cls, text):
        lines = text.splitlines(keepends=True)
        sections = []
        current = []
        current_header = None
        multiline_state = None

        for line in lines:
            header = None if multiline_state else TABLE_RE.match(line)
            if header and ((header.group(1) == '[[') == (header.group(3) == ']]')):
                if current:
                    sections.append((current_header, current))
                current = [line]
                current_header = (
                    'array' if header.group(1) == '[[' else 'table',
                    tuple(part.strip() for part in header.group(2).split('.')),
                )
            else:
                current.append(line)
            multiline_state = cls._advance_multiline_state(line, multiline_state)

        if current:
            sections.append((current_header, current))
        return sections

    @staticmethod
    def _hook_kind(header):
        if not header or header[0] != 'array':
            return None
        path = header[1]
        if len(path) == 2 and path[0] == 'hooks':
            return ('parent', path[1])
        if len(path) == 3 and path[0] == 'hooks' and path[2] == 'hooks':
            return ('handler', path[1])
        return None

    def _section_is_current_handler(self, lines):
        for line in lines[1:]:
            match = COMMAND_RE.match(line)
            if match and self.is_current_adapter_text(match.group(2)):
                return True
        return False

    def _remove_hook_sections(self, text):
        sections = self._split_sections(text)
        remove = set()

        for index, (header, lines) in enumerate(sections):
            kind = self._hook_kind(header)
            if kind and kind[0] == 'handler' and self._section_is_current_handler(lines):
                remove.add(index)

        for index, (header, _) in enumerate(sections):
            kind = self._hook_kind(header)
            if not kind or kind[0] != 'parent':
                continue
            event = kind[1]
            handler_indexes = []
            cursor = index + 1
            while cursor < len(sections):
                child_kind = self._hook_kind(sections[cursor][0])
                if not child_kind or child_kind != ('handler', event):
                    break
                handler_indexes.append(cursor)
                cursor += 1
            if handler_indexes and all(handler_index in remove for handler_index in handler_indexes):
                remove.add(index)

        return ''.join(
            ''.join(lines)
            for index, (_, lines) in enumerate(sections)
            if index not in remove
        )

    @staticmethod
    def _bracket_delta(line):
        delta = 0
        quote = ''
        escaped = False
        for character in line:
            if quote:
                if quote == '"' and escaped:
                    escaped = False
                    continue
                if quote == '"' and character == '\\':
                    escaped = True
                    continue
                if character == quote:
                    quote = ''
                continue
            if character in ('"', "'"):
                quote = character
            elif character == '#':
                break
            elif character == '[':
                delta += 1
            elif character == ']':
                delta -= 1
        return delta

    def _remove_legacy_notify(self, text):
        lines = text.splitlines(keepends=True)
        kept = []
        index = 0
        multiline_state = None
        while index < len(lines):
            line = lines[index]
            if multiline_state is None and re.match(r'^\s*notify\s*=', line):
                block = [line]
                balance = self._bracket_delta(line)
                index += 1
                while balance > 0 and index < len(lines):
                    block.append(lines[index])
                    balance += self._bracket_delta(lines[index])
                    index += 1
                if self.is_current_adapter_text(''.join(block)):
                    continue
                kept.extend(block)
                continue
            kept.append(line)
            multiline_state = self._advance_multiline_state(line, multiline_state)
            index += 1
        return ''.join(kept)

    def clean(self, text, newline='\n'):
        text = self._remove_owned_marker_comments(text)
        text = self._remove_hook_sections(text)
        text = self._remove_legacy_notify(text)
        return text.rstrip() + (newline if text.strip() else '')


def atomic_write(path, content):
    destination = os.path.realpath(path) if os.path.islink(path) else path
    directory = os.path.dirname(destination) or '.'
    os.makedirs(directory, exist_ok=True)
    existing_mode = None
    if os.path.exists(destination):
        existing_mode = stat.S_IMODE(os.stat(destination).st_mode)
    descriptor, temporary_path = tempfile.mkstemp(prefix='.config.toml.', dir=directory)
    try:
        with os.fdopen(descriptor, 'w', encoding='utf-8', newline='') as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        if existing_mode is not None:
            os.chmod(temporary_path, existing_mode)
        os.replace(temporary_path, destination)
    finally:
        if os.path.exists(temporary_path):
            os.unlink(temporary_path)


def read_config(path):
    try:
        with open(path, encoding='utf-8', newline='') as handle:
            return handle.read()
    except FileNotFoundError:
        return ''


def build_block(install_dir, adapter_path, newline='\n'):
    command = 'if [ -f {adapter} ]; then CLAUDE_PEON_DIR={install_dir} bash {adapter} >/dev/null 2>&1 || true; fi'.format(
        install_dir=shlex.quote(install_dir),
        adapter=shlex.quote(adapter_path),
    )
    block = [BEGIN_MARKER, '# install_dir = ' + install_dir]
    for event, matcher in EVENTS:
        block.append('[[hooks.{}]]'.format(event))
        if matcher:
            block.append('matcher = ' + json.dumps(matcher))
        block.append('')
        block.append('[[hooks.{}.hooks]]'.format(event))
        block.append('type = "command"')
        block.append('command = ' + json.dumps(command))
        block.append('timeout = 30')
        block.append('')
    block.append(END_MARKER)
    return newline.join(block) + newline


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('install', 'clean'))
    parser.add_argument('--config', required=True)
    parser.add_argument('--install-dir', required=True)
    parser.add_argument('--adapter')
    args = parser.parse_args()

    editor = CodexConfigEditor(args.install_dir)
    original = read_config(args.config)
    newline = '\r\n' if '\r\n' in original else '\n'
    content = editor.clean(original, newline)

    if args.action == 'install':
        if not args.adapter:
            parser.error('--adapter is required for install')
        block = build_block(args.install_dir, args.adapter, newline)
        content = (content + newline if content else '') + block

    if content != original:
        atomic_write(args.config, content)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
