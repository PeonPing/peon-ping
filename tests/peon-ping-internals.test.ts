/**
 * Tests for adapters/opencode/peon-ping-internals.ts
 *
 * Covers the core business logic of the peon-ping OpenCode adapter:
 * config merging, legacy manifest migration, sound picking (no-repeat),
 * pack resolution with rotation, debounce, and spam detection.
 */

import { describe, it, expect, vi, beforeEach } from "vitest"

vi.mock("node:fs", () => ({
  readFileSync: vi.fn(),
  writeFileSync: vi.fn(),
  existsSync: vi.fn(),
  readdirSync: vi.fn(),
  statSync: vi.fn(),
  mkdirSync: vi.fn(),
}))

import * as fs from "node:fs"
import {
  CESP_CATEGORIES,
  DEFAULT_CONFIG,
  type CESPCategory,
  type CESPManifest,
  type CESPSound,
  type CESPCategoryEntry,
  type PeonState,
  loadConfig,
  loadManifest,
  migrateLegacyManifest,
  resolveCategory,
  pickSound,
  resolveActivePack,
  escapeAppleScript,
  createDebounceChecker,
  createSpamChecker,
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
