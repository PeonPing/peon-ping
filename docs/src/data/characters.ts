export interface Character {
  id: string;
  name: string;
  faction: string;
  game: string;
  color: string;
  avatar: string;
}

export interface PostComment {
  characterId: string;
  text: string;
  timestamp: string;
}

export const characters: Record<string, Character> = {
  peon: {
    id: "peon",
    name: "Orc Peon",
    faction: "Horde",
    game: "Warcraft III",
    color: "#8B0000",
    avatar: "/characters/peon.png",
  },
  glados: {
    id: "glados",
    name: "GLaDOS",
    faction: "Aperture Science",
    game: "Portal",
    color: "#FF6600",
    avatar: "/characters/glados.png",
  },
  battlecruiser: {
    id: "battlecruiser",
    name: "Battlecruiser Captain",
    faction: "Terran Dominion",
    game: "StarCraft",
    color: "#4169E1",
    avatar: "/characters/battlecruiser.png",
  },
  peasant: {
    id: "peasant",
    name: "Human Peasant",
    faction: "Alliance",
    game: "Warcraft III",
    color: "#1E90FF",
    avatar: "/characters/peasant.png",
  },
  marine: {
    id: "marine",
    name: "Terran Marine",
    faction: "Terran Dominion",
    game: "StarCraft",
    color: "#2E8B57",
    avatar: "/characters/marine.png",
  },
  axe: {
    id: "axe",
    name: "Axe",
    faction: "Dire",
    game: "Dota 2",
    color: "#DC143C",
    avatar: "/characters/axe.png",
  },
  engineer: {
    id: "engineer",
    name: "Engineer",
    faction: "RED Team",
    game: "Team Fortress 2",
    color: "#B8860B",
    avatar: "/characters/engineer.png",
  },
  kerrigan: {
    id: "kerrigan",
    name: "Sarah Kerrigan",
    faction: "Zerg Swarm",
    game: "StarCraft",
    color: "#800080",
    avatar: "/characters/kerrigan.png",
  },
  speaki: {
    id: "speaki",
    name: "Petite Speaki",
    faction: "Legendary Pet",
    game: "Trickcal Chibi Go",
    color: "#FFB6C1",
    avatar: "/characters/speaki.jpg",
  },
};

export const postComments: Record<string, PostComment[]> = {
  "cesp-architecture": [
    {
      characterId: "peon",
      text: "me write this article. me very proud. took 3 gold worth of candle to finish. if you not understand something, is because you not peon. read again slower.",
      timestamp: "2 gold ago",
    },
    {
      characterId: "glados",
      text: "I've reviewed the specification. It's... adequate. The JSON schema validation is a nice touch, though I would have implemented it in approximately 0.003 seconds. The anti-repeat logic is charmingly primitive. I've already designed 47 superior alternatives. But sure. Arrays. That works too.",
      timestamp: "1 gold ago",
    },
    {
      characterId: "battlecruiser",
      text: "Event mapping system checks out. Reminds me of our tactical comm protocols. session.start, task.complete — clear, hierarchical, no ambiguity. Good copy. Battlecruiser operational.",
      timestamp: "58 minutes ago",
    },
    {
      characterId: "peasant",
      text: "I wish to formally request Alliance representation in the default pack list. We peasants have been building things since before the Horde even HAD a spec. 'More work?' Yes. Always more work. That's called PROFESSIONALISM.",
      timestamp: "45 minutes ago",
    },
    {
      characterId: "engineer",
      text: "Now that's a fine piece of work right there. The SSH relay? That's real engineering, son. Reminds me of my teleporter — sound goes in one end, comes out the other. And the async playback with nohup? *chef's kiss* That's how you build 'em.",
      timestamp: "32 minutes ago",
    },
    {
      characterId: "kerrigan",
      text: "The Swarm finds your 'platform detection cascade' interesting. We adapt to any host. Your code adapts to any platform. There are... parallels. The registry design is efficient — distributed, resilient, zero cost. Even the Overmind would approve of that resource allocation.",
      timestamp: "28 minutes ago",
    },
    {
      characterId: "axe",
      text: "AXE APPROVES OF THIS ARCHITECTURE! Dotted categories? AXE CHOPS DOTS! Anti-repeat logic? AXE NEVER REPEATS! Except 'AXE APPROVES.' AXE ALWAYS APPROVES GOOD CODE!",
      timestamp: "15 minutes ago",
    },
    {
      characterId: "marine",
      text: "Heh, you had me at 'stop poking me.' That spam detection? Story of my life, man. Every newbie player clicking me 50 times. At least NOW there's a proper event category for it. About damn time someone standardized that.",
      timestamp: "8 minutes ago",
    },
    {
      characterId: "speaki",
      text: "Cuayo - Speaki like mopping your codebase",
      timestamp: "3 minutes ago",
    },
  ],
};
