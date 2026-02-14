/**
 * Tests for adapters/opencode/peon-ping-internals.ts
 *
 * Covers the core business logic of the peon-ping OpenCode adapter:
 * config merging, legacy manifest migration, sound picking (no-repeat),
 * pack resolution with rotation, debounce, and spam detection.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from "vitest"

vi.mock("node:fs", () => ({
  readFileSync: vi.fn(),
  writeFileSync: vi.fn(),
  existsSync: vi.fn(),
  readdirSync: vi.fn(),
  statSync: vi.fn(),
  mkdirSync: vi.fn(),
}))

vi.mock("node:os", async () => {
  const actual = await vi.importActual<typeof import("node:os")>("node:os")
  return {
    ...actual,
    platform: vi.fn(() => "darwin"),
    homedir: actual.homedir,
  }
})

import * as fs from "node:fs"
import * as os from "node:os"
import {
  CESP_CATEGORIES,
  DEFAULT_CONFIG,
  type CESPCategory,
  type CESPManifest,
  type CESPSound,
  type CESPCategoryEntry,
  type PeonConfig,
  type PeonState,
  type RuntimePlatform,
  loadConfig,
  loadManifest,
  migrateLegacyManifest,
  listPacks,
  loadState,
  saveState,
  resolveCategory,
  pickSound,
  resolveActivePack,
  escapeAppleScript,
  createDebounceChecker,
  createSpamChecker,
  detectPlatform,
  getRelayConfig,
} from "../adapters/opencode/peon-ping-internals.js"

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeManifest(
  overrides: Partial<CESPManifest> = {},
): CESPManifest {
  return {
    cesp_version: "1.0",
    name: "test-pack",
    display_name: "Test Pack",
    version: "1.0.0",
    categories: {},
    ...overrides,
  }
}

function makeManifestWithSounds(
  categoryMap: Partial<Record<CESPCategory, CESPSound[]>>,
): CESPManifest {
  const categories: Partial<Record<CESPCategory, CESPCategoryEntry>> = {}
  for (const [cat, sounds] of Object.entries(categoryMap)) {
    categories[cat as CESPCategory] = { sounds }
  }
  return makeManifest({ categories })
}

function makeState(overrides: Partial<PeonState> = {}): PeonState {
  return { last_played: {}, session_packs: {}, ...overrides }
}

function setupListPacks(available: string[]) {
  vi.mocked(fs.readdirSync).mockReturnValue(available as any)
  vi.mocked(fs.statSync).mockReturnValue({ isDirectory: () => true } as any)
  vi.mocked(fs.existsSync).mockReturnValue(true)
}

// ---------------------------------------------------------------------------
// loadConfig
// ---------------------------------------------------------------------------

describe("loadConfig", () => {
  beforeEach(() => vi.resetAllMocks())

  it("returns defaults when config file is missing", () => {
    vi.mocked(fs.readFileSync).mockImplementation(() => { throw new Error("ENOENT") })
    expect(loadConfig()).toEqual(DEFAULT_CONFIG)
  })

  it("merges user overrides while preserving defaults", () => {
    vi.mocked(fs.readFileSync).mockReturnValue(
      JSON.stringify({ volume: 0.9, active_pack: "glados" }),
    )
    const config = loadConfig()
    expect(config.volume).toBe(0.9)
    expect(config.active_pack).toBe("glados")
    expect(config.enabled).toBe(true)
  })

  it("deep-merges categories so partial overrides keep other defaults", () => {
    vi.mocked(fs.readFileSync).mockReturnValue(
      JSON.stringify({ categories: { "user.spam": false } }),
    )
    const config = loadConfig()
    expect(config.categories["user.spam"]).toBe(false)
    expect(config.categories["session.start"]).toBe(true)
  })
})

// ---------------------------------------------------------------------------
// migrateLegacyManifest
// ---------------------------------------------------------------------------

describe("migrateLegacyManifest", () => {
  it("maps all 7 legacy category names to CESP equivalents", () => {
    const legacy = {
      name: "orc-peon",
      display_name: "Orc Peon",
      version: "1.0.0",
      categories: {
        greeting: { sounds: [{ file: "hello.wav", label: "Hello" }] },
        acknowledge: { sounds: [{ file: "ack.wav", label: "Ack" }] },
        complete: { sounds: [{ file: "done.wav", label: "Done" }] },
        error: { sounds: [{ file: "err.wav", label: "Error" }] },
        permission: { sounds: [{ file: "perm.wav", label: "Perm" }] },
        resource_limit: { sounds: [{ file: "lim.wav", label: "Lim" }] },
        annoyed: { sounds: [{ file: "ann.wav", label: "Ann" }] },
      },
    }
    const result = migrateLegacyManifest(legacy)
    expect(result.cesp_version).toBe("1.0")
    expect(result.categories["session.start"]?.sounds).toHaveLength(1)
    expect(result.categories["task.acknowledge"]?.sounds).toHaveLength(1)
    expect(result.categories["task.complete"]?.sounds).toHaveLength(1)
    expect(result.categories["task.error"]?.sounds).toHaveLength(1)
    expect(result.categories["input.required"]?.sounds).toHaveLength(1)
    expect(result.categories["resource.limit"]?.sounds).toHaveLength(1)
    expect(result.categories["user.spam"]?.sounds).toHaveLength(1)
  })

  it("prepends sounds/ to bare filenames but preserves paths with /", () => {
    const legacy = {
      name: "t",
      categories: {
        greeting: { sounds: [
          { file: "hello.wav", label: "a" },
          { file: "audio/hello.wav", label: "b" },
        ]},
      },
    }
    const sounds = migrateLegacyManifest(legacy).categories["session.start"]!.sounds
    expect(sounds[0].file).toBe("sounds/hello.wav")
    expect(sounds[1].file).toBe("audio/hello.wav")
  })

  it("falls back to line then file for label, keeps sha256 only when present", () => {
    const legacy = {
      name: "t",
      categories: {
        greeting: { sounds: [
          { file: "a.wav", line: "My line" },
          { file: "b.wav" },
          { file: "c.wav", label: "C", sha256: "abc" },
        ]},
      },
    }
    const sounds = migrateLegacyManifest(legacy).categories["session.start"]!.sounds
    expect(sounds[0].label).toBe("My line")
    expect(sounds[1].label).toBe("b.wav")
    expect(sounds[2].sha256).toBe("abc")
    expect(sounds[0]).not.toHaveProperty("sha256")
  })

  it("uses safe defaults for missing name/display_name/version", () => {
    const result = migrateLegacyManifest({})
    expect(result.name).toBe("unknown")
    expect(result.display_name).toBe("Unknown Pack")
    expect(result.version).toBe("0.0.0")
  })

  it("ignores unknown legacy categories", () => {
    const result = migrateLegacyManifest({
      name: "t",
      categories: { fake_category: { sounds: [{ file: "x.wav", label: "X" }] } },
    })
    for (const cat of CESP_CATEGORIES) {
      expect(result.categories[cat]).toBeUndefined()
    }
  })
})

// ---------------------------------------------------------------------------
// loadManifest
// ---------------------------------------------------------------------------

describe("loadManifest", () => {
  beforeEach(() => vi.resetAllMocks())

  it("returns null when neither manifest exists", () => {
    vi.mocked(fs.existsSync).mockReturnValue(false)
    expect(loadManifest("/packs/test")).toBeNull()
  })

  it("prefers openpeon.json and falls back to manifest.json with migration", () => {
    // openpeon.json path
    const cesp = makeManifest({ name: "cesp" })
    vi.mocked(fs.existsSync).mockImplementation((p) => String(p).endsWith("openpeon.json"))
    vi.mocked(fs.readFileSync).mockReturnValue(JSON.stringify(cesp))
    expect(loadManifest("/p")!.name).toBe("cesp")

    // fallback: only manifest.json
    vi.resetAllMocks()
    vi.mocked(fs.existsSync).mockImplementation((p) => String(p).endsWith("manifest.json"))
    vi.mocked(fs.readFileSync).mockReturnValue(
      JSON.stringify({ name: "legacy", categories: { greeting: { sounds: [{ file: "hi.wav", label: "Hi" }] } } }),
    )
    const result = loadManifest("/p")!
    expect(result.cesp_version).toBe("1.0")
    expect(result.categories["session.start"]).toBeDefined()
  })

  it("returns null on invalid JSON in either file", () => {
    vi.mocked(fs.existsSync).mockImplementation((p) => String(p).endsWith("openpeon.json"))
    vi.mocked(fs.readFileSync).mockReturnValue("bad json")
    expect(loadManifest("/p")).toBeNull()
  })
})

// ---------------------------------------------------------------------------
// resolveCategory
// ---------------------------------------------------------------------------

describe("resolveCategory", () => {
  it("returns entry when sounds exist, null otherwise", () => {
    const sounds: CESPSound[] = [{ file: "sounds/done.wav", label: "Done" }]
    const manifest = makeManifestWithSounds({ "task.complete": sounds })

    expect(resolveCategory(manifest, "task.complete")).toEqual({ sounds })
    expect(resolveCategory(manifest, "session.end")).toBeNull()
    expect(resolveCategory(makeManifestWithSounds({ "task.complete": [] }), "task.complete")).toBeNull()
  })
})

// ---------------------------------------------------------------------------
// pickSound
// ---------------------------------------------------------------------------

describe("pickSound", () => {
  it("returns null when category has no sounds", () => {
    expect(pickSound(makeManifest(), "session.start", makeState())).toBeNull()
  })

  it("picks a sound and records it in state.last_played", () => {
    const sound: CESPSound = { file: "sounds/hi.wav", label: "Hi" }
    const manifest = makeManifestWithSounds({ "session.start": [sound] })
    const state = makeState()

    expect(pickSound(manifest, "session.start", state)).toEqual(sound)
    expect(state.last_played["session.start"]).toBe("sounds/hi.wav")
  })

  it("avoids repeating the last played sound (no-repeat)", () => {
    const sounds: CESPSound[] = [
      { file: "sounds/a.wav", label: "A" },
      { file: "sounds/b.wav", label: "B" },
    ]
    const manifest = makeManifestWithSounds({ "task.complete": sounds })
    const state = makeState({ last_played: { "task.complete": "sounds/a.wav" } })

    expect(pickSound(manifest, "task.complete", state)!.file).toBe("sounds/b.wav")
  })

  it("still picks when only one sound matches the last played", () => {
    const sound: CESPSound = { file: "sounds/only.wav", label: "Only" }
    const manifest = makeManifestWithSounds({ "task.error": [sound] })
    const state = makeState({ last_played: { "task.error": "sounds/only.wav" } })

    expect(pickSound(manifest, "task.error", state)).toEqual(sound)
  })
})

// ---------------------------------------------------------------------------
// resolveActivePack
// ---------------------------------------------------------------------------

describe("resolveActivePack", () => {
  beforeEach(() => vi.resetAllMocks())

  it("returns active_pack when available", () => {
    setupListPacks(["peon", "glados"])
    expect(resolveActivePack({ ...DEFAULT_CONFIG, active_pack: "glados" }, makeState(), "s1", "/p")).toBe("glados")
  })

  it("falls back to first available when active_pack is missing", () => {
    setupListPacks(["alpha", "beta"])
    expect(resolveActivePack({ ...DEFAULT_CONFIG, active_pack: "gone" }, makeState(), "s1", "/p")).toBe("alpha")
  })

  it("uses rotation, stores pick, and reuses existing session pack", () => {
    setupListPacks(["peon", "glados"])
    const config = { ...DEFAULT_CONFIG, pack_rotation: ["peon", "glados"] }
    const state = makeState()

    const pick = resolveActivePack(config, state, "s1", "/p")
    expect(["peon", "glados"]).toContain(pick)
    expect(state.session_packs["s1"]).toBe(pick)

    // Same session ID returns same pack
    expect(resolveActivePack(config, state, "s1", "/p")).toBe(pick)
  })

  it("falls through when all rotation packs are unavailable", () => {
    setupListPacks(["peon"])
    const config = { ...DEFAULT_CONFIG, active_pack: "peon", pack_rotation: ["gone1", "gone2"] }
    expect(resolveActivePack(config, makeState(), "s1", "/p")).toBe("peon")
  })
})

// ---------------------------------------------------------------------------
// listPacks
// ---------------------------------------------------------------------------

describe("listPacks", () => {
  beforeEach(() => vi.resetAllMocks())

  it("returns sorted pack names that have a manifest file", () => {
    vi.mocked(fs.readdirSync).mockReturnValue(["glados", "peon", "peasant"] as any)
    vi.mocked(fs.statSync).mockReturnValue({ isDirectory: () => true } as any)
    vi.mocked(fs.existsSync).mockReturnValue(true)
    expect(listPacks("/packs")).toEqual(["glados", "peasant", "peon"])
  })

  it("excludes entries that are not directories", () => {
    vi.mocked(fs.readdirSync).mockReturnValue(["peon", "readme.txt"] as any)
    vi.mocked(fs.statSync).mockImplementation((p) => ({
      isDirectory: () => !String(p).includes("readme"),
    }) as any)
    vi.mocked(fs.existsSync).mockReturnValue(true)
    expect(listPacks("/packs")).toEqual(["peon"])
  })

  it("excludes directories without openpeon.json or manifest.json", () => {
    vi.mocked(fs.readdirSync).mockReturnValue(["empty-dir"] as any)
    vi.mocked(fs.statSync).mockReturnValue({ isDirectory: () => true } as any)
    vi.mocked(fs.existsSync).mockReturnValue(false)
    expect(listPacks("/packs")).toEqual([])
  })

  it("returns empty array when packs dir does not exist", () => {
    vi.mocked(fs.readdirSync).mockImplementation(() => { throw new Error("ENOENT") })
    expect(listPacks("/nonexistent")).toEqual([])
  })
})

// ---------------------------------------------------------------------------
// loadState / saveState
// ---------------------------------------------------------------------------

describe("loadState", () => {
  beforeEach(() => vi.resetAllMocks())

  it("returns default empty state when file is missing", () => {
    vi.mocked(fs.readFileSync).mockImplementation(() => { throw new Error("ENOENT") })
    expect(loadState()).toEqual({ last_played: {}, session_packs: {} })
  })

  it("parses persisted state from disk", () => {
    const persisted: PeonState = {
      last_played: { "task.complete": "sounds/done.wav" },
      session_packs: { "oc-123": "glados" },
    }
    vi.mocked(fs.readFileSync).mockReturnValue(JSON.stringify(persisted))
    expect(loadState()).toEqual(persisted)
  })
})

describe("saveState", () => {
  beforeEach(() => vi.resetAllMocks())

  it("writes state as pretty-printed JSON and creates directory", () => {
    const state: PeonState = {
      last_played: { "session.start": "sounds/hi.wav" },
      session_packs: {},
    }
    saveState(state)
    expect(fs.mkdirSync).toHaveBeenCalledWith(expect.any(String), { recursive: true })
    expect(fs.writeFileSync).toHaveBeenCalledWith(
      expect.any(String),
      JSON.stringify(state, null, 2),
    )
  })

  it("does not throw when write fails", () => {
    vi.mocked(fs.mkdirSync).mockImplementation(() => { throw new Error("EPERM") })
    expect(() => saveState({ last_played: {}, session_packs: {} })).not.toThrow()
  })
})

// ---------------------------------------------------------------------------
// escapeAppleScript
// ---------------------------------------------------------------------------

describe("escapeAppleScript", () => {
  it("escapes backslashes and double quotes", () => {
    expect(escapeAppleScript("path\\to\\file")).toBe("path\\\\to\\\\file")
    expect(escapeAppleScript('say "hi"')).toBe('say \\"hi\\"')
    expect(escapeAppleScript("plain")).toBe("plain")
    expect(escapeAppleScript("")).toBe("")
  })
})

// ---------------------------------------------------------------------------
// createDebounceChecker
// ---------------------------------------------------------------------------

describe("createDebounceChecker", () => {
  it("allows first event, blocks within window, allows after", () => {
    const check = createDebounceChecker(500)
    expect(check("task.complete", 1000)).toBe(false)
    expect(check("task.complete", 1200)).toBe(true)
    expect(check("task.complete", 1600)).toBe(false)
  })

  it("tracks categories independently", () => {
    const check = createDebounceChecker(500)
    check("task.complete", 1000)
    expect(check("task.error", 1100)).toBe(false)
    expect(check("task.complete", 1100)).toBe(true)
  })
})

// ---------------------------------------------------------------------------
// createSpamChecker
// ---------------------------------------------------------------------------

describe("createSpamChecker", () => {
  it("triggers at threshold and resets after window expires", () => {
    const check = createSpamChecker(3, 10)
    expect(check(100)).toBe(false) // 1st
    expect(check(101)).toBe(false) // 2nd
    expect(check(102)).toBe(true)  // 3rd — at threshold
    expect(check(120)).toBe(false) // window expired, only 1 now
  })

  it("prunes old timestamps within sliding window", () => {
    const check = createSpamChecker(3, 10)
    check(100)
    check(105)
    // At 112, entry at 100 is outside window -> only 105 + 112 = 2
    expect(check(112)).toBe(false)
  })
})

// ---------------------------------------------------------------------------
// detectPlatform
// ---------------------------------------------------------------------------

describe("detectPlatform", () => {
  const savedEnv = { ...process.env }

  afterEach(() => {
    // Restore environment
    delete process.env.SSH_CONNECTION
    delete process.env.SSH_CLIENT
    delete process.env.REMOTE_CONTAINERS
    delete process.env.CODESPACES
    vi.mocked(os.platform).mockReturnValue("darwin")
  })

  it("returns 'ssh' when SSH_CONNECTION is set", () => {
    process.env.SSH_CONNECTION = "1.2.3.4 56789 5.6.7.8 22"
    expect(detectPlatform()).toBe("ssh")
  })

  it("returns 'ssh' when SSH_CLIENT is set", () => {
    process.env.SSH_CLIENT = "1.2.3.4 56789 22"
    expect(detectPlatform()).toBe("ssh")
  })

  it("returns 'devcontainer' when REMOTE_CONTAINERS is set", () => {
    process.env.REMOTE_CONTAINERS = "true"
    expect(detectPlatform()).toBe("devcontainer")
  })

  it("returns 'devcontainer' when CODESPACES is set", () => {
    process.env.CODESPACES = "true"
    expect(detectPlatform()).toBe("devcontainer")
  })

  it("returns 'mac' on darwin without SSH env vars", () => {
    vi.mocked(os.platform).mockReturnValue("darwin")
    expect(detectPlatform()).toBe("mac")
  })

  it("returns 'linux' on linux without SSH/WSL", () => {
    vi.mocked(os.platform).mockReturnValue("linux")
    vi.mocked(fs.readFileSync).mockReturnValue("Linux version 5.15.0")
    expect(detectPlatform()).toBe("linux")
  })

  it("SSH takes priority over devcontainer when both are set", () => {
    process.env.SSH_CONNECTION = "1.2.3.4 56789 5.6.7.8 22"
    process.env.REMOTE_CONTAINERS = "true"
    expect(detectPlatform()).toBe("ssh")
  })
})

// ---------------------------------------------------------------------------
// getRelayConfig
// ---------------------------------------------------------------------------

describe("getRelayConfig", () => {
  afterEach(() => {
    delete process.env.PEON_RELAY_HOST
    delete process.env.PEON_RELAY_PORT
  })

  it("returns localhost:19998 for SSH platform with no overrides", () => {
    const config: PeonConfig = { ...DEFAULT_CONFIG }
    const relay = getRelayConfig(config, "ssh")
    expect(relay).toEqual({ host: "localhost", port: 19998 })
  })

  it("returns host.docker.internal:19998 for devcontainer with no overrides", () => {
    const config: PeonConfig = { ...DEFAULT_CONFIG }
    const relay = getRelayConfig(config, "devcontainer")
    expect(relay).toEqual({ host: "host.docker.internal", port: 19998 })
  })

  it("respects PEON_RELAY_HOST env var override", () => {
    process.env.PEON_RELAY_HOST = "custom-host"
    const config: PeonConfig = { ...DEFAULT_CONFIG }
    const relay = getRelayConfig(config, "ssh")
    expect(relay.host).toBe("custom-host")
  })

  it("respects PEON_RELAY_PORT env var override", () => {
    process.env.PEON_RELAY_PORT = "12345"
    const config: PeonConfig = { ...DEFAULT_CONFIG }
    const relay = getRelayConfig(config, "ssh")
    expect(relay.port).toBe(12345)
  })

  it("respects config relay_host / relay_port fields", () => {
    const config: PeonConfig = { ...DEFAULT_CONFIG, relay_host: "cfg-host", relay_port: 9999 }
    const relay = getRelayConfig(config, "ssh")
    expect(relay).toEqual({ host: "cfg-host", port: 9999 })
  })

  it("config fields take priority over env vars", () => {
    process.env.PEON_RELAY_HOST = "env-host"
    process.env.PEON_RELAY_PORT = "11111"
    const config: PeonConfig = { ...DEFAULT_CONFIG, relay_host: "cfg-host", relay_port: 9999 }
    const relay = getRelayConfig(config, "ssh")
    expect(relay).toEqual({ host: "cfg-host", port: 9999 })
  })
})
