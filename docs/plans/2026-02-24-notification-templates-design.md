# Notification Message Templates

**Date**: 2026-02-24
**Branch**: `feat/configurable-notifications`
**Status**: Approved

## Problem

Notification message content is hardcoded (just the project name for most events). Users who want richer context (e.g., transcript summary on task completion, tool name on permission requests) have no way to configure it.

## Design: Format String Templates

### Config Schema

New key `notification_templates` in `config.json`:

```json
{
  "notification_templates": {
    "stop": "{project}: {summary}",
    "permission": "{project}: {tool_name}",
    "error": "{project}: error",
    "idle": "{project}",
    "question": "{project}"
  }
}
```

- **Omitted keys** fall back to `"{project}"` (current default behavior).
- **Empty or missing** `notification_templates` object = 100% backward-compatible.
- Unknown `{variables}` render as empty string (no crash).

### Available Variables

| Variable | Available in | Source |
|----------|-------------|--------|
| `{project}` | all events | project name resolution chain |
| `{summary}` | stop | `transcript_summary` from hook JSON (truncated to 120 chars) |
| `{tool_name}` | permission, error | `tool_name` from hook JSON |
| `{status}` | all events | computed status string (done/error/ready/etc.) |
| `{event}` | all events | event type name (Stop/PermissionRequest/etc.) |

### Category-to-Template Key Mapping

| Category | Template key |
|----------|-------------|
| `task.complete` | `stop` |
| `input.required` (PermissionRequest) | `permission` |
| `input.required` (elicitation_dialog) | `question` |
| `task.error` | `error` |
| Notification/idle_prompt | `idle` |

### Implementation Location

Python event parser in `peon.sh`, after per-event `msg` construction (~line 2860), before the shell variable output block. Uses `str.format_map()` with `collections.defaultdict(str)` for safe missing-key handling.

### CLI Interface

```bash
peon notifications template stop "{project}: {summary}"
peon notifications template permission "{project}: {tool_name}"
peon notifications template --reset
```

Writes to `notification_templates` in `config.json`.

### What Doesn't Change

- Position, dismiss, label configs (already shipped)
- Sound/category routing
- Default behavior with no template config
