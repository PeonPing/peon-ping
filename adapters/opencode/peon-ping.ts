/**
 * peon-ping for OpenCode — Thin Adapter
 *
 * Routes OpenCode events through peon.sh instead of re-implementing
 * sound playback, notifications, and trainer features in TypeScript.
 *
 * This gives OpenCode users access to ALL peon-ping features:
 * - Sound packs & rotation
 * - Desktop notifications
 * - Trainer reminders (pushups, squats, etc.)
 * - Spam detection
 * - SSH/devcontainer relay
 * - All config options via `peon` CLI
 * - Tab title updates
 *
 * Event mapping (OpenCode → peon.sh hook_event_name):
 *   session.created (no parent)  → SessionStart
 *   session.status (busy)        → UserPromptSubmit
 *   session.idle                 → Stop
 *   session.error                → PostToolUseFailure
 *   permission.asked             → PermissionRequest
 *
 * Requires peon-ping installed: brew install PeonPing/tap/peon-ping
 *   or: curl -fsSL peonping.com/install | bash
 */

import * as fs from "node:fs"
import * as path from "node:path"
import * as os from "node:os"
import { spawn } from "node:child_process"
import type { Plugin } from "@opencode-ai/plugin"

const PEON_SH_PATHS = [
  path.join(os.homedir(), ".claude", "hooks", "peon-ping", "peon.sh"),
  path.join(os.homedir(), ".openclaw", "hooks", "peon-ping", "peon.sh"),
]

function findPeonSh(): string | null {
  for (const p of PEON_SH_PATHS) {
    try {
      if (fs.existsSync(p)) return p
    } catch {}
  }
  return null
}

function setTabTitle(title: string): void {
  process.stdout.write(`\x1b]0;${title}\x07`)
}

export const PeonPingPlugin: Plugin = async ({ directory }) => {
  const projectName = path.basename(directory || process.cwd()) || "opencode"
  const peonSh = findPeonSh()

  if (!peonSh) {
    console.warn("[peon-ping] peon.sh not found. Install peon-ping first:")
    console.warn("  brew install PeonPing/tap/peon-ping")
    console.warn("  # or: curl -fsSL peonping.com/install | bash")
    return {}
  }

  const cwd = directory || process.cwd()
  const sessionId = `oc-${Date.now()}`
  const subagentSessionIds = new Set<string>()

  function firePeon(event: string): void {
    const payload = JSON.stringify({
      hook_event_name: event,
      notification_type: "",
      cwd,
      session_id: sessionId,
      permission_mode: "",
      source: "opencode",
    })

    try {
      const proc = spawn("bash", [peonSh], {
        stdio: ["pipe", "ignore", "ignore"],
      })
      proc.stdin.write(payload)
      proc.stdin.end()
      proc.unref()
    } catch {}
  }

  function isSubagent(sid: string | undefined): boolean {
    return !!sid && subagentSessionIds.has(sid)
  }

  setTimeout(() => {
    setTabTitle(`${projectName}: ready`)
    firePeon("SessionStart")
  }, 100)

  return {
    event: async ({ event }) => {
      switch (event.type) {
        case "session.created": {
          const info = (event as any).properties?.info
          if (info?.parentID) {
            subagentSessionIds.add(info.id)
            break
          }
          setTabTitle(`${projectName}: ready`)
          firePeon("SessionStart")
          break
        }

        case "session.updated": {
          const info = (event as any).properties?.info
          if (info?.parentID) subagentSessionIds.add(info.id)
          break
        }

        case "session.deleted": {
          const info = (event as any).properties?.info
          if (info?.id) subagentSessionIds.delete(info.id)
          break
        }

        case "session.idle": {
          const sid = (event as any).properties?.sessionID
          if (isSubagent(sid)) break
          setTabTitle(`\u25cf ${projectName}: done`)
          firePeon("Stop")
          break
        }

        case "session.error": {
          const sid = (event as any).properties?.sessionID
          if (isSubagent(sid)) break
          setTabTitle(`\u25cf ${projectName}: error`)
          firePeon("PostToolUseFailure")
          break
        }

        case "permission.asked": {
          setTabTitle(`\u25cf ${projectName}: needs approval`)
          firePeon("PermissionRequest")
          break
        }

        case "session.status": {
          const sid = (event as any).properties?.sessionID
          if (isSubagent(sid)) break
          const status = event.properties?.status
          const statusType = typeof status === "object" ? (status as any)?.type : status
          if (statusType === "busy" || statusType === "running") {
            setTabTitle(`${projectName}: working`)
            firePeon("UserPromptSubmit")
          }
          break
        }
      }
    },
  }
}

export default PeonPingPlugin
