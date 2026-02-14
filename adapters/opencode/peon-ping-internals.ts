/**
 * peon-ping internals — extracted pure logic for testability.
 *
 * This module contains all the deterministic/pure functions from peon-ping.ts
 * so they can be unit-tested independently of platform I/O.
 *
 * The main peon-ping.ts plugin re-exports or calls these functions.
 */

import * as fs from "node:fs"
import * as path from "node:path"
import * as os from "node:os"

// ---------------------------------------------------------------------------
// CESP v1.0 Types
// ---------------------------------------------------------------------------

/** CESP v1.0 category names */
export type CESPCategory =
  | "session.start"
  | "session.end"
  | "task.acknowledge"
  | "task.complete"
  | "task.error"
  | "task.progress"
  | "input.required"
  | "resource.limit"
  | "user.spam"

export const CESP_CATEGORIES: readonly CESPCategory[] = [
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
export interface CESPSound {
  file: string
  label: string
  sha256?: string
}

/** A category entry containing its sounds */
export interface CESPCategoryEntry {
  sounds: CESPSound[]
}

/** openpeon.json manifest per CESP v1.0 */
export interface CESPManifest {
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
export interface PeonConfig {
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

// ---------------------------------------------------------------------------
// Platform Detection & Relay
// ---------------------------------------------------------------------------

export type RuntimePlatform = "mac" | "linux" | "wsl" | "ssh" | "devcontainer"

export interface RelayConfig {
  host: string
  port: number
}

export function detectPlatform(): RuntimePlatform {
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

export function getRelayConfig(config: PeonConfig, platform: RuntimePlatform): RelayConfig {
  const host = config.relay_host
    || process.env.PEON_RELAY_HOST
    || (platform === "devcontainer" ? "host.docker.internal" : "localhost")
  const port = config.relay_port
    || Number(process.env.PEON_RELAY_PORT)
    || 19998
  return { host, port }
}

/** Internal runtime state */
export interface PeonState {
  last_played: Partial<Record<CESPCategory, string>>
  session_packs: Record<string, string>
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

export const PLUGIN_DIR = path.join(os.homedir(), ".config", "opencode", "peon-ping")
export const CONFIG_PATH = path.join(PLUGIN_DIR, "config.json")
export const STATE_PATH = path.join(PLUGIN_DIR, ".state.json")
export const PAUSED_PATH = path.join(PLUGIN_DIR, ".paused")
export const DEFAULT_PACKS_DIR = path.join(os.homedir(), ".openpeon", "packs")

export const REGISTRY_URL = "https://peonping.github.io/registry/index.json"

export const DEFAULT_CONFIG: PeonConfig = {
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

export const TERMINAL_APPS = [
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

export function loadConfig(): PeonConfig {
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

export function loadState(): PeonState {
  try {
    const raw = fs.readFileSync(STATE_PATH, "utf8")
    return JSON.parse(raw)
  } catch {
    return { last_played: {}, session_packs: {} }
  }
}

export function saveState(state: PeonState): void {
  try {
    fs.mkdirSync(path.dirname(STATE_PATH), { recursive: true })
    fs.writeFileSync(STATE_PATH, JSON.stringify(state, null, 2))
  } catch {
    // Non-critical
  }
}

export function isPaused(): boolean {
  return fs.existsSync(PAUSED_PATH)
}

// ---------------------------------------------------------------------------
// Helpers: Pack Management (CESP v1.0)
// ---------------------------------------------------------------------------

export function getPacksDir(config: PeonConfig): string {
  return config.packs_dir || DEFAULT_PACKS_DIR
}

export function loadManifest(packDir: string): CESPManifest | null {
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

export function migrateLegacyManifest(legacy: any): CESPManifest {
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

export function listPacks(packsDir: string): string[] {
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

export function resolveCategory(
  manifest: CESPManifest,
  category: CESPCategory,
): CESPCategoryEntry | null {
  const direct = manifest.categories[category]
  if (direct && direct.sounds.length > 0) return direct
  return null
}

export function pickSound(
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

export function resolveActivePack(
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

export function escapeAppleScript(s: string): string {
  return s.replace(/\\/g, "\\\\").replace(/"/g, '\\"')
}

/**
 * Create a debounce checker. Returns a function that tracks last event times
 * and returns true if the event should be debounced.
 */
export function createDebounceChecker(debounceMs: number) {
  const lastEventTime: Partial<Record<CESPCategory, number>> = {}

  return function shouldDebounce(category: CESPCategory, now?: number): boolean {
    const time = now ?? Date.now()
    const last = lastEventTime[category]
    if (last && time - last < debounceMs) return true
    lastEventTime[category] = time
    return false
  }
}

/**
 * Create a spam checker. Returns a function that tracks prompt timestamps
 * and returns true when rapid-prompt threshold is exceeded.
 */
export function createSpamChecker(threshold: number, windowSeconds: number) {
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
