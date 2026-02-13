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

/** CESP v1.0 category names */
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

/** A single sound entry in the manifest */
interface CESPSound {
  file: string
  label: string
  sha256?: string
}

/** A category entry containing its sounds */
interface CESPCategoryEntry {
  sounds: CESPSound[]
}

/** openpeon.json manifest per CESP v1.0 */
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

/** Plugin configuration */
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
}

/** Internal runtime state */
interface PeonState {
  last_played: Partial<Record<CESPCategory, string>>
  session_packs: Record<string, string>
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const PLUGIN_DIR = path.join(os.homedir(), ".config", "opencode", "peon-ping")
const CONFIG_PATH = path.join(PLUGIN_DIR, "config.json")
const STATE_PATH = path.join(PLUGIN_DIR, ".state.json")
const PAUSED_PATH = path.join(PLUGIN_DIR, ".paused")

/** Default packs directory per CESP spec Section 7.2 */
const DEFAULT_PACKS_DIR = path.join(os.homedir(), ".openpeon", "packs")

const REGISTRY_URL = "https://peonping.github.io/registry/index.json"

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

/** Terminal app names for macOS focus detection */
const TERMINAL_APPS = [
  "Terminal",
  "iTerm2",
  "Warp",
  "Alacritty",
  "kitty",
  "WezTerm",
  "Ghostty",
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

/**
 * Resolve the packs directory. Supports user override via config.
 * Falls back to ~/.openpeon/packs/ per CESP spec.
 */
function getPacksDir(config: PeonConfig): string {
  return config.packs_dir || DEFAULT_PACKS_DIR
}

/**
 * Load a CESP manifest (openpeon.json) from a pack directory.
 * Falls back to manifest.json for legacy packs, migrating category names.
 */
function loadManifest(packDir: string): CESPManifest | null {
  // Try openpeon.json first (CESP v1.0)
  const cespPath = path.join(packDir, "openpeon.json")
  if (fs.existsSync(cespPath)) {
    try {
      const raw = fs.readFileSync(cespPath, "utf8")
      return JSON.parse(raw) as CESPManifest
    } catch {
      return null
    }
  }

  // Fall back to legacy manifest.json and migrate
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

/**
 * Migrate a legacy peon-ping manifest.json to CESP v1.0 format.
 * Per CESP spec Appendix B.
 */
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

/**
 * List available packs in the packs directory.
 * A valid pack has either openpeon.json or manifest.json.
 */
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

/**
 * Resolve a CESP category from the manifest.
 * Per CESP spec Section 5 resolution order.
 */
function resolveCategory(
  manifest: CESPManifest,
  category: CESPCategory,
): CESPCategoryEntry | null {
  // 1. Direct lookup in categories
  const direct = manifest.categories[category]
  if (direct && direct.sounds.length > 0) return direct

  // 2. Category not found — no sounds for this category
  return null
}

/**
 * Pick a random sound from a category, avoiding the last played.
 * Per CESP spec Section 7.1.
 */
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

/**
 * Resolve the active pack for a session, supporting pack_rotation.
 */
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

  // Fall back to first available pack
  return available[0] || config.active_pack
}

// ---------------------------------------------------------------------------
// Platform: Audio Playback
// ---------------------------------------------------------------------------

function playSound(filePath: string, volume: number): void {
  if (!fs.existsSync(filePath)) return

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

function sendNotification(msg: string, title: string): void {
  const platform = os.platform()

  if (platform === "darwin") {
    try {
      const proc = Bun.spawn(
        [
          "osascript",
          "-e",
          `display notification "${msg}" with title "${title}"`,
        ],
        { stdout: "ignore", stderr: "ignore" },
      )
      proc.unref()
    } catch {}
  } else if (platform === "linux") {
    try {
      const proc = Bun.spawn(["notify-send", title, msg], {
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

  // --- In-memory state for debouncing and spam detection ---
  const promptTimestamps: number[] = []
  const lastEventTime: Partial<Record<CESPCategory, number>> = {}

  /**
   * Check if an event should be debounced.
   * Per CESP spec Section 6.3: players SHOULD debounce rapid events.
   */
  function shouldDebounce(category: CESPCategory): boolean {
    const now = Date.now()
    const last = lastEventTime[category]
    if (last && now - last < config.debounce_ms) return true
    lastEventTime[category] = now
    return false
  }

  /**
   * Check for rapid-prompt spam (user.spam).
   */
  function checkSpam(): boolean {
    if (config.categories["user.spam"] === false) return false

    const now = Date.now() / 1000
    const window = config.spam_window_seconds
    const threshold = config.spam_threshold

    // Prune old timestamps and add current
    const cutoff = now - window
    while (promptTimestamps.length > 0 && promptTimestamps[0] < cutoff) {
      promptTimestamps.shift()
    }
    promptTimestamps.push(now)

    return promptTimestamps.length >= threshold
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
      notifyMsg?: string
    } = {},
  ): Promise<void> {
    const {
      status = "",
      marker = "",
      notify = false,
      notifyMsg = "",
    } = opts
    const paused = isPaused()

    // Tab title (always, even when paused)
    if (status) {
      setTabTitle(`${marker}${projectName}: ${status}`)
    }

    // Debounce check
    if (shouldDebounce(category)) return

    // Sound
    if (config.categories[category] !== false && !paused) {
      const currentState = loadState()
      const sound = pickSound(manifest!, category, currentState)
      if (sound) {
        // Sound paths are relative to manifest per CESP spec
        const soundPath = path.join(packDir, sound.file)
        playSound(soundPath, config.volume)
        saveState(currentState)
      }
    }

    // Desktop notification (only when terminal is NOT focused)
    if (notify && !paused) {
      const focused = await isTerminalFocused()
      if (!focused) {
        sendNotification(
          notifyMsg,
          `${marker}${projectName}: ${status}`,
        )
      }
    }
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
            notifyMsg: `${projectName} \u2014 Task complete`,
          })
          break
        }

        // Task error
        case "session.error": {
          await emitCESP("task.error", {
            status: "error",
            marker: "\u25cf ",
            notify: true,
            notifyMsg: `${projectName} \u2014 Error occurred`,
          })
          break
        }

        // Input required (permission prompt)
        case "permission.asked": {
          await emitCESP("input.required", {
            status: "needs approval",
            marker: "\u25cf ",
            notify: true,
            notifyMsg: `${projectName} \u2014 Permission needed`,
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
