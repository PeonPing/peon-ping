"use client";

import "./landing.css";
import { useState, useEffect, useRef, useCallback } from "react";

/* ------------------------------------------------------------------ */
/*  Types                                                              */
/* ------------------------------------------------------------------ */

interface RegistryPack {
  name: string;
  display_name: string;
  description?: string;
  language?: string;
  sound_count: number;
  source_repo: string;
  source_ref: string;
  source_path?: string;
  preview_sounds?: string[];
  author?: { name?: string };
  tags?: string[];
}

interface ManifestSound {
  file: string;
  label?: string;
}

interface ManifestCategory {
  sounds?: ManifestSound[];
  [key: string]: unknown;
}

interface Manifest {
  categories?: Record<string, ManifestCategory | ManifestSound[]>;
}

/* ------------------------------------------------------------------ */
/*  Constants                                                          */
/* ------------------------------------------------------------------ */

const REGISTRY_URL = "https://peonping.github.io/registry/index.json";
const DEFAULT_PACKS = new Set([
  "peon",
  "peasant",
  "glados",
  "sc_kerrigan",
  "sc_battlecruiser",
  "ra2_kirov",
  "dota2_axe",
  "duke_nukem",
  "tf2_engineer",
  "hd2_helldiver",
]);

/* ------------------------------------------------------------------ */
/*  Helpers                                                            */
/* ------------------------------------------------------------------ */

function setsEqual(a: Set<string>, b: Set<string>): boolean {
  if (a.size !== b.size) return false;
  for (const item of a) if (!b.has(item)) return false;
  return true;
}

function escapeHtml(str: string): string {
  const div = document.createElement("div");
  div.appendChild(document.createTextNode(str));
  return div.innerHTML;
}

function parseHashPacks(): Set<string> | "all" | null {
  if (typeof window === "undefined") return null;
  const hash = window.location.hash;
  if (!hash.startsWith("#packs=")) return null;
  const val = hash.substring(7);
  if (val === "none") return new Set<string>();
  if (val === "all") return "all";
  return new Set(val.split(",").filter(Boolean));
}

/* ------------------------------------------------------------------ */
/*  Clipboard SVGs                                                     */
/* ------------------------------------------------------------------ */

function ClipboardIcon() {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 16 16"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <rect x="5" y="5" width="8" height="8" rx="1.5" />
      <path d="M3 11V2.5A1.5 1.5 0 014.5 1H10" />
    </svg>
  );
}

function CheckIcon() {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 16 16"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M3 8.5L6.5 12L13 4" />
    </svg>
  );
}

/* ------------------------------------------------------------------ */
/*  CopyBlock component (reusable install block)                       */
/* ------------------------------------------------------------------ */

function CopyBlock({
  command,
  id,
  label,
}: {
  command: string;
  id?: string;
  label?: string;
}) {
  const [copied, setCopied] = useState(false);

  const handleCopy = useCallback(() => {
    navigator.clipboard.writeText(command).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  }, [command]);

  return (
    <div
      className="install-block"
      onClick={handleCopy}
      title="Click to copy"
      role="button"
      aria-label={label || "Copy install command"}
    >
      <code id={id}>{command}</code>
      <button
        className={`copy-btn${copied ? " copied" : ""}`}
        aria-label="Copy to clipboard"
      >
        {copied ? <CheckIcon /> : <ClipboardIcon />}
      </button>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/*  Audio card data                                                    */
/* ------------------------------------------------------------------ */

const AUDIO_CARDS = [
  { sound: "PeonReady1", quote: '"Ready to work?"', file: "greeting" },
  { sound: "PeonYes3", quote: '"Work, work."', file: "acknowledge" },
  { sound: "PeonYes2", quote: '"Be happy to."', file: "acknowledge" },
  { sound: "PeonYes4", quote: '"Okie dokie."', file: "acknowledge" },
  {
    sound: "PeonWhat4",
    quote: '"Something need doing?"',
    file: "permission",
  },
  {
    sound: "PeonAngry4",
    quote: '"Me not that kind of orc!"',
    file: "annoyed",
  },
  { sound: "PeonYes1", quote: '"I can do that."', file: "acknowledge" },
  { sound: "PeonWhat3", quote: '"What you want?"', file: "permission" },
];

/* ------------------------------------------------------------------ */
/*  Terminal lines data                                                */
/* ------------------------------------------------------------------ */

const TERMINAL_LINES = [
  { delay: 300, content: <><span className="term-prompt">$ </span><span className="term-cmd">claude</span></> },
  { delay: 900, sound: "PeonReady1", content: <span className="term-sound">{"\uD83D\uDD0A"} &quot;Ready to work?&quot;</span> },
  { delay: 1800, content: <><span className="term-prompt">&gt; </span><span className="term-cmd">Fix the login bug in auth.ts</span></> },
  { delay: 2600, content: <span className="term-dim">  Claude is working...</span> },
  { delay: 3400, content: <span className="term-dim">  [you tab to Slack]</span> },
  { delay: 4600, sound: "PeonWhat4", content: <><span className="term-sound">{"\uD83D\uDD0A"} &quot;Something need doing?&quot;</span><span className="term-dim"> &mdash; permission needed</span></> },
  { delay: 5600, content: <span className="term-dim">  [you hear it, switch back, approve]</span> },
  { delay: 6600, content: <span className="term-dim">  Claude continues working...</span> },
  { delay: 7800, sound: "PeonYes3", content: <><span className="term-sound">{"\uD83D\uDD0A"} &quot;Work, work.&quot;</span><span className="term-dim"> &mdash; done</span></> },
  { delay: 8600, content: <><span className="term-prompt">&gt; </span><span className="term-cursor"></span></> },
];

/* ------------------------------------------------------------------ */
/*  Carousel packs data                                                */
/* ------------------------------------------------------------------ */

interface CarouselPack {
  id: string;
  badge: string;
  name: string;
  game: string;
  credit: string;
  creditUrl: string;
  sounds: { src: string; quote: string; cat: string; label: string }[];
}

const CAROUSEL_PACKS: CarouselPack[] = [
  {
    id: "peon",
    badge: "Default",
    name: "Orc Peon",
    game: "Warcraft III",
    credit: "@tonyyont",
    creditUrl: "https://github.com/tonyyont",
    sounds: [
      { src: "/audio/PeonReady1.ogg", quote: '"Ready to work?"', cat: "greeting", label: 'Play: Ready to work?' },
      { src: "/audio/PeonYes3.ogg", quote: '"Work, work."', cat: "acknowledge", label: 'Play: Work, work.' },
      { src: "/audio/PeonYes4.ogg", quote: '"Okie dokie."', cat: "acknowledge", label: 'Play: Okie dokie.' },
      { src: "/audio/PeonWhat4.ogg", quote: '"Something need doing?"', cat: "permission", label: 'Play: Something need doing?' },
      { src: "/audio/PeonAngry4.ogg", quote: '"Me not that kind of orc!"', cat: "error", label: 'Play: Me not that kind of orc!' },
      { src: "/audio/PeonWhat3.ogg", quote: '"What you want?"', cat: "permission", label: 'Play: What you want?' },
    ],
  },
  {
    id: "peasant",
    badge: "New",
    name: "Human Peasant",
    game: "Warcraft III",
    credit: "@thomasKn",
    creditUrl: "https://github.com/thomasKn",
    sounds: [
      { src: "/audio/PeasantReady1.mp3", quote: '"Ready to work."', cat: "greeting", label: 'Play: Ready to work.' },
      { src: "/audio/PeasantYes2.mp3", quote: '"Yes, milord."', cat: "acknowledge", label: 'Play: Yes, milord.' },
      { src: "/audio/PeasantYes4.mp3", quote: '"Off I go, then!"', cat: "acknowledge", label: 'Play: Off I go, then!' },
      { src: "/audio/PeasantWhat1.mp3", quote: '"Yes, milord?"', cat: "permission", label: 'Play: Yes, milord?' },
      { src: "/audio/PeasantYesAttack4.mp3", quote: '"That\'s it. I\'m dead."', cat: "error", label: "Play: That's it. I'm dead." },
      { src: "/audio/PeasantAngry1.mp3", quote: '"I didn\'t vote for you."', cat: "annoyed", label: "Play: I didn't vote for you." },
    ],
  },
  {
    id: "ra2_soviet_engineer",
    badge: "New",
    name: "Soviet Engineer",
    game: "Red Alert 2",
    credit: "@msukkari",
    creditUrl: "https://github.com/msukkari",
    sounds: [
      { src: "/audio/ToolsReady.mp3", quote: '"Tools ready"', cat: "greeting", label: 'Play: Tools ready' },
      { src: "/audio/YesCommander.mp3", quote: '"Yes, commander"', cat: "greeting", label: 'Play: Yes, commander' },
      { src: "/audio/Engineering.mp3", quote: '"Engineering"', cat: "acknowledge", label: 'Play: Engineering' },
      { src: "/audio/PowerUp.mp3", quote: '"Power up"', cat: "acknowledge", label: 'Play: Power up' },
      { src: "/audio/GetMeOuttaHere.mp3", quote: '"Get me outta here!"', cat: "error", label: 'Play: Get me outta here!' },
      { src: "/audio/CheckingDesigns.mp3", quote: '"Checking designs"', cat: "acknowledge", label: 'Play: Checking designs' },
    ],
  },
  {
    id: "sc_battlecruiser",
    badge: "New",
    name: "Battlecruiser",
    game: "StarCraft",
    credit: "@garysheng",
    creditUrl: "https://github.com/garysheng",
    sounds: [
      { src: "/audio/BattlecruiserOperational.mp3", quote: '"Battlecruiser operational"', cat: "greeting", label: 'Play: Battlecruiser operational' },
      { src: "/audio/ShieldsUp.mp3", quote: '"Shields up"', cat: "greeting", label: 'Play: Shields up' },
      { src: "/audio/MakeItHappen.mp3", quote: '"Make it happen"', cat: "acknowledge", label: 'Play: Make it happen' },
      { src: "/audio/Engage.mp3", quote: '"Engage"', cat: "acknowledge", label: 'Play: Engage' },
      { src: "/audio/HailingFrequenciesOpen.mp3", quote: '"Hailing frequencies open"', cat: "complete", label: 'Play: Hailing frequencies open' },
      { src: "/audio/ReallyHaveToGo.mp3", quote: '"I really have to go"', cat: "annoyed", label: 'Play: I really have to go' },
    ],
  },
  {
    id: "sc_kerrigan",
    badge: "New",
    name: "Sarah Kerrigan",
    game: "StarCraft",
    credit: "@garysheng",
    creditUrl: "https://github.com/garysheng",
    sounds: [
      { src: "/audio/KerriganReporting.mp3", quote: '"Lieutenant Kerrigan reporting"', cat: "greeting", label: 'Play: Lieutenant Kerrigan reporting' },
      { src: "/audio/IGotcha.mp3", quote: '"I gotcha"', cat: "acknowledge", label: 'Play: I gotcha' },
      { src: "/audio/BeAPleasure.mp3", quote: '"It\'d be a pleasure"', cat: "acknowledge", label: "Play: It'd be a pleasure" },
      { src: "/audio/WhatNow.mp3", quote: '"What now?"', cat: "permission", label: 'Play: What now?' },
      { src: "/audio/EasilyAmused.mp3", quote: '"Easily amused, huh?"', cat: "annoyed", label: 'Play: Easily amused, huh?' },
      { src: "/audio/GotAJobToDo.mp3", quote: '"I\'ve got a job to do"', cat: "annoyed", label: "Play: I've got a job to do" },
    ],
  },
  {
    id: "tf2_engineer",
    badge: "New",
    name: "TF2 Engineer",
    game: "Team Fortress 2",
    credit: "@Arie",
    creditUrl: "https://github.com/Arie",
    sounds: [
      { src: "/audio/Engineer_battlecry03.mp3", quote: '"Cowboy up!"', cat: "greeting", label: 'Play: Cowboy up!' },
      { src: "/audio/Engineer_autobuildingsentry01.mp3", quote: '"Sentry going up."', cat: "acknowledge", label: 'Play: Sentry going up.' },
      { src: "/audio/Eng_quest_complete_easy_01.mp3", quote: '"Nice work!"', cat: "complete", label: 'Play: Nice work!' },
      { src: "/audio/Engineer_autodestroyedsentry01.mp3", quote: '"Sentry down!"', cat: "error", label: 'Play: Sentry down!' },
      { src: "/audio/Engineer_wranglekills01.mp3", quote: '"Ain\'t on auto-pilot, son!"', cat: "permission", label: "Play: Ain't on auto-pilot, son!" },
      { src: "/audio/Engineer_goldenwrenchkill04.mp3", quote: '"Erectin\' a statue of a moron."', cat: "annoyed", label: "Play: Erectin' a statue of a moron." },
    ],
  },
];

const CAROUSEL_DOT_LABELS = [
  "Orc Peon",
  "Human Peasant",
  "Soviet Engineer",
  "Battlecruiser",
  "Sarah Kerrigan",
  "TF2 Engineer",
];

/* ------------------------------------------------------------------ */
/*  Main Page Component                                                */
/* ------------------------------------------------------------------ */

export default function LandingPage() {
  /* ---- Audio state (shared across all sections) ---- */
  const currentAudioRef = useRef<HTMLAudioElement | null>(null);
  const currentCardRef = useRef<string | null>(null);
  const [playingAudioCard, setPlayingAudioCard] = useState<string | null>(null);

  /* ---- Terminal state ---- */
  const [termSoundEnabled, setTermSoundEnabled] = useState(false);
  const [termVisibleLines, setTermVisibleLines] = useState<Set<number>>(new Set());
  const [beaconDismissed, setBeaconDismissed] = useState(false);
  const termTimeoutsRef = useRef<ReturnType<typeof setTimeout>[]>([]);
  const termAudioRef = useRef<HTMLAudioElement | null>(null);
  const termAnimatingRef = useRef(false);
  const termDemoRef = useRef<HTMLDivElement>(null);
  const hasAnimatedRef = useRef(false);

  /* ---- Carousel state ---- */
  const [carouselIndex, setCarouselIndex] = useState(0);
  const packAudioRef = useRef<HTMLAudioElement | null>(null);
  const [playingPackBtn, setPlayingPackBtn] = useState<string | null>(null);

  /* ---- Pack count ---- */
  const [packCount, setPackCount] = useState("43+");

  /* ---- Picker state ---- */
  const [registryPacks, setRegistryPacks] = useState<RegistryPack[]>([]);
  const [selectedPacks, setSelectedPacks] = useState<Set<string>>(new Set(DEFAULT_PACKS));
  const [activeFilter, setActiveFilter] = useState("en");
  const [searchQuery, setSearchQuery] = useState("");
  const [installMode, setInstallMode] = useState<"curl" | "brew">("curl");
  const [expandedPack, setExpandedPack] = useState<string | null>(null);
  const [pickerLoading, setPickerLoading] = useState(true);
  const [pickerError, setPickerError] = useState(false);
  const manifestCacheRef = useRef<Record<string, Manifest>>({});
  const [manifestData, setManifestData] = useState<Record<string, Manifest>>({});

  /* picker audio refs */
  const pickerAudioRef = useRef<HTMLAudioElement | null>(null);
  const [playingPickerPreview, setPlayingPickerPreview] = useState<string | null>(null);
  const expandAudioRef = useRef<HTMLAudioElement | null>(null);
  const [playingExpandSound, setPlayingExpandSound] = useState<string | null>(null);

  /* selectedPacks ref for hash updates */
  const selectedPacksRef = useRef(selectedPacks);
  selectedPacksRef.current = selectedPacks;
  const registryPacksRef = useRef(registryPacks);
  registryPacksRef.current = registryPacks;

  /* ---- Utility: stop all audio ---- */
  const stopAllAudio = useCallback(() => {
    if (currentAudioRef.current) {
      currentAudioRef.current.pause();
      currentAudioRef.current.currentTime = 0;
      currentAudioRef.current = null;
    }
    setPlayingAudioCard(null);
    currentCardRef.current = null;

    if (packAudioRef.current) {
      packAudioRef.current.pause();
      packAudioRef.current.currentTime = 0;
      packAudioRef.current = null;
    }
    setPlayingPackBtn(null);

    if (pickerAudioRef.current) {
      pickerAudioRef.current.pause();
      pickerAudioRef.current.currentTime = 0;
      pickerAudioRef.current = null;
    }
    setPlayingPickerPreview(null);

    if (expandAudioRef.current) {
      expandAudioRef.current.pause();
      expandAudioRef.current.currentTime = 0;
      expandAudioRef.current = null;
    }
    setPlayingExpandSound(null);
  }, []);

  /* ---- Audio card click ---- */
  const handleAudioCardClick = useCallback(
    (soundName: string) => {
      // If same card clicked while playing, stop
      if (currentCardRef.current === soundName && currentAudioRef.current && !currentAudioRef.current.paused) {
        currentAudioRef.current.pause();
        currentAudioRef.current.currentTime = 0;
        currentAudioRef.current = null;
        currentCardRef.current = null;
        setPlayingAudioCard(null);
        return;
      }

      // Stop everything
      stopAllAudio();

      const audio = new Audio("/audio/" + soundName + ".ogg");
      audio.play();
      currentAudioRef.current = audio;
      currentCardRef.current = soundName;
      setPlayingAudioCard(soundName);

      audio.addEventListener("ended", () => {
        setPlayingAudioCard(null);
        currentAudioRef.current = null;
        currentCardRef.current = null;
      });
    },
    [stopAllAudio]
  );

  /* ---- Terminal animation ---- */
  const animateTerminal = useCallback(
    (withSound: boolean) => {
      // Clear pending
      termTimeoutsRef.current.forEach((t) => clearTimeout(t));
      termTimeoutsRef.current = [];
      if (termAudioRef.current) {
        termAudioRef.current.pause();
        termAudioRef.current = null;
      }
      termAnimatingRef.current = true;
      setTermVisibleLines(new Set());

      TERMINAL_LINES.forEach((line, idx) => {
        const t = setTimeout(() => {
          setTermVisibleLines((prev) => {
            const next = new Set(prev);
            next.add(idx);
            return next;
          });
          if (withSound && line.sound) {
            if (termAudioRef.current) {
              termAudioRef.current.pause();
            }
            const a = new Audio("/audio/" + line.sound + ".ogg");
            a.volume = 0.7;
            a.play().catch(() => {});
            termAudioRef.current = a;
          }
        }, line.delay);
        termTimeoutsRef.current.push(t);
      });

      const maxDelay = Math.max(...TERMINAL_LINES.map((l) => l.delay));
      termTimeoutsRef.current.push(
        setTimeout(() => {
          termAnimatingRef.current = false;
        }, maxDelay + 500)
      );
    },
    []
  );

  /* ---- Terminal IntersectionObserver ---- */
  useEffect(() => {
    const el = termDemoRef.current;
    if (!el) return;

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting && !termAnimatingRef.current && !hasAnimatedRef.current) {
            hasAnimatedRef.current = true;
            animateTerminal(false);
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.3 }
    );

    observer.observe(el);
    return () => observer.disconnect();
  }, [animateTerminal]);

  /* ---- Terminal sound toggle ---- */
  const handleTermSoundToggle = useCallback(() => {
    setTermSoundEnabled((prev) => {
      const next = !prev;
      setBeaconDismissed(true);
      if (next) {
        animateTerminal(true);
      }
      return next;
    });
  }, [animateTerminal]);

  /* ---- Carousel ---- */
  const stopPackAudio = useCallback(() => {
    if (packAudioRef.current) {
      packAudioRef.current.pause();
      packAudioRef.current.currentTime = 0;
      packAudioRef.current = null;
    }
    setPlayingPackBtn(null);
  }, []);

  const goToSlide = useCallback(
    (i: number) => {
      stopPackAudio();
      const len = CAROUSEL_PACKS.length;
      setCarouselIndex(((i % len) + len) % len);
    },
    [stopPackAudio]
  );

  const handlePackSoundClick = useCallback(
    (src: string, key: string) => {
      // Toggle off if same
      if (playingPackBtn === key && packAudioRef.current && !packAudioRef.current.paused) {
        stopPackAudio();
        return;
      }
      stopAllAudio();

      const audio = new Audio(src);
      audio.play().catch(() => {});
      packAudioRef.current = audio;
      setPlayingPackBtn(key);

      audio.addEventListener("ended", () => {
        setPlayingPackBtn(null);
        packAudioRef.current = null;
      });
    },
    [playingPackBtn, stopPackAudio, stopAllAudio]
  );

  /* ---- Pack count fetch ---- */
  useEffect(() => {
    fetch("https://peonping.github.io/registry/index.json")
      .then((r) => r.json())
      .then((data) => {
        const count = Array.isArray(data)
          ? data.length
          : data.packs
          ? data.packs.length
          : Object.keys(data).length;
        setPackCount(count + "+");
      })
      .catch(() => {});
  }, []);

  /* ---- Picker: hash sync + registry load ---- */
  useEffect(() => {
    async function loadRegistry() {
      try {
        const resp = await fetch(REGISTRY_URL);
        const data = await resp.json();
        const packs: RegistryPack[] = data.packs || [];
        setRegistryPacks(packs);

        const hashPacks = parseHashPacks();
        const validNames = new Set(packs.map((p: RegistryPack) => p.name));

        if (hashPacks === "all") {
          setSelectedPacks(new Set(validNames));
        } else if (hashPacks !== null) {
          setSelectedPacks(new Set([...hashPacks].filter((n) => validNames.has(n))));
        }

        setPickerLoading(false);

        // Scroll to picker if shared URL
        if (hashPacks !== null) {
          setTimeout(() => {
            document.getElementById("picker")?.scrollIntoView({ behavior: "smooth" });
          }, 100);
        }
      } catch {
        setPickerError(true);
        setPickerLoading(false);
      }
    }
    loadRegistry();
  }, []);

  /* ---- Picker: update hash when selectedPacks changes ---- */
  useEffect(() => {
    if (registryPacks.length === 0) return;
    if (setsEqual(selectedPacks, DEFAULT_PACKS)) {
      if (window.location.hash.startsWith("#packs=")) {
        history.replaceState(null, "", window.location.pathname);
      }
      return;
    }
    if (selectedPacks.size === 0) {
      history.replaceState(null, "", "#packs=none");
      return;
    }
    history.replaceState(null, "", "#packs=" + Array.from(selectedPacks).sort().join(","));
  }, [selectedPacks, registryPacks]);

  /* ---- Picker: compute install command ---- */
  const pickerCommand = (() => {
    if (installMode === "brew") {
      const brew = "brew install PeonPing/tap/peon-ping && peon-ping-setup";
      if (selectedPacks.size === 0 || setsEqual(selectedPacks, DEFAULT_PACKS)) {
        return brew;
      } else if (selectedPacks.size === registryPacks.length) {
        return brew + " --all";
      } else {
        return brew + " --packs=" + Array.from(selectedPacks).sort().join(",");
      }
    } else {
      const base = "curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash";
      if (selectedPacks.size === 0 || setsEqual(selectedPacks, DEFAULT_PACKS)) {
        return base;
      } else if (selectedPacks.size === registryPacks.length) {
        return base + " -s -- --all";
      } else {
        return base + " -s -- --packs=" + Array.from(selectedPacks).sort().join(",");
      }
    }
  })();

  /* ---- Picker: toggle pack ---- */
  const togglePickerPack = useCallback((name: string) => {
    setSelectedPacks((prev) => {
      const next = new Set(prev);
      if (next.has(name)) next.delete(name);
      else next.add(name);
      return next;
    });
  }, []);

  /* ---- Picker: filter and search ---- */
  const knownLangs = ["en", "ru", "es", "fr", "cs", "pt-BR"];
  const filteredPacks = registryPacks
    .filter((p) => {
      if (activeFilter === "all") return true;
      if (activeFilter === "other") return !knownLangs.includes(p.language || "");
      return p.language === activeFilter;
    })
    .filter((p) => {
      if (!searchQuery) return true;
      const hay = [p.display_name, p.name, p.description || "", (p.author && p.author.name) || "", (p.tags || []).join(" ")].join(" ").toLowerCase();
      return hay.includes(searchQuery);
    });

  /* ---- Picker: expand/collapse ---- */
  const stopExpandAudio = useCallback(() => {
    if (expandAudioRef.current) {
      expandAudioRef.current.pause();
      expandAudioRef.current.currentTime = 0;
      expandAudioRef.current = null;
    }
    setPlayingExpandSound(null);
  }, []);

  const toggleExpand = useCallback(
    (packName: string) => {
      stopExpandAudio();
      setExpandedPack((prev) => (prev === packName ? null : packName));
    },
    [stopExpandAudio]
  );

  /* ---- Picker: load manifest for expanded pack ---- */
  useEffect(() => {
    if (!expandedPack) return;
    if (manifestCacheRef.current[expandedPack]) {
      setManifestData((prev) => ({
        ...prev,
        [expandedPack]: manifestCacheRef.current[expandedPack],
      }));
      return;
    }

    const pack = registryPacks.find((p) => p.name === expandedPack);
    if (!pack) return;

    const sp = pack.source_path ? pack.source_path + "/" : "";
    const url = "https://raw.githubusercontent.com/" + pack.source_repo + "/" + pack.source_ref + "/" + sp + "openpeon.json";

    fetch(url)
      .then((r) => r.json())
      .then((manifest: Manifest) => {
        manifestCacheRef.current[pack.name] = manifest;
        setManifestData((prev) => ({ ...prev, [pack.name]: manifest }));
      })
      .catch(() => {});
  }, [expandedPack, registryPacks]);

  /* ---- Picker: preview audio ---- */
  const handlePickerPreview = useCallback(
    (packName: string, e: React.MouseEvent) => {
      e.stopPropagation();
      const pack = registryPacks.find((p) => p.name === packName);
      if (!pack || !pack.preview_sounds || !pack.preview_sounds.length) return;

      if (playingPickerPreview === packName && pickerAudioRef.current && !pickerAudioRef.current.paused) {
        pickerAudioRef.current.pause();
        pickerAudioRef.current.currentTime = 0;
        pickerAudioRef.current = null;
        setPlayingPickerPreview(null);
        return;
      }

      stopAllAudio();

      const soundFile = pack.preview_sounds[0];
      const sp = pack.source_path ? pack.source_path + "/" : "";
      const url = "https://raw.githubusercontent.com/" + pack.source_repo + "/" + pack.source_ref + "/" + sp + "sounds/" + soundFile;

      const audio = new Audio(url);
      audio.play().catch(() => {});
      pickerAudioRef.current = audio;
      setPlayingPickerPreview(packName);

      audio.addEventListener("ended", () => {
        setPlayingPickerPreview(null);
        pickerAudioRef.current = null;
      });
    },
    [registryPacks, playingPickerPreview, stopAllAudio]
  );

  /* ---- Picker: expand sound play ---- */
  const handleExpandSoundPlay = useCallback(
    (src: string, key: string, e: React.MouseEvent) => {
      e.stopPropagation();
      if (playingExpandSound === key && expandAudioRef.current && !expandAudioRef.current.paused) {
        stopExpandAudio();
        return;
      }
      stopAllAudio();

      const audio = new Audio(src);
      audio.play().catch(() => {});
      expandAudioRef.current = audio;
      setPlayingExpandSound(key);

      audio.addEventListener("ended", () => {
        setPlayingExpandSound(null);
        expandAudioRef.current = null;
      });
    },
    [playingExpandSound, stopExpandAudio, stopAllAudio]
  );

  /* ---- Carousel keyboard support ---- */
  const handlePacksKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === "ArrowLeft") goToSlide(carouselIndex - 1);
      if (e.key === "ArrowRight") goToSlide(carouselIndex + 1);
    },
    [goToSlide, carouselIndex]
  );

  /* ---- Collapsed expanded if filtered out ---- */
  useEffect(() => {
    if (expandedPack && !filteredPacks.find((p) => p.name === expandedPack)) {
      stopExpandAudio();
      setExpandedPack(null);
    }
  }, [filteredPacks, expandedPack, stopExpandAudio]);

  /* ================================================================ */
  /*  RENDER                                                           */
  /* ================================================================ */

  return (
    <>
      {/* Atmospheric glow orb */}
      <div className="atmosphere">
        <div className="atmosphere-orb"></div>
      </div>

      {/* ============ HERO ============ */}
      <section className="hero">
        <div className="container">
          <div className="hero-mascot">
            <img src="/images/peon-portrait.gif" alt="Peon mascot" className="peon-avatar" />
          </div>
          <p className="hero-label" style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 16 }}>
            <a href="https://github.com/PeonPing/peon-ping" style={{ color: "var(--wc3-gold)", textDecoration: "none", display: "inline-flex", alignItems: "center", gap: 6 }}>
              <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
                <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z" />
              </svg>
              GitHub
            </a>
            <span style={{ color: "var(--wc3-text-dim)" }}>&middot;</span>
            <a href="https://x.com/peonping" style={{ color: "var(--wc3-gold)", textDecoration: "none", display: "inline-flex", alignItems: "center", gap: 6 }}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
              </svg>
              @peonping
            </a>
            <span style={{ color: "var(--wc3-text-dim)" }}>&middot;</span>
            <a href="https://discord.gg/guEDn2Umen" target="_blank" rel="noopener noreferrer" style={{ color: "var(--wc3-gold)", textDecoration: "none", display: "inline-flex", alignItems: "center", gap: 6 }}>
              <svg width="16" height="13" viewBox="0 0 71 55" fill="currentColor">
                <path d="M60.1 4.9A58.5 58.5 0 0045.4.2a.2.2 0 00-.2.1 40.8 40.8 0 00-1.8 3.7 54 54 0 00-16.2 0A37.4 37.4 0 0025.4.3a.2.2 0 00-.2-.1 58.4 58.4 0 00-14.7 4.6.2.2 0 00-.1.1C1.5 18.7-.9 32 .3 45.1v.2a58.9 58.9 0 0017.8 9 .2.2 0 00.3-.1 42.2 42.2 0 003.6-5.9.2.2 0 00-.1-.3 38.8 38.8 0 01-5.5-2.7.2.2 0 01 0-.4l1.1-.9a.2.2 0 01.2 0 42 42 0 0035.8 0 .2.2 0 01.2 0l1.1.9a.2.2 0 010 .4 36.4 36.4 0 01-5.5 2.7.2.2 0 00-.1.3 47.4 47.4 0 003.6 5.9.2.2 0 00.3.1 58.7 58.7 0 0017.9-9 .2.2 0 00.1-.2c1.4-15-2.3-28-9.9-39.6a.2.2 0 00-.1-.1zM23.7 37c-3.4 0-6.3-3.2-6.3-7s2.8-7 6.3-7 6.3 3.1 6.3 7-2.8 7-6.3 7zm23.3 0c-3.4 0-6.3-3.2-6.3-7s2.8-7 6.3-7 6.4 3.1 6.3 7-2.8 7-6.3 7z"/>
              </svg>
              Discord
            </a>
          </p>
          <h1>Stop babysitting your terminal</h1>
          <p className="hero-sub">
            Game character voice lines the instant <strong>Claude Code</strong>, <strong>Codex</strong>, <strong>Cursor</strong>, <strong>OpenCode</strong>, <strong>Kiro</strong>, or <strong>Antigravity</strong> finishes or needs permission. Never lose flow to a silent terminal again.
          </p>
          <CopyBlock command="brew install PeonPing/tap/peon-ping" />
          <p style={{ textAlign: "center", marginTop: "0.75rem", color: "var(--wc3-text-dim)", fontSize: "0.85rem" }}>
            or <code style={{ color: "var(--wc3-gold)", fontSize: "0.85rem" }}>curl -fsSL peonping.com/install | bash</code>
          </p>
        </div>
      </section>

      {/* ============ TERMINAL DEMO ============ */}
      <section className="terminal-hero" id="terminal">
        <div className="container">
          <div className="terminal-wrap" id="terminalDemo" ref={termDemoRef}>
            <div className="terminal-bar">
              <span className="terminal-dot red"></span>
              <span className="terminal-dot yellow"></span>
              <span className="terminal-dot green"></span>
              <span className="terminal-bar-title">peon-demo: ready</span>
              <button
                className={`terminal-sound-toggle${termSoundEnabled ? " active" : ""}`}
                id="termSoundToggle"
                title="Play sounds with animation"
                onClick={handleTermSoundToggle}
              >
                <span className={`sound-beacon-wrap${beaconDismissed ? " dismissed" : ""}`} id="soundBeacon">
                  <span className="sound-beacon"></span>
                  <span className="sound-tooltip">Hear the Peon!</span>
                </span>
                <svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor">
                  <path d="M8 1.5L4 5H1v6h3l4 3.5V1.5z" />
                  <path className="sound-wave" d="M11 4.5a6.5 6.5 0 010 7M11 7a3 3 0 010 2" fill="none" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
                </svg>
                <span>sound</span>
              </button>
            </div>
            <div className="terminal-body">
              {TERMINAL_LINES.map((line, idx) => (
                <div
                  key={idx}
                  className={`term-line${termVisibleLines.has(idx) ? " visible" : ""}`}
                  data-delay={line.delay}
                  data-sound={line.sound || undefined}
                >
                  {line.content}
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* ============ AUDIO DEMO ============ */}
      <section id="sounds">
        <div className="container">
          <p className="section-label">Sound check</p>
          <h2 className="section-title">Meet your new coworker</h2>
          <p className="section-desc">Click to play. These are the actual sounds you&apos;ll hear.</p>
          <div className="audio-grid">
            {AUDIO_CARDS.map((card) => (
              <div
                key={card.sound}
                className={`audio-card${playingAudioCard === card.sound ? " playing" : ""}`}
                role="button"
                tabIndex={0}
                aria-label={`Play: ${card.quote}`}
                onClick={() => handleAudioCardClick(card.sound)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" || e.key === " ") {
                    e.preventDefault();
                    handleAudioCardClick(card.sound);
                  }
                }}
              >
                <div className="audio-play-icon">
                  {playingAudioCard === card.sound ? "\u25A0" : "\u25B6"}
                </div>
                <div className="audio-quote">{card.quote}</div>
                <div className="audio-file">{card.file}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ============ SOUND PACKS CAROUSEL ============ */}
      <section id="packs" onKeyDown={handlePacksKeyDown}>
        <div className="container">
          <p className="section-label">Sound packs</p>
          <h2 className="section-title">Choose your character</h2>
          <p className="section-desc">Swap packs with one line in config. Click sounds to preview.</p>

          <div className="carousel-wrap">
            <button className="carousel-arrow carousel-prev" aria-label="Previous pack" onClick={() => goToSlide(carouselIndex - 1)}>
              <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M12 4l-6 6 6 6" />
              </svg>
            </button>

            <div className="carousel-viewport">
              {CAROUSEL_PACKS.map((pack, i) => (
                <div key={pack.id} className={`carousel-slide${i === carouselIndex ? " active" : ""}`} data-pack={pack.id}>
                  <div className="pack-card-full">
                    <div className="pack-header">
                      <div className="pack-badge">{pack.badge}</div>
                      <div className="pack-name">{pack.name}</div>
                      <div className="pack-game">{pack.game}</div>
                      <code className="pack-id">{pack.id}</code>
                      <div className="pack-credit">
                        Added by <a href={pack.creditUrl}>{pack.credit}</a>
                      </div>
                    </div>
                    <div className="pack-sounds">
                      {pack.sounds.map((sound, si) => {
                        const key = `${pack.id}-${si}`;
                        return (
                          <button
                            key={key}
                            className={`pack-sound-btn${playingPackBtn === key ? " playing" : ""}`}
                            data-src={sound.src}
                            aria-label={sound.label}
                            onClick={() => handlePackSoundClick(sound.src, key)}
                          >
                            <span className="pack-sound-icon">
                              {playingPackBtn === key ? "\u25A0" : "\u25B6"}
                            </span>
                            <span className="pack-sound-quote">{sound.quote}</span>
                            <span className="pack-sound-cat">{sound.cat}</span>
                          </button>
                        );
                      })}
                    </div>
                  </div>
                </div>
              ))}
            </div>

            <button className="carousel-arrow carousel-next" aria-label="Next pack" onClick={() => goToSlide(carouselIndex + 1)}>
              <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M8 4l6 6-6 6" />
              </svg>
            </button>
          </div>

          <div className="carousel-dots">
            {CAROUSEL_DOT_LABELS.map((label, i) => (
              <button key={i} className={`carousel-dot${i === carouselIndex ? " active" : ""}`} aria-label={label} onClick={() => goToSlide(i)} />
            ))}
          </div>

          <div className="contribute-cta">
            <p>
              <strong><span className="pack-count">{packCount}</span> packs and counting!</strong> You&apos;re only seeing a few above &mdash; there are many more including GLaDOS, StarCraft Terran units, Czech, Spanish &amp; Russian &amp; Polish Warcraft packs, and others.
            </p>
            <p>
              Run <code>peon packs list</code> to see them all, or <a href="https://openpeon.com/packs">browse the full catalog at openpeon.com</a>.
            </p>
            <p className="contribute-ideas">
              <strong>Want to add your own?</strong> Any game, any character &mdash; create a GitHub repo with your sounds, register it, and it&apos;s available to everyone. <a href="https://openpeon.com/create">Create a pack &rarr;</a>
            </p>
          </div>
        </div>
      </section>

      {/* ============ PACK PICKER ============ */}
      <section id="picker">
        <div className="container">
          <p className="section-label">Build your install</p>
          <h2 className="section-title">Pick your packs</h2>
          <p className="section-desc">Select the sound packs you want. Your custom install command updates live.</p>

          <input
            type="text"
            className="picker-search"
            id="pickerSearch"
            placeholder="Search packs..."
            autoComplete="off"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value.toLowerCase().trim())}
          />

          <div className="picker-filters">
            {[
              { lang: "en", label: "English" },
              { lang: "ru", label: "Russian" },
              { lang: "es", label: "Spanish" },
              { lang: "fr", label: "French" },
              { lang: "cs", label: "Czech" },
              { lang: "pt-BR", label: "Portuguese (BR)" },
              { lang: "other", label: "Other" },
              { lang: "all", label: "All" },
            ].map((f) => (
              <button
                key={f.lang}
                className={`picker-filter${activeFilter === f.lang ? " active" : ""}`}
                data-lang={f.lang}
                onClick={() => setActiveFilter(f.lang)}
              >
                {f.label}
              </button>
            ))}
          </div>

          <div className="picker-grid" id="pickerGrid">
            {pickerLoading ? (
              <div className="picker-loading">Loading packs from registry...</div>
            ) : pickerError ? (
              <div className="picker-loading">Could not load registry. Use the default install command above.</div>
            ) : filteredPacks.length === 0 ? (
              <div className="picker-loading">No packs match your search.</div>
            ) : (
              filteredPacks.map((pack) => {
                const sel = selectedPacks.has(pack.name);
                const isDef = DEFAULT_PACKS.has(pack.name);
                const isExpanded = expandedPack === pack.name;
                const langLabel = pack.language ? pack.language.toUpperCase() : "EN";
                const manifest = manifestData[pack.name];

                return (
                  <div
                    key={pack.name}
                    className={`picker-card${sel ? " selected" : ""}${isExpanded ? " expanded" : ""}`}
                    data-pack={pack.name}
                    onClick={(e) => {
                      const target = e.target as HTMLElement;
                      if (target.closest(".picker-card-preview")) return;
                      if (target.closest(".picker-expand-sound")) return;
                      if (target.closest(".picker-checkbox")) {
                        togglePickerPack(pack.name);
                        return;
                      }
                      toggleExpand(pack.name);
                    }}
                  >
                    <div className="picker-card-top">
                      <div className="picker-checkbox">{sel ? "\u2713" : ""}</div>
                      <div className="picker-card-name">{pack.display_name}</div>
                    </div>
                    <div className="picker-card-meta">
                      {langLabel} &middot; {pack.sound_count} sounds
                    </div>
                    <div className="picker-card-bottom">
                      {isDef ? <span className="picker-default-badge">default</span> : <span></span>}
                      <button
                        className={`picker-card-preview${playingPickerPreview === pack.name ? " playing" : ""}`}
                        data-pack={pack.name}
                        aria-label={`Preview ${pack.display_name}`}
                        onClick={(e) => handlePickerPreview(pack.name, e)}
                      >
                        {playingPickerPreview === pack.name ? "\u25A0" : "\u25B6"}
                      </button>
                    </div>
                    <div className="picker-card-expand-area" id={`expand-${pack.name}`}>
                      {isExpanded && manifest ? (
                        <>
                          {pack.description && (
                            <div className="picker-expand-desc">{pack.description}</div>
                          )}
                          {(() => {
                            const categories = manifest.categories || {};
                            const sp = pack.source_path ? pack.source_path + "/" : "";
                            const baseUrl = "https://raw.githubusercontent.com/" + pack.source_repo + "/" + pack.source_ref + "/" + sp;

                            return Object.entries(categories).map(([catKey, cat]) => {
                              const rawCat = cat as ManifestCategory | ManifestSound[];
                              const sounds: ManifestSound[] = Array.isArray(rawCat)
                                ? rawCat
                                : (rawCat as ManifestCategory).sounds || [];
                              if (!Array.isArray(sounds) || sounds.length === 0) return null;

                              return (
                                <div key={catKey}>
                                  <div className="picker-expand-category">{catKey}</div>
                                  <div className="picker-expand-sounds">
                                    {sounds.map((sound, si) => {
                                      const filePath = sound.file || "";
                                      const soundUrl = filePath.startsWith("sounds/") ? baseUrl + filePath : baseUrl + "sounds/" + filePath;
                                      const soundKey = `${pack.name}-${catKey}-${si}`;
                                      return (
                                        <button
                                          key={soundKey}
                                          className={`picker-expand-sound${playingExpandSound === soundKey ? " playing" : ""}`}
                                          data-src={soundUrl}
                                          onClick={(e) => handleExpandSoundPlay(soundUrl, soundKey, e)}
                                        >
                                          <span className="picker-expand-sound-icon">
                                            {playingExpandSound === soundKey ? "\u25A0" : "\u25B6"}
                                          </span>
                                          <span className="picker-expand-sound-label">
                                            {sound.label || filePath}
                                          </span>
                                        </button>
                                      );
                                    })}
                                  </div>
                                </div>
                              );
                            });
                          })()}
                        </>
                      ) : isExpanded ? (
                        <div className="picker-loading" style={{ padding: "20px", gridColumn: "auto" }}>Loading sounds...</div>
                      ) : null}
                    </div>
                  </div>
                );
              })
            )}
          </div>

          <div className="picker-controls">
            <span className="picker-count" id="pickerCount">
              {selectedPacks.size} pack{selectedPacks.size !== 1 ? "s" : ""} selected
            </span>
            <button
              className="picker-btn"
              id="pickerSelectDefaults"
              onClick={() => setSelectedPacks(new Set(DEFAULT_PACKS))}
            >
              Defaults
            </button>
            <button
              className="picker-btn"
              id="pickerSelectAll"
              onClick={() => setSelectedPacks(new Set(registryPacks.map((p) => p.name)))}
            >
              All
            </button>
            <button
              className="picker-btn"
              id="pickerSelectNone"
              onClick={() => setSelectedPacks(new Set())}
            >
              None
            </button>
          </div>

          <div className="picker-command">
            <div className="picker-install-toggle">
              <button
                className={installMode === "curl" ? "active" : ""}
                data-mode="curl"
                onClick={() => setInstallMode("curl")}
              >
                curl
              </button>
              <button
                className={installMode === "brew" ? "active" : ""}
                data-mode="brew"
                onClick={() => setInstallMode("brew")}
              >
                brew
              </button>
            </div>
            <CopyBlock command={pickerCommand} id="pickerCommandCode" label="Copy custom install command" />
          </div>
        </div>
      </section>

      {/* ============ FEATURES ============ */}
      <section id="features">
        <div className="container">
          <p className="section-label">Details</p>
          <h2 className="section-title">Tuned for real work</h2>
          <div className="features-grid">
            <div className="feature-card">
              <div className="feature-icon">{"\uD83D\uDD0A"}</div>
              <div className="feature-text">
                <h3>Volume control</h3>
                <p>0.0 &ndash; 1.0 in config. Quiet enough for the office.</p>
              </div>
            </div>
            <div className="feature-card">
              <div className="feature-icon">{"\uD83D\uDD00"}</div>
              <div className="feature-text">
                <h3>No repeats</h3>
                <p>Tracks last played per category. Never the same line twice in a row.</p>
              </div>
            </div>
            <div className="feature-card">
              <div className="feature-icon">{"\uD83C\uDF9B"}</div>
              <div className="feature-text">
                <h3>Category toggles</h3>
                <p>Enable or disable greeting, acknowledge, complete, error, annoyed individually.</p>
              </div>
            </div>
            <div className="feature-card">
              <div className="feature-icon">{"\uD83D\uDCCB"}</div>
              <div className="feature-text">
                <h3>Tab titles</h3>
                <p>Terminal tab shows project name and status. Dot indicator when done.</p>
              </div>
            </div>
            <div className="feature-card">
              <div className="feature-icon">{"\uD83D\uDD14"}</div>
              <div className="feature-text">
                <h3>Desktop notifications</h3>
                <p>Push alerts when your terminal isn&apos;t focused. Never miss a permission prompt again.</p>
              </div>
            </div>
            <div className="feature-card">
              <div className="feature-icon">{"\uD83D\uDEE0"}</div>
              <div className="feature-text">
                <h3>Multi-IDE</h3>
                <p>Works with Claude Code, Codex, Cursor, OpenCode, Kiro, and Antigravity. Adapters for any IDE with hooks.</p>
              </div>
            </div>
            <div className="feature-card">
              <div className="feature-icon">{"\uD83D\uDCE6"}</div>
              <div className="feature-text">
                <h3>Pack system</h3>
                <p>
                  <span className="pack-count">{packCount}</span> packs across 7 languages. <a href="#picker">Pick your favorites</a> or <a href="https://openpeon.com/create">create your own.</a>
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ============ INSTALL CTA ============ */}
      <section id="install">
        <div className="container" style={{ textAlign: "center" }}>
          <h2 className="section-title">Ready to work?</h2>
          <p className="section-desc" style={{ margin: "0 auto 32px" }}>
            One command. Works with Claude Code, Codex, Cursor, OpenCode, Kiro, and Antigravity on macOS, Linux, and WSL2.
          </p>
          <CopyBlock command="brew install PeonPing/tap/peon-ping" />
          <p style={{ textAlign: "center", marginTop: "0.75rem", color: "var(--wc3-text-dim)", fontSize: "0.85rem" }}>
            or <code style={{ color: "var(--wc3-gold)", fontSize: "0.85rem" }}>curl -fsSL peonping.com/install | bash</code>
          </p>
        </div>
      </section>

      {/* ============ FOOTER ============ */}
      <footer>
        <div className="container">
          <p>
            MIT License &middot; <a href="https://github.com/PeonPing/peon-ping">GitHub</a> &middot; <a href="https://x.com/peonping">@peonping</a> &middot; <a href="https://discord.gg/guEDn2Umen" target="_blank" rel="noopener noreferrer">Discord</a>
          </p>
          <p>
            Sound files are property of their respective publishers. <a href="https://github.com/PeonPing/peon-ping/pulls">Contribute a pack</a>
          </p>
          <p style={{ marginTop: 16, fontSize: "0.68rem", color: "var(--wc3-text-dim)", opacity: 0.5 }}>
            support the project + have fun:{" "}
            <a href="https://dexscreener.com/base/0xf4bA744229aFB64E2571eef89AaceC2F524e8bA3" style={{ color: "var(--wc3-text-dim)", fontFamily: "var(--font-mono)", fontSize: "0.65rem" }}>
              0xf4ba744229afb64e2571eef89aacec2f524e8ba3
            </a>
          </p>
        </div>
      </footer>
    </>
  );
}
