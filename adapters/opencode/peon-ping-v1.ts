/**
 * peon-ping for OpenCode — Thin Adapter (v1 contract)
 *
 * OpenCode 1.x uses the v1 plugin contract: default export must be an object
 * with a callable `server` property (Plugin type from @opencode-ai/plugin).
 * This file is served to OpenCode 1.x by the installer.
 *
 * Routes OpenCode events through peon.sh instead of re-implementing
 * sound playback, notifications, and trainer features in TypeScript.
 *
 * Event mapping (OpenCode v1 events → peon.sh hook_event_name):
 *   session.created (no parent)  → SessionStart
 *   session.status (busy)        → UserPromptSubmit
 *   session.idle                 → Stop
 *   session.error                → PostToolUseFailure
 *   permission.asked             → PermissionRequest
 *   question.asked             → Notification (elicitation_dialog)
 *
 * Requires peon-ping installed: brew install PeonPing/tap/peon-ping
 *   or: curl -fsSL peonping.com/install | bash
 */

import * as fs from "node:fs"
import * as path from "node:path"
import * as os from "node:os"
import { spawn } from "node:child_process"
import type { Plugin } from "@opencode-ai/plugin"

const SCOPED_EVENT_TYPES = new Set([
  "session.created", "session.deleted", "session.execution.started",
  "session.execution.succeeded", "session.execution.failed", "session.execution.interrupted",
  "permission.asked", "form.created", "form.replied", "form.cancelled",
])

const MAX_PENDING_QUESTION_IDS = 100

const PEON_HOOK_PATHS = [
  path.join(os.homedir(), ".claude", "hooks", "peon-ping"),
  path.join(os.homedir(), ".openclaw", "hooks", "peon-ping"),
]

const IS_WINDOWS = process.platform === "win32"

function findPeonScript(): string | null {
  const ext = IS_WINDOWS ? "ps1" : "sh"
  for (const dir of PEON_HOOK_PATHS) {
    const p = path.join(dir, `peon.${ext}`)
    if (fs.existsSync(p)) return p
  }
  return null
}

function setTabTitle(title: string): void {
  if (!process.stdout.isTTY) return
  process.stdout.write(`\x1b]0;${title}\x07`)
}

/**
 * Creates the v1 plugin instance. Exported as `server` in the PluginModule.
 */
function createPeonPingPlugin(directory?: string): Plugin {
  return async ({ directory: dir }) => {
    const projectName = path.basename(dir || directory || process.cwd()) || "opencode"
    const peonScript = findPeonScript()

    if (!peonScript) {
      if (IS_WINDOWS) {
        console.warn("[peon-ping] peon.ps1 not found. Install peon-ping first:")
        console.warn("  iwr -useb https://peonping.com/install.ps1 | iex")
      } else {
        console.warn("[peon-ping] peon.sh not found. Install peon-ping first:")
        console.warn("  brew install PeonPing/tap/peon-ping")
        console.warn("  # or: curl -fsSL peonping.com/install | bash")
      }
      return {}
    }

    const cwd = dir || directory || process.cwd()
    const sessionId = `oc-${Date.now()}`
    const subagentSessionIds = new Set<string>()
    const busySessions = new Set<string>()
    let lastSessionStart = 0
    const pendingQuestionIds = new Set<string>()

    function firePeon(event: string, notificationType = ""): void {
      const payload = JSON.stringify({
        hook_event_name: event,
        notification_type: notificationType,
        cwd,
        session_id: sessionId,
        permission_mode: "",
        source: "opencode",
      })

      try {
        const cmd = IS_WINDOWS ? "powershell.exe" : "bash"
        const args = IS_WINDOWS
          ? ["-NoProfile", "-NonInteractive", "-File", peonScript]
          : [peonScript]
        const proc = spawn(cmd, args, { stdio: ["pipe", "ignore", "ignore"] })
        proc.stdin!.write(payload)
        proc.stdin!.end()
        proc.unref()
      } catch {}
    }

    function isSubagent(sid: string | undefined): boolean {
      return !!sid && subagentSessionIds.has(sid)
    }

    setTabTitle(`${projectName}: ready`)

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
            lastSessionStart = Date.now()
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

          case "session.execution.started": {
            const sid = (event as any).properties?.sessionID
            if (isSubagent(sid) || busySessions.has(sid)) break
            busySessions.add(sid)
            const lastStart = lastSessionStart
            if (lastStart === undefined || Date.now() - lastStart > 3000) {
              setTabTitle(`${projectName}: ready`)
              firePeon("SessionStart")
            }
            break
          }

          case "session.execution.succeeded": {
            const sid = (event as any).properties?.sessionID
            if (isSubagent(sid)) break
            if (sid) busySessions.delete(sid)
            setTabTitle(`\u25cf ${projectName}: done`)
            firePeon("Stop")
            break
          }

          case "session.execution.failed": {
            const sid = (event as any).properties?.sessionID
            if (isSubagent(sid)) break
            if (sid) busySessions.delete(sid)
            setTabTitle(`\u25cf ${projectName}: error`)
            firePeon("PostToolUseFailure")
            break
          }

          case "session.execution.interrupted": {
            const sid = (event as any).properties?.sessionID
            if (typeof sid === "string") busySessions.delete(sid)
            break
          }

          case "session.idle": {
            const sid = (event as any).properties?.sessionID
            if (isSubagent(sid)) break
            if (sid) busySessions.delete(sid)
            setTabTitle(`\u25cf ${projectName}: done`)
            firePeon("Stop")
            break
          }

          case "session.error": {
            const sid = (event as any).properties?.sessionID
            if (isSubagent(sid)) break
            if (sid) busySessions.delete(sid)
            setTabTitle(`\u25cf ${projectName}: error`)
            firePeon("PostToolUseFailure")
            break
          }

          case "permission.asked": {
            setTabTitle(`\u25cf ${projectName}: needs approval`)
            firePeon("PermissionRequest")
            break
          }

          case "form.created": {
            const properties = (event as any).properties
            const requestId = properties?.id
            if (typeof requestId !== "string" || pendingQuestionIds.has(requestId)) break
            if (pendingQuestionIds.size >= MAX_PENDING_QUESTION_IDS) {
              pendingQuestionIds.delete(pendingQuestionIds.values().next().value!)
            }
            pendingQuestionIds.add(requestId)
            setTabTitle(`\u25cf ${projectName}: needs input`)
            firePeon("Notification", "elicitation_dialog")
            break
          }

          case "form.replied":
          case "form.cancelled": {
            const properties = (event as any).properties
            const requestId = properties?.requestID ?? properties?.id
            if (typeof requestId === "string") pendingQuestionIds.delete(requestId)
            break
          }

          case "question.asked":
          case "question.v2.asked": {
            const properties = (event as any).properties
            if (isSubagent(properties?.sessionID)) break
            const requestId = properties?.id
            if (typeof requestId !== "string" || pendingQuestionIds.has(requestId)) break
            if (pendingQuestionIds.size >= MAX_PENDING_QUESTION_IDS) {
              pendingQuestionIds.delete(pendingQuestionIds.values().next().value!)
            }
            pendingQuestionIds.add(requestId)
            setTabTitle(`\u25cf ${projectName}: needs input`)
            firePeon("Notification", "elicitation_dialog")
            break
          }

          case "question.replied":
          case "question.rejected":
          case "question.v2.replied":
          case "question.v2.rejected": {
            const properties = (event as any).properties
            const requestId = properties?.requestID ?? properties?.id
            if (typeof requestId === "string") pendingQuestionIds.delete(requestId)
            break
          }

          case "session.status": {
            const sid = (event as any).properties?.sessionID
            if (isSubagent(sid)) break
            const status = event.properties?.status
            const statusType = typeof status === "object" ? (status as any)?.type : status
            if (statusType === "busy" || statusType === "running") {
              if (sid && !busySessions.has(sid)) {
                busySessions.add(sid)
                if (Date.now() - lastSessionStart > 3000) {
                  setTabTitle(`${projectName}: working`)
                  firePeon("UserPromptSubmit")
                }
              }
            } else {
              if (sid) busySessions.delete(sid)
            }
            break
          }
        }
      },
    }
  }
}

/**
 * v1 plugin module export.
 * OpenCode 1.x expects: { server: Plugin }
 */
export const server: Plugin = createPeonPingPlugin()

export default { server }
