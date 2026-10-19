# OpenCode v2 event mapping

`adapters/opencode/peon-ping.ts` supports both OpenCode API generations in
one file. It exports a default object with `id`, `server` (v1), and `setup`
(v2). Each host reads its own entrypoint and accepts the other key, so the
existing installers need no version detection or alternate download.

## 1. Plugin module format

OpenCode v1.19.3 reads `default.server` and requires an `id` for a local
file plugin. Its `readV1Plugin` checks `server` and `tui`; it does not reject
an additional `setup` property. OpenCode v2.0.32 decodes `default.id` and
`default.setup` (or `effect`); additional properties do not fail decoding.
The adapter has no runtime package imports, so both entrypoints can share
the same native process bridge and configuration discovery.

The v1 entrypoint translates `properties` payloads into the bridge's v2
shape. It uses the v1 SDK's `client.session.get({ path: { id } })` response
to resolve resumed sessions and suppress children even when their creation
was not observed. Its `dispose` hook releases project ownership when the
host reloads. The legacy `server.instance.disposed` event does the same.
The v2 entrypoint subscribes to the event stream and aborts it on cleanup.
Both paths contain lookup failures and asynchronous process/pipe errors.

These contracts were checked against the [v1 loader](https://github.com/anomalyco/opencode/blob/v1.19.3/packages/opencode/src/plugin/shared.ts)
and [v2 module decoder](https://github.com/anomalyco/opencode/blob/d4a6223d017e17f1beaa91d3e6ecc6511c5132ad/packages/core/src/plugin/module.ts).

## 2. Event taxonomy

The v2 entrypoint uses a different event taxonomy from v1. The v1 targets
no longer exist; `session.idle` survives only as a `// deprecated` definition
and `session.status` is defined but never published.

| peon-ping hook event   | v1 event (removed)         | v2 event used instead                     |
| ---------------------- | -------------------------- | ----------------------------------------- |
| `SessionStart`         | `session.created`          | first `session.execution.started`          |
| `UserPromptSubmit`     | `session.status` (busy)    | `session.execution.started`                |
| `Stop`                 | `session.idle`             | `session.execution.succeeded`              |
| `PostToolUseFailure`   | `session.error`            | `session.execution.failed`                 |
| `PermissionRequest`    | `permission.asked`         | `permission.asked` (unchanged)             |
| `Notification`         | `question.asked`           | `form.created`                             |
| silent state cleanup   | no direct equivalent      | `session.execution.interrupted`            |

v2 payloads also carry the event body under `data` rather than `properties`:

```ts
for await (const event of ctx.event.subscribe()) {
  // event: { id, type, location?, data: { sessionID, ... } }
}
```

## Notes

- Both entrypoints forward `session_id` as `opencode-<native session ID>`,
  so independent sessions in one physical project do not share a pack assignment.
- The first execution in each primary v2 session emits `SessionStart`. Later
  executions emit `UserPromptSubmit` after the existing 3s startup debounce.
  Repeated starts while the session is busy are ignored. Success, failure,
  interruption and deletion clear busy state.
- Failed executions forward their native `error.message` (or v1
  `error.data.message`) on `PostToolUseFailure`. A provided tool name stays
  unchanged; execution failures without a tool name do not invent one. The core
  accepts explicit OpenCode and omp failures with error text as `task.error`,
  while retaining Claude Code's existing Bash-only filter.
- A tool failure surfaces as `session.execution.failed`. There is no longer a
  per-tool error event, so `PostToolUseFailure` now covers any failed
  execution, not just tool errors.
- `session.created` identifies the new session with `data.sessionID` and
  marks a child with `data.parentID`. Child lifecycle, permission and form
  notifications are suppressed after creation has been observed. For events
  without a location, the host session lookup also identifies child sessions.
- `form.created` nests its request under `data.form`: the adapter reads
  `data.form.id` and `data.form.sessionID`. Replies and cancellations use
  `data.id`. Form text, fields, answers and request IDs are never forwarded
  to the hook.
- The stream covers the connected server. Events carrying a different
  `location.directory` are ignored. Durable execution events have no location
  envelope, so the adapter resolves their session through `ctx.session.get`
  and compares its directory before forwarding. An unresolved directory is
  ignored. Symlink aliases identify the same physical directory. If the host
  loads multiple plugin instances for that directory, one instance owns the
  bridge until its cleanup releases ownership to a surviving instance.
- Cleanup aborts the event subscription and releases directory ownership.
  A session lookup that finishes after cleanup cannot send a notification.
  `session.deleted` silently clears state by its globally unique session ID
  without retrieving a session that the host has already removed.

These payloads were checked against the [OpenCode v2 session schema](https://github.com/anomalyco/opencode/blob/0a46301e36d7edd517dd89736acc5daf9c74898e/packages/schema/src/session-event.ts),
[form schema](https://github.com/anomalyco/opencode/blob/0a46301e36d7edd517dd89736acc5daf9c74898e/packages/schema/src/form.ts)
and [plugin API](https://opencode.ai/v2/docs/build/plugins) on 2026-10-04.

## Native hook bridge

On Windows, the adapter invokes `powershell.exe -NoProfile -NonInteractive
-File peon.ps1` directly, with UTF-8 JSON on stdin. It requires no Bash
wrapper. On macOS and Linux it invokes `bash peon.sh` with the same JSON.
The script path is an argument rather than shell command text. Stdin is
closed after writing the payload, and asynchronous process/pipe errors are
contained.

Discovery checks `CLAUDE_PEON_DIR`, then the Claude hook directory
(`CLAUDE_CONFIG_DIR` or `~/.claude`), the Windows OpenPeon hook directory,
the shared `~/.openpeon` directory and the legacy OpenClaw hook directory.
Only the platform's native script is required.

## Validation and compatibility gates

Run `npm ci` and `npx vitest run` from `adapters/opencode`. The adapter
workflow runs on Ubuntu and Windows. `tests/opencode-bridge.test.ts`
launches the real native executable and checks UTF-8 JSON delivery through
a script path containing spaces, quotes and Unicode. Windows Pester checks
run separately in the main test workflow. Both Windows jobs must pass
before the native bridge is shipped.

On 2026-10-04, the exact adapter was loaded by the official
`@opencode/cli-darwin-arm64@2.0.22` binary in isolated temporary HOME and XDG
directories. The [official update manifest](https://opencode.ai/update/api/latest/cli/npm)
identified build source `05018b8862a8fc198ec9810aafd397c96bb7d86e`.
Actual host events verified forms, permissions, successful and failed
executions, child suppression, routing between two projects and a `/tmp`
symlink alias. Three real location reloads produced one notification each;
all 12 plugin setups received cleanup and closed their streams. A local
OpenAI-compatible fixture supplied model responses without external model
calls. These macOS checks complement the required native Windows jobs.

OpenCode v1 and v2 share this adapter through their respective entrypoints.
Kilo retains its separate export and event contract. The Kilo installers download the preserved v1 server
adapter from `adapters/kilo/peon-ping.ts` directly, so the OpenCode v2
migration does not change Kilo's event contract. The dedicated adapter
exports a `server` function and reads v1 `properties` payloads, matching
[Kilo's documented plugin API](https://kilo.ai/docs/automate/extending/plugins)
and the [Kilo host bridge](https://github.com/Kilo-Org/kilocode/blob/76bcfd40be616a72f4697b3041565f322245b462/packages/opencode/src/plugin/index.ts).
The shell installer integration test loads the installed plugin and
checks `session.idle` delivery through its real hook process. Windows
installer behavior is covered by `tests/opencode-installer.Tests.ps1`.
On 2026-10-04, the exact dedicated adapter also loaded from the global plugin
directory in the official `@kilocode/cli-darwin-arm64@7.8.3` binary. Actual
`session.created` events carried `properties.info`; a primary session
delivered `SessionStart` through Bash, and a child carrying `parentID`
remained silent. The host was isolated in temporary HOME and XDG directories
and terminated after validation.

## Native compatibility verification (2026-10-19)

The same single-file candidate loaded in the official macOS ARM64 binaries
`opencode-darwin-arm64@1.19.3` and `@opencode/cli-darwin-arm64@2.0.32`.
Each host created two independent native sessions in one physical project.
For v1, real `session.created` and `session.idle` events delivered one
`SessionStart` and one `Stop` per session through the Bash hook. A child
session's creation and shell completion stayed silent. Disposing and
reloading the project released the old bridge.

For v2, a local OpenAI-compatible provider supplied fixture responses at no
model cost. Real `session.execution.started` and
`session.execution.succeeded` events delivered exactly one `SessionStart`
and one `Stop` per session, with distinct native session identities. Real
forms in both primary sessions delivered private notifications; a child's
form stayed silent. The host's update manifest identified v2 source commit
`d4a6223d017e17f1beaa91d3e6ecc6511c5132ad`.

These macOS runs prove the host contracts and process bridge. Native Windows
execution remains a separate gate: the Windows bridge and Pester jobs must
pass on the exact integration commit before shipping a Windows fix.
