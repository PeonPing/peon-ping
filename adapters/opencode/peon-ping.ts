/**
 * peon-ping for OpenCode — CESP v1.0 Adapter
 *
 * A CESP (Coding Event Sound Pack Specification) player for OpenCode.
 * Plays sound effects from OpenPeon-compatible sound packs when coding
 * events occur: task completion, errors, permission prompts, and more.
 *
 * Conforms to the CESP v1.0 specification:
 * https://github.com/PeonPing/openpeon
 *
 * Features:
 * - Reads openpeon.json manifests per CESP v1.0
 * - Maps OpenCode events to CESP categories
 * - Registry integration: install packs from the OpenPeon registry
 * - Desktop notifications when the terminal is not focused
 * - Tab title updates (project: status)
 * - Rapid-prompt detection (user.spam)
 * - Pause/resume support
 * - Pack rotation per session
 * - SSH/devcontainer relay support
 * - category_aliases for backward compatibility with legacy packs
 *
 * Setup:
 *   1. Copy this file to ~/.config/opencode/plugins/peon-ping.ts
 *   2. Install a pack (see README for details)
 *   3. Restart OpenCode
 *
 * Ported from https://github.com/tonyyont/peon-ping
 */

import * as fs from "node:fs"
import * as path from "node:path"
import * as os from "node:os"
import type { Plugin } from "@opencode-ai/plugin"

// ---------------------------------------------------------------------------
// CESP v1.0 Types
// ---------------------------------------------------------------------------

type CESPCategory =
  | "session.start"
  | "session.end"
  | "task.acknowledge"
  | "task.complete"
  | "task.error"
  | "task.progress"
  | "input.required"
  | "resource.limit"
  | "user.spam"

const CESP_CATEGORIES: readonly CESPCategory[] = [
  "session.start",
  "session.end",
  "task.acknowledge",
  "task.complete",
  "task.error",
  "task.progress",
  "input.required",
  "resource.limit",
  "user.spam",
] as const

interface CESPSound {
  file: string
  label: string
  sha256?: string
}

interface CESPCategoryEntry {
  sounds: CESPSound[]
}

interface CESPManifest {
  cesp_version: string
  name: string
  display_name: string
  version: string
  description?: string
  author?: { name: string; github?: string }
  license?: string
  language?: string
  homepage?: string
  tags?: string[]
  preview?: string
  min_player_version?: string
  categories: Partial<Record<CESPCategory, CESPCategoryEntry>>
  category_aliases?: Record<string, CESPCategory>
}

interface PeonConfig {
  active_pack: string
  volume: number
  enabled: boolean
  categories: Partial<Record<CESPCategory, boolean>>
  spam_threshold: number
  spam_window_seconds: number
  pack_rotation: string[]
  packs_dir?: string
  debounce_ms: number
  relay_host?: string
  relay_port?: number
}

interface PeonState {
  last_played: Partial<Record<CESPCategory, string>>
  session_packs: Record<string, string>
}

// ---------------------------------------------------------------------------
// Platform Detection & Relay
// ---------------------------------------------------------------------------

type RuntimePlatform = "mac" | "linux" | "wsl" | "ssh" | "devcontainer"

interface RelayConfig {
  host: string
  port: number
}

function detectPlatform(): RuntimePlatform {
  if (process.env.SSH_CONNECTION || process.env.SSH_CLIENT) return "ssh"
  if (process.env.REMOTE_CONTAINERS || process.env.CODESPACES) return "devcontainer"
  if (os.platform() === "linux") {
    try {
      const ver = fs.readFileSync("/proc/version", "utf8")
      if (/microsoft/i.test(ver)) return "wsl"
    } catch {}
    return "linux"
  }
  if (os.platform() === "darwin") return "mac"
  return "linux"
}

function getRelayConfig(config: PeonConfig, platform: RuntimePlatform): RelayConfig {
  const host = config.relay_host
    || process.env.PEON_RELAY_HOST
    || (platform === "devcontainer" ? "host.docker.internal" : "localhost")
  const port = config.relay_port
    || Number(process.env.PEON_RELAY_PORT)
    || 19998
  return { host, port }
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const PLUGIN_DIR = path.join(os.homedir(), ".config", "opencode", "peon-ping")
const CONFIG_PATH = path.join(PLUGIN_DIR, "config.json")
const STATE_PATH = path.join(PLUGIN_DIR, ".state.json")
const PAUSED_PATH = path.join(PLUGIN_DIR, ".paused")
const DEFAULT_PACKS_DIR = path.join(os.homedir(), ".openpeon", "packs")

const DEFAULT_CONFIG: PeonConfig = {
  active_pack: "peon",
  volume: 0.5,
  enabled: true,
  categories: {
    "session.start": true,
    "session.end": true,
    "task.acknowledge": true,
    "task.complete": true,
    "task.error": true,
    "task.progress": true,
    "input.required": true,
    "resource.limit": true,
    "user.spam": true,
  },
  spam_threshold: 3,
  spam_window_seconds: 10,
  pack_rotation: [],
  debounce_ms: 500,
}

const TERMINAL_APPS = [
  "Terminal",
  "iTerm2",
  "Warp",
  "Alacritty",
  "kitty",
  "WezTerm",
  "ghostty",
  "Hyper",
]

// ---------------------------------------------------------------------------
// Helpers: Config & State
// ---------------------------------------------------------------------------

function loadConfig(): PeonConfig {
  try {
    const raw = fs.readFileSync(CONFIG_PATH, "utf8")
    const parsed = JSON.parse(raw)
    return {
      ...DEFAULT_CONFIG,
      ...parsed,
      categories: { ...DEFAULT_CONFIG.categories, ...parsed.categories },
    }
  } catch {
    return { ...DEFAULT_CONFIG }
  }
}

function loadState(): PeonState {
  try {
    const raw = fs.readFileSync(STATE_PATH, "utf8")
    return JSON.parse(raw)
  } catch {
    return { last_played: {}, session_packs: {} }
  }
}

function saveState(state: PeonState): void {
  try {
    fs.mkdirSync(path.dirname(STATE_PATH), { recursive: true })
    fs.writeFileSync(STATE_PATH, JSON.stringify(state, null, 2))
  } catch {
    // Non-critical
  }
}

function isPaused(): boolean {
  return fs.existsSync(PAUSED_PATH)
}

// ---------------------------------------------------------------------------
// Helpers: Pack Management (CESP v1.0)
// ---------------------------------------------------------------------------

function getPacksDir(config: PeonConfig): string {
  return config.packs_dir || DEFAULT_PACKS_DIR
}

function loadManifest(packDir: string): CESPManifest | null {
  const cespPath = path.join(packDir, "openpeon.json")
  if (fs.existsSync(cespPath)) {
    try {
      const raw = fs.readFileSync(cespPath, "utf8")
      return JSON.parse(raw) as CESPManifest
    } catch {
      return null
    }
  }

  const legacyPath = path.join(packDir, "manifest.json")
  if (fs.existsSync(legacyPath)) {
    try {
      const raw = fs.readFileSync(legacyPath, "utf8")
      const legacy = JSON.parse(raw)
      return migrateLegacyManifest(legacy)
    } catch {
      return null
    }
  }

  return null
}

function migrateLegacyManifest(legacy: any): CESPManifest {
  const LEGACY_MAP: Record<string, CESPCategory> = {
    greeting: "session.start",
    acknowledge: "task.acknowledge",
    complete: "task.complete",
    error: "task.error",
    permission: "input.required",
    resource_limit: "resource.limit",
    annoyed: "user.spam",
  }

  const categories: Partial<Record<CESPCategory, CESPCategoryEntry>> = {}

  if (legacy.categories) {
    for (const [oldName, entry] of Object.entries(legacy.categories)) {
      const cespName = LEGACY_MAP[oldName] || oldName
      if (CESP_CATEGORIES.includes(cespName as CESPCategory)) {
        const catEntry = entry as any
        const sounds: CESPSound[] = (catEntry.sounds || []).map((s: any) => ({
          file: s.file.includes("/") ? s.file : `sounds/${s.file}`,
          label: s.label || s.line || s.file,
          ...(s.sha256 ? { sha256: s.sha256 } : {}),
        }))
        categories[cespName as CESPCategory] = { sounds }
      }
    }
  }

  return {
    cesp_version: "1.0",
    name: legacy.name || "unknown",
    display_name: legacy.display_name || legacy.name || "Unknown Pack",
    version: legacy.version || "0.0.0",
    description: legacy.description,
    categories,
    category_aliases: LEGACY_MAP,
  }
}

function listPacks(packsDir: string): string[] {
  try {
    return fs
      .readdirSync(packsDir)
      .filter((name) => {
        const dir = path.join(packsDir, name)
        try {
          if (!fs.statSync(dir).isDirectory()) return false
        } catch {
          return false
        }
        return (
          fs.existsSync(path.join(dir, "openpeon.json")) ||
          fs.existsSync(path.join(dir, "manifest.json"))
        )
      })
      .sort()
  } catch {
    return []
  }
}

function resolveCategory(
  manifest: CESPManifest,
  category: CESPCategory,
): CESPCategoryEntry | null {
  const direct = manifest.categories[category]
  if (direct && direct.sounds.length > 0) return direct
  return null
}

function pickSound(
  manifest: CESPManifest,
  category: CESPCategory,
  state: PeonState,
): CESPSound | null {
  const entry = resolveCategory(manifest, category)
  if (!entry || entry.sounds.length === 0) return null

  const sounds = entry.sounds
  const lastFile = state.last_played[category]

  let candidates = sounds
  if (sounds.length > 1 && lastFile) {
    candidates = sounds.filter((s) => s.file !== lastFile)
    if (candidates.length === 0) candidates = sounds
  }

  const pick = candidates[Math.floor(Math.random() * candidates.length)]
  state.last_played[category] = pick.file
  return pick
}

function resolveActivePack(
  config: PeonConfig,
  state: PeonState,
  sessionId: string,
  packsDir: string,
): string {
  const available = listPacks(packsDir)

  if (config.pack_rotation.length > 0) {
    const validRotation = config.pack_rotation.filter((p) =>
      available.includes(p),
    )
    if (validRotation.length > 0) {
      const existing = state.session_packs[sessionId]
      if (existing && validRotation.includes(existing)) {
        return existing
      }
      const pick =
        validRotation[Math.floor(Math.random() * validRotation.length)]
      state.session_packs[sessionId] = pick
      return pick
    }
  }

  if (available.includes(config.active_pack)) {
    return config.active_pack
  }

  return available[0] || config.active_pack
}

function escapeAppleScript(s: string): string {
  return s.replace(/\\/g, "\\\\").replace(/"/g, '\\"')
}

function createDebounceChecker(debounceMs: number) {
  const lastEventTime: Partial<Record<CESPCategory, number>> = {}

  return function shouldDebounce(category: CESPCategory, now?: number): boolean {
    const time = now ?? Date.now()
    const last = lastEventTime[category]
    if (last && time - last < debounceMs) return true
    lastEventTime[category] = time
    return false
  }
}

function createSpamChecker(threshold: number, windowSeconds: number) {
  const promptTimestamps: number[] = []

  return function checkSpam(nowSeconds?: number): boolean {
    const now = nowSeconds ?? Date.now() / 1000
    const cutoff = now - windowSeconds

    while (promptTimestamps.length > 0 && promptTimestamps[0] < cutoff) {
      promptTimestamps.shift()
    }
    promptTimestamps.push(now)

    return promptTimestamps.length >= threshold
  }
}

// ---------------------------------------------------------------------------
// Platform: Audio Playback
// ---------------------------------------------------------------------------

function playSound(
  filePath: string,
  volume: number,
  runtimePlatform: RuntimePlatform = "mac",
  relay: RelayConfig | null = null,
  packsDir: string = "",
): void {
  if (!fs.existsSync(filePath)) return

  // SSH / devcontainer: relay to local machine
  if ((runtimePlatform === "ssh" || runtimePlatform === "devcontainer") && relay) {
    const packsParent = path.dirname(packsDir)
    const relPath = path.relative(packsParent, filePath)
    const encoded = encodeURIComponent(relPath)
    fetch(`http://${relay.host}:${relay.port}/play?file=${encoded}`, {
      headers: { "X-Volume": String(volume) },
    }).catch(() => {})
    return
  }

  const platform = os.platform()

  if (platform === "darwin") {
    const proc = Bun.spawn(["afplay", "-v", String(volume), filePath], {
      stdout: "ignore",
      stderr: "ignore",
    })
    proc.unref()
  } else if (platform === "linux") {
    let isWSL = false
    try {
      const ver = fs.readFileSync("/proc/version", "utf8")
      isWSL = /microsoft/i.test(ver)
    } catch {}

    if (isWSL) {
      const wpath = filePath.replace(/\//g, "\\")
      const cmd = `
        Add-Type -AssemblyName PresentationCore
        $p = New-Object System.Windows.Media.MediaPlayer
        $p.Open([Uri]::new('file:///${wpath}'))
        $p.Volume = ${volume}
        Start-Sleep -Milliseconds 200
        $p.Play()
        Start-Sleep -Seconds 3
        $p.Close()
      `
      const proc = Bun.spawn(
        ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", cmd],
        { stdout: "ignore", stderr: "ignore" },
      )
      proc.unref()
    } else {
      try {
        const proc = Bun.spawn(["paplay", filePath], {
          stdout: "ignore",
          stderr: "ignore",
        })
        proc.unref()
      } catch {
        try {
          const proc = Bun.spawn(["aplay", filePath], {
            stdout: "ignore",
            stderr: "ignore",
          })
          proc.unref()
        } catch {}
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Platform: Desktop Notifications
// ---------------------------------------------------------------------------

/** Notification options for rich desktop notifications */
interface NotifyOptions {
  title: string
  subtitle?: string
  body: string
  /** Group ID for notification coalescing (terminal-notifier only) */
  group?: string
  /** Path to custom icon image (terminal-notifier only) */
  iconPath?: string
}

/**
 * Detect whether terminal-notifier is available.
 * Cached at plugin init for performance.
 *
 * TODO: terminal-notifier (github.com/julienXX/terminal-notifier) is unmaintained
 * (last commit 2021) and uses the deprecated NSUserNotification API. Consider
 * migrating to jamf/Notifier (github.com/jamf/Notifier) which uses the modern
 * UserNotifications framework and has built-in --rebrand support for custom icons.
 * Migrate when jamf/Notifier is published to Homebrew or when terminal-notifier
 * breaks on a future macOS release.
 */
function detectTerminalNotifier(): string | null {
  try {
    const result = Bun.spawnSync(["which", "terminal-notifier"], {
      stdout: "pipe",
      stderr: "ignore",
    })
    const p = new TextDecoder().decode(result.stdout).trim()
    if (p && result.exitCode === 0) return p
  } catch {}
  return null
}

/**
 * Resolve the peon-ping icon path for notifications.
 * Checks Homebrew libexec, then OpenCode plugin dir.
 */
function resolveIconPath(): string | null {
  const candidates = [
    // Homebrew-installed icon (via formula)
    "/opt/homebrew/opt/peon-ping/libexec/docs/peon-icon.png",
    "/usr/local/opt/peon-ping/libexec/docs/peon-icon.png",
    // Plugin dir
    path.join(PLUGIN_DIR, "peon-icon.png"),
  ]
  for (const p of candidates) {
    if (fs.existsSync(p)) return p
  }
  return null
}

function sendNotification(
  opts: NotifyOptions,
  terminalNotifierPath: string | null,
  runtimePlatform: RuntimePlatform = "mac",
  relay: RelayConfig | null = null,
): void {
  // SSH / devcontainer: relay notification to local machine
  if ((runtimePlatform === "ssh" || runtimePlatform === "devcontainer") && relay) {
    fetch(`http://${relay.host}:${relay.port}/notify`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: opts.title, message: opts.body }),
    }).catch(() => {})
    return
  }

  const platform = os.platform()

  if (platform === "darwin") {
    // Prefer terminal-notifier for rich notifications (custom icon, grouping)
    // TODO: Replace with jamf/Notifier when available via Homebrew — see detectTerminalNotifier()
    if (terminalNotifierPath) {
      try {
        const args = [
          terminalNotifierPath,
          "-title", opts.title,
          "-message", opts.body,
          "-group", opts.group || "peon-ping",
        ]
        if (opts.subtitle) {
          args.push("-subtitle", opts.subtitle)
        }
        if (opts.iconPath) {
          args.push("-appIcon", opts.iconPath)
        }
        const proc = Bun.spawn(args, { stdout: "ignore", stderr: "ignore" })
        proc.unref()
        return
      } catch {
        // Fall through to osascript
      }
    }

    // Fallback: osascript with subtitle support
    try {
      const title = escapeAppleScript(opts.title)
      const body = escapeAppleScript(opts.body)
      let script = `display notification "${body}" with title "${title}"`
      if (opts.subtitle) {
        script += ` subtitle "${escapeAppleScript(opts.subtitle)}"`
      }
      const proc = Bun.spawn(
        ["osascript", "-e", script],
        { stdout: "ignore", stderr: "ignore" },
      )
      proc.unref()
    } catch {}
  } else if (platform === "linux") {
    try {
      const args = ["notify-send", opts.title]
      // Combine subtitle and body for Linux
      const fullBody = opts.subtitle ? `${opts.subtitle}\n${opts.body}` : opts.body
      args.push(fullBody)
      if (opts.iconPath) {
        args.push("-i", opts.iconPath)
      }
      const proc = Bun.spawn(args, {
        stdout: "ignore",
        stderr: "ignore",
      })
      proc.unref()
    } catch {}
  }
}

// ---------------------------------------------------------------------------
// Platform: Terminal Focus Detection
// ---------------------------------------------------------------------------

async function isTerminalFocused(): Promise<boolean> {
  if (os.platform() !== "darwin") return false

  try {
    const proc = Bun.spawn(
      [
        "osascript",
        "-e",
        'tell application "System Events" to get name of first process whose frontmost is true',
      ],
      { stdout: "pipe", stderr: "ignore" },
    )
    const output = await new Response(proc.stdout).text()
    const frontmost = output.trim()
    return TERMINAL_APPS.some(
      (name) => name.toLowerCase() === frontmost.toLowerCase(),
    )
  } catch {
    return false
  }
}

// ---------------------------------------------------------------------------
// Tab Title
// ---------------------------------------------------------------------------

function setTabTitle(title: string): void {
  process.stdout.write(`\x1b]0;${title}\x07`)
}

// ---------------------------------------------------------------------------
// OpenCode -> CESP v1.0 Event Mapping
// ---------------------------------------------------------------------------
//
// Per CESP spec Section 6, each player publishes its event mapping.
//
// | OpenCode Event              | CESP Category    |
// |-----------------------------|------------------|
// | Plugin init / session start | session.start    |
// | session.status (busy)       | task.acknowledge |
// | session.idle                | task.complete    |
// | session.error               | task.error       |
// | permission.asked            | input.required   |
// | (rate limit detection)      | resource.limit   |
// | Rapid prompts detected      | user.spam        |
//

// ---------------------------------------------------------------------------
// Plugin
// ---------------------------------------------------------------------------

export const PeonPingPlugin: Plugin = async ({ directory }) => {
  const projectName = path.basename(directory || process.cwd()) || "opencode"

  const config = loadConfig()
  if (!config.enabled) return {}

  const packsDir = getPacksDir(config)
  const sessionId = `oc-${Date.now()}`

  // Resolve active pack
  const state = loadState()
  const activePack = resolveActivePack(config, state, sessionId, packsDir)
  saveState(state)

  const packDir = path.join(packsDir, activePack)
  const manifest = loadManifest(packDir)
  if (!manifest) {
    // No valid pack found -- plugin is a no-op
    return {}
  }

  // --- Platform detection & relay config ---
  const runtimePlatform = detectPlatform()
  const relay = (runtimePlatform === "ssh" || runtimePlatform === "devcontainer")
    ? getRelayConfig(config, runtimePlatform) : null

  // --- Notification capabilities (detected once at init) ---
  const terminalNotifierPath = detectTerminalNotifier()
  const iconPath = resolveIconPath()

  // --- In-memory state for debouncing and spam detection ---
  const shouldDebounce = createDebounceChecker(config.debounce_ms)
  const checkSpamRaw = createSpamChecker(config.spam_threshold, config.spam_window_seconds)

  /** Wrapper that respects the user.spam category toggle. */
  function checkSpam(): boolean {
    if (config.categories["user.spam"] === false) return false
    return checkSpamRaw()
  }

  /**
   * Core handler: play a sound and optionally send a notification.
   */
  async function emitCESP(
    category: CESPCategory,
    opts: {
      status?: string
      marker?: string
      notify?: boolean
      notifyTitle?: string
    } = {},
  ): Promise<void> {
    const {
      status = "",
      marker = "",
      notify = false,
      notifyTitle = "",
    } = opts
    const paused = isPaused()

    // Tab title (always, even when paused)
    if (status) {
      setTabTitle(`${marker}${projectName}: ${status}`)
    }

    // Debounce check
    if (shouldDebounce(category)) return

    // Pick sound (needed for both playback and notification body)
    let pickedSound: CESPSound | null = null
    if (config.categories[category] !== false && !paused) {
      const currentState = loadState()
      pickedSound = pickSound(manifest!, category, currentState)
      if (pickedSound) {
        const soundPath = path.join(packDir, pickedSound.file)
        playSound(soundPath, config.volume, runtimePlatform, relay, packsDir)
        saveState(currentState)
      }
    }

    // Desktop notification (only when terminal is NOT focused)
    if (notify && !paused) {
      const focused = await isTerminalFocused()
      if (!focused) {
        const title = notifyTitle || `${marker}${projectName}: ${status}`
        const body = pickedSound?.label
          ? `\uD83D\uDDE3 "${pickedSound.label}"`
          : `${marker}${projectName}`
        sendNotification(
          {
            title,
            subtitle: manifest!.display_name,
            body,
            group: `peon-ping-${projectName}`,
            iconPath: iconPath || undefined,
          },
          terminalNotifierPath,
          runtimePlatform,
          relay,
        )
      }
    }
  }

  // --- Relay health check on init (SSH/devcontainer only) ---
  if (relay) {
    fetch(`http://${relay.host}:${relay.port}/health`)
      .then((res) => {
        if (!res.ok) {
          console.warn(`[peon-ping] relay health check failed (HTTP ${res.status})`)
        }
      })
      .catch(() => {
        console.warn(`[peon-ping] relay unreachable at ${relay.host}:${relay.port} — sounds will not play`)
      })
  }

  // --- Emit session.start on plugin init ---
  setTimeout(
    () =>
      emitCESP("session.start", {
        status: "ready",
      }),
    100,
  )

  // --- Return OpenCode event hooks ---
  return {
    event: async ({ event }) => {
      switch (event.type) {
        // Task complete
        case "session.idle": {
          await emitCESP("task.complete", {
            status: "done",
            marker: "\u25cf ",
            notify: true,
            notifyTitle: `${projectName} \u2014 Task complete`,
          })
          break
        }

        // Task error
        case "session.error": {
          await emitCESP("task.error", {
            status: "error",
            marker: "\u25cf ",
            notify: true,
            notifyTitle: `${projectName} \u2014 Error occurred`,
          })
          break
        }

        // Input required (permission prompt)
        case "permission.asked": {
          await emitCESP("input.required", {
            status: "needs approval",
            marker: "\u25cf ",
            notify: true,
            notifyTitle: `${projectName} \u2014 Permission needed`,
          })
          break
        }

        // Session created
        case "session.created": {
          await emitCESP("session.start", {
            status: "ready",
          })
          break
        }

        // Status change (working / busy)
        case "session.status": {
          const status = event.properties?.status
          if (status === "busy" || status === "running") {
            // Check for spam first
            if (checkSpam()) {
              await emitCESP("user.spam", {
                status: "working",
              })
            } else {
              // task.acknowledge: tool accepted work
              await emitCESP("task.acknowledge", {
                status: "working",
              })
            }
          }
          break
        }
      }
    },

    // Track user messages for spam detection
    "message.updated": async (props: any) => {
      if (props?.properties?.role === "user") {
        checkSpam()
      }
    },
  }
}

export default PeonPingPlugin
