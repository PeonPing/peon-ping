# Security Audit Report: peon-ping

**Date:** 2026-02-23

## Executive Summary

peon-ping is a CLI tool that receives JSON events from IDE hooks, processes them through embedded Python, and plays audio notifications. The primary attack surface is: (1) JSON input from IDE hooks parsed inline in shell scripts, (2) an unauthenticated HTTP relay server, (3) downloads from remote registries, and (4) numerous shell-to-Python handoff points using string interpolation.

The most significant class of vulnerability found is **shell variable injection into Python code strings**, present in dozens of locations throughout the codebase. Because the Python blocks are constructed via bash string interpolation of `$CONFIG`, `$STATE`, `$PEON_DIR` and similar variables, a malicious path containing Python syntax (e.g., via a crafted `CLAUDE_CONFIG_DIR` environment variable) could achieve code execution.

---

## CRITICAL Findings

### 1. Shell Variable Injection into Inline Python via `$CONFIG`, `$PEON_DIR`, `$STATE` (peon.sh, throughout)

**Vulnerability**: Throughout `peon.sh`, Python code is constructed using single-quoted shell variable interpolation. For example, at line 1997-1998:

```python
config_path = '$CONFIG'
state_file = '$STATE'
peon_dir = '$PEON_DIR'
```

The variables `$CONFIG`, `$STATE`, and `$PEON_DIR` are derived from `$CLAUDE_PEON_DIR`, `$CLAUDE_CONFIG_DIR`, or `$PWD`. If any of these contain a single quote followed by Python code (e.g., `'; import os; os.system("malicious command"); #`), the Python string literal is broken out of, enabling arbitrary Python code execution inside the `eval "$(python3 -c "...")"` at line 1993.

This pattern is repeated in dozens of places throughout `peon.sh`, `install.sh`, and `scripts/hook-handle-use.sh`.

**Attack Vector**: An attacker who can set environment variables for the user's shell session (e.g., via a malicious `.envrc`, compromised dotfile, or repository-level `.env` file processed by a tool like `direnv`) can set `CLAUDE_CONFIG_DIR` or `CLAUDE_PEON_DIR` to a value containing Python injection payloads. When the hook fires, arbitrary code executes as the user.

**Impact**: Arbitrary code execution as the current user. Since hooks fire automatically on IDE events, exploitation requires no user interaction beyond opening a project.

**Remediation**: Pass all external data to Python via environment variables or command-line arguments (using `sys.argv`), never via string interpolation into Python source code.

---

### 2. Unauthenticated HTTP Relay Server with Command Execution (relay.sh)

**Vulnerability**: The relay server at `relay.sh` (lines 172-520) listens on an HTTP port (default 19998) with **zero authentication**. Any process on the same machine (or network, if `--bind=0.0.0.0` is used) can:

1. **Play arbitrary sound files** within the peon-ping directory via `GET /play?file=<path>`
2. **Trigger desktop notifications** with arbitrary content via `POST /notify`
3. **Execute category-based sounds** via `GET /play?category=<category>`

**Attack Vector**: Any malicious process, browser tab (via JavaScript to localhost), or script on the machine can send HTTP requests to `localhost:19998` to trigger desktop notifications with arbitrary text. This could be used for social engineering.

**Impact**: Social engineering via fake desktop notifications, potential denial of service via notification spam.

**Remediation**: Add a shared secret/token that must be present in requests. Implement CORS headers. Rate-limit the notification endpoint.

---

## HIGH Findings

### 3. WSL PowerShell Injection via Unescaped Path (peon.sh, relay.sh)

**Vulnerability**: In the WSL audio playback path at `peon.sh` lines 240-242:

```bash
setsid powershell.exe -NoProfile -NonInteractive -Command "
  (New-Object Media.SoundPlayer '${tmpdir}peon-ping-sound.wav').PlaySync()
" &>/dev/null &
```

And in `relay.sh` lines 361-372:

```python
f"$mp.Open([uri]'{win_path}'); "
```

If these paths contain single quotes, they enable PowerShell command injection.

**Impact**: Arbitrary PowerShell command execution on Windows/WSL hosts.

**Remediation**: Properly escape paths for PowerShell string literals by doubling single quotes.

---

### 4. `eval` of Python Output Without Validation (peon.sh, line 1993)

**Vulnerability**: At `peon.sh` line 1993:

```bash
eval "$(python3 -c "..." <<< "$INPUT" 2>/dev/null)"
```

The output of the Python script is directly `eval`'d by bash. While the Python code uses `shlex.quote()` to safely quote output values, this creates a fragile security boundary.

Similarly, at line 451: `eval "$mobile_vars"`

**Impact**: Arbitrary shell command execution as the current user if quoting is ever bypassed.

**Remediation**: Validate that Python output matches expected `VAR=value` patterns before eval'ing.

---

### 5. Supply Chain Risk: HTTP Downloads Without Integrity Verification (install.sh, pack-download.sh)

**Vulnerability**: Scripts and packs are downloaded from GitHub over HTTPS without checksum or signature verification.

**Impact**: Arbitrary code execution via compromised scripts or crafted pack manifests.

**Remediation**: Add GPG signature verification or SHA256 checksums for core scripts.

---

## MEDIUM Findings

### 6. Notification Content Injection for Social Engineering (relay.sh, notify.sh)

**Vulnerability**: The relay's `/notify` endpoint accepts arbitrary `title` and `message` content and displays it as a desktop notification. This allows crafting convincing phishing notifications.

**Impact**: Social engineering leading to credential theft or malicious command execution by the user.

**Remediation**: Add authentication to the relay endpoint. Add a fixed visual indicator that cannot be overridden.

---

### 7. JSON Injection in Adapter Scripts via `$CWD` and `$PWD` (codex.sh, windsurf.sh, antigravity.sh)

**Vulnerability**: Several adapter scripts construct JSON by string interpolation without proper escaping:

```bash
echo "{\"hook_event_name\":\"$EVENT\",...,\"cwd\":\"$CWD\",...}" | bash "$PEON_DIR/peon.sh"
```

If `$CWD` contains double quotes or backslashes, this breaks the JSON structure.

**Impact**: Likely limited to denial of service (JSON parse failure), but crafted JSON could inject additional fields.

**Remediation**: Use `json.dumps()` to construct JSON safely (as `adapters/kiro.sh` already does).

---

### 8. Race Condition in State File Writes (peon.sh, relay.sh)

**Vulnerability**: State file `.state.json` is read, modified, and written back non-atomically. Uses `json.dump(state, open(state_file, 'w'))` which truncates the file immediately.

**Impact**: State corruption from concurrent hook invocations.

**Remediation**: Use atomic file writes (write to temp file, then `os.replace()`).

---

## LOW Findings

### 9. Path Traversal Protection Could Be Strengthened (relay.sh)

**Observation**: Multi-layered defense exists (normpath + `..` check + realpath + prefix check), but should additionally restrict to audio file extensions only.

**Remediation**: Validate that accessed files have audio file extensions (`.wav`, `.mp3`, `.ogg`, etc.).

---

### 10. Sensitive Tokens Stored in Plaintext Config (peon.sh, config.json)

**Vulnerability**: Mobile notification service credentials stored in plaintext in `config.json`.

**Remediation**: Set restrictive file permissions. Support reading tokens from environment variables.

---

### 11. Unvalidated File Extension in Audio Playback (relay.sh, peon.sh)

**Observation**: Files are played without verifying they have audio file extensions. Any file within the allowed directory could be passed to audio players.

**Remediation**: Validate file paths end with `.wav`, `.mp3`, `.ogg`, `.flac`, `.aac`, `.m4a`, or `.opus`.

---

## Positive Security Practices Observed

1. **`shlex.quote()` usage**: Consistent use for shell variable output
2. **Input validation in pack-download.sh**: Strict allowlist patterns for pack names, repos, refs, paths, filenames
3. **Path traversal protection**: Multi-layered defense in relay.sh and peon.sh
4. **Set options**: Scripts use `set -euo pipefail` or `set -uo pipefail`
5. **Relay defaults to localhost binding**: Default `BIND_ADDR` is `127.0.0.1`
6. **Input validation in hook-handle-use.sh**: Pack names and session IDs validated against strict character sets
