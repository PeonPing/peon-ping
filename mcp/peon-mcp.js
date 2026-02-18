#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { readFileSync, readdirSync, existsSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { spawn, execSync } from "child_process";
import { platform as osPlatform } from "os";

const __dirname = dirname(fileURLToPath(import.meta.url));
const home = process.env.HOME || process.env.USERPROFILE || "";

function readConfig() {
  const candidates = [
    join(home, ".claude", "hooks", "peon-ping", "config.json"),
    join(home, ".openpeon", "config.json"),
  ];
  for (const p of candidates) {
    try {
      return JSON.parse(readFileSync(p, "utf-8"));
    } catch {}
  }
  return {};
}

const cfg = readConfig();
const volume = process.env.PEON_VOLUME ? (parseFloat(process.env.PEON_VOLUME) || 0.5) : (typeof cfg.volume === "number" ? cfg.volume : 0.5);
const useSoundEffectsDevice = cfg.use_sound_effects_device !== false;

let version = "2.1.0";
try { version = readFileSync(join(__dirname, "..", "VERSION"), "utf-8").trim(); } catch {}

function findPacksDir() {
  if (process.env.PEON_PACKS_DIR && existsSync(process.env.PEON_PACKS_DIR)) return process.env.PEON_PACKS_DIR;
  for (const dir of [join(home, ".openpeon", "packs"), join(home, ".claude", "hooks", "peon-ping", "packs")]) {
    if (existsSync(dir)) return dir;
  }
  return null;
}

let catalog = null;

function loadCatalog() {
  if (catalog) return catalog;
  const dir = findPacksDir();
  const packs = new Map();
  if (dir) {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const manifest = join(dir, entry.name, "openpeon.json");
      if (!existsSync(manifest)) continue;
      try { packs.set(entry.name, JSON.parse(readFileSync(manifest, "utf-8"))); } catch {}
    }
  }
  catalog = { dir, packs };
  return catalog;
}

function resolveSound(pack, sound) {
  const { dir, packs } = loadCatalog();
  if (!dir) return null;
  const manifest = packs.get(pack);
  if (!manifest) return null;
  for (const category of Object.values(manifest.categories || {})) {
    for (const s of category.sounds || []) {
      const name = s.file.split("/").pop().replace(/\.\w+$/, "");
      if (name === sound) return { path: join(dir, pack, s.file), label: s.label || sound };
    }
  }
  return null;
}

function detectPlatform() {
  const p = osPlatform();
  if (p === "darwin") return "mac";
  if (p === "win32") return "windows";
  if (p === "linux") {
    try { if (/microsoft/i.test(readFileSync("/proc/version", "utf-8"))) return "wsl"; } catch {}
    return "linux";
  }
  return null;
}

function findLinuxPlayer() {
  for (const p of ["pw-play", "paplay", "ffplay", "mpv", "play", "aplay"]) {
    try { execSync(`command -v ${p}`, { stdio: "ignore" }); return p; } catch {}
  }
  return null;
}

function getPlayCommand(filePath) {
  const plat = detectPlatform();
  if (plat === "mac") {
    const peonPlay = join(home, ".claude", "hooks", "peon-ping", "scripts", "peon-play");
    const cmd = (useSoundEffectsDevice && existsSync(peonPlay)) ? peonPlay : "afplay";
    return [cmd, ["-v", String(volume), filePath]];
  }
  if (plat === "wsl") return ["powershell.exe", ["-NoProfile", "-Command", `(New-Object Media.SoundPlayer '${filePath.replace(/\//g, "\\")}').PlaySync()`]];
  if (plat === "linux") {
    const player = findLinuxPlayer();
    if (!player) return null;
    const v = volume;
    if (player === "pw-play") return [player, ["--volume", String(v), filePath]];
    if (player === "paplay") return [player, ["--volume", String(Math.round(v * 65536)), filePath]];
    if (player === "ffplay") return [player, ["-nodisp", "-autoexit", "-volume", String(Math.round(v * 100)), filePath]];
    if (player === "mpv") return [player, ["--no-video", `--volume=${Math.round(v * 100)}`, filePath]];
    return [player, [filePath]];
  }
  return null;
}

function playFile(filePath) {
  const cmd = getPlayCommand(filePath);
  if (!cmd) return Promise.resolve();
  return new Promise(resolve => {
    const child = spawn(cmd[0], cmd[1], { stdio: "ignore" });
    child.on("close", resolve);
    child.on("error", resolve);
  });
}

const queue = [];
let playing = false;

function enqueue(filePath) {
  queue.push(filePath);
  if (!playing) drain();
}

async function drain() {
  playing = true;
  while (queue.length) await playFile(queue.shift());
  playing = false;
}

const server = new McpServer({ name: "peon-ping", version });

server.resource("catalog", "peon-ping://catalog", { description: "All sound packs and their sounds", mimeType: "text/plain" }, () => {
  const { packs } = loadCatalog();
  if (!packs.size) return { contents: [{ uri: "peon-ping://catalog", text: "No packs installed." }] };
  const lines = [`${packs.size} packs. Use play_sound with "pack/SoundName".\n`];
  for (const [name, manifest] of [...packs].sort((a, b) => a[0].localeCompare(b[0]))) {
    const sounds = Object.values(manifest.categories || {}).flatMap(c =>
      (c.sounds || []).map(s => `${name}/${s.file.split("/").pop().replace(/\.\w+$/, "")} ("${s.label}")`)
    );
    lines.push(`${name} (${manifest.display_name || name}): ${sounds.join(", ")}`);
  }
  return { contents: [{ uri: "peon-ping://catalog", text: lines.join("\n") }] };
});

server.resource("pack", "peon-ping://pack/{name}", { description: "Sounds in a specific pack", mimeType: "text/plain" }, (uri, { name }) => {
  const manifest = loadCatalog().packs.get(name);
  if (!manifest) return { contents: [{ uri: uri.href, text: `Pack "${name}" not found.` }] };
  const lines = [`${manifest.display_name || name}:\n`];
  for (const [cat, data] of Object.entries(manifest.categories || {})) {
    lines.push(cat + ":");
    for (const s of data.sounds || []) {
      lines.push(`  ${name}/${s.file.split("/").pop().replace(/\.\w+$/, "")} — "${s.label}"`);
    }
  }
  return { contents: [{ uri: uri.href, text: lines.join("\n") }] };
});

server.tool(
  "play_sound",
  'Play a sound effect. Keys: "pack/sound" (e.g. "duke_nukem/Groovy"). Read the catalog resource for available sounds.',
  {
    sound: z.string().optional().describe("Sound key"),
    sounds: z.array(z.string()).optional().describe("Multiple sound keys"),
  },
  async ({ sound, sounds: arr }) => {
    const keys = arr || (sound ? [sound] : []);
    if (!keys.length) return { content: [{ type: "text", text: "No sound specified." }] };

    const results = keys.slice(0, 5).map(key => {
      const [pack, name] = key.split("/", 2);
      if (!pack || !name) return `❌ Invalid: "${key}"`;
      const resolved = resolveSound(pack, name);
      if (!resolved) return `❌ Not found: "${key}"`;
      if (!existsSync(resolved.path)) return `❌ Missing file: "${key}"`;
      enqueue(resolved.path);
      return `🔊 ${key} ("${resolved.label}")`;
    });

    return { content: [{ type: "text", text: results.join("\n") }] };
  }
);

await server.connect(new StdioServerTransport());
