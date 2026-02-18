import React from "react";
import {
  AbsoluteFill,
  Audio,
  Img,
  Sequence,
  useCurrentFrame,
  interpolate,
  spring,
  useVideoConfig,
  staticFile,
} from "remotion";

// --- Color palette (Warcraft Horde) ---
const BG = "#1a1b26";
const BAR_BG = "#0c0d14";
const GREEN = "#4ade80";
const WC3_GOLD = "#ffab01";
const WC3_GOLD_DIM = "rgba(255, 171, 1, 0.3)";
const ACCENT = "#4caf50";
const DIM = "#505a79";
const BRIGHT = "#e0e8ff";
const RED = "#ef4444";

// --- Shared components ---

const TermLine: React.FC<{
  children: React.ReactNode;
  appearFrame: number;
}> = ({ children, appearFrame }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const localFrame = frame - appearFrame;
  if (localFrame < 0) return null;
  const opacity = spring({ frame: localFrame, fps, config: { damping: 20 } });
  const y = interpolate(opacity, [0, 1], [8, 0]);
  return (
    <div style={{ opacity, transform: `translateY(${y}px)`, marginBottom: 4 }}>
      {children}
    </div>
  );
};

const TypedText: React.FC<{
  text: string;
  startFrame: number;
  color: string;
  speed?: number;
}> = ({ text, startFrame, color, speed = 1.5 }) => {
  const frame = useCurrentFrame();
  const elapsed = frame - startFrame;
  const charsToShow = Math.min(Math.floor(elapsed * speed), text.length);
  return (
    <span style={{ color }}>
      {text.slice(0, charsToShow)}
      {charsToShow < text.length && (
        <span
          style={{
            display: "inline-block",
            width: 10,
            height: "1.1em",
            backgroundColor: GREEN,
            verticalAlign: "text-bottom",
            marginLeft: 1,
          }}
        />
      )}
    </span>
  );
};

const SoundBadge: React.FC<{ label: string }> = ({ label }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = spring({ frame, fps, config: { damping: 12 } });
  const pulse = interpolate(Math.sin(frame * 0.3), [-1, 1], [0.8, 1]);
  return (
    <span
      style={{
        color: DIM,
        fontSize: 20,
        marginLeft: 12,
        opacity: enter,
        transform: `scale(${pulse})`,
        display: "inline-block",
      }}
    >
      {label}
    </span>
  );
};

const TerminalChrome: React.FC<{
  children: React.ReactNode;
  tabTitle: string;
}> = ({ children, tabTitle }) => (
  <div
    style={{
      width: 940,
      borderRadius: 12,
      overflow: "hidden",
      border: "1px solid rgba(76,175,80,0.15)",
      boxShadow:
        "0 0 60px rgba(0,0,0,0.6), 0 0 4px rgba(76,175,80,0.1)",
    }}
  >
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 8,
        padding: "14px 18px",
        backgroundColor: BAR_BG,
        borderBottom: "1px solid rgba(76,175,80,0.1)",
      }}
    >
      <div style={{ width: 14, height: 14, borderRadius: "50%", backgroundColor: "#ff5f57" }} />
      <div style={{ width: 14, height: 14, borderRadius: "50%", backgroundColor: "#febc2e" }} />
      <div style={{ width: 14, height: 14, borderRadius: "50%", backgroundColor: "#28c840" }} />
      <div
        style={{
          marginLeft: "auto",
          display: "flex",
          alignItems: "center",
          gap: 8,
        }}
      >
        <Img
          src={staticFile("peon-portrait.gif")}
          style={{
            width: 20,
            height: 20,
            borderRadius: 3,
            border: `1px solid ${WC3_GOLD_DIM}`,
          }}
        />
        <span
          style={{
            fontFamily: "'JetBrains Mono', monospace",
            fontSize: 14,
            color: DIM,
          }}
        >
          {tabTitle}
        </span>
      </div>
    </div>
    <div
      style={{
        padding: "24px 28px",
        backgroundColor: BG,
        fontFamily: "'JetBrains Mono', monospace",
        fontSize: 22,
        lineHeight: 2,
        minHeight: 500,
      }}
    >
      {children}
    </div>
  </div>
);

// --- Act 1: INTRODUCING... PEON-PING 2.0 ---
const LaunchTitle: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Staggered reveals: Introducing → Peon-Ping → 2.0 → tagline
  const introSpring = spring({ frame, fps, config: { damping: 14 }, delay: 8 });
  const logoSpring = spring({ frame, fps, config: { damping: 10, mass: 1.1 }, delay: 20 });
  const versionSpring = spring({ frame, fps, config: { damping: 8, mass: 1.3 }, delay: 35 });
  const taglineSpring = spring({ frame, fps, config: { damping: 12 }, delay: 50 });
  const peonSpring = spring({ frame, fps, config: { damping: 10 }, delay: 30 });

  // Pulsing glow on "2.0"
  const glowPulse = interpolate(Math.sin(frame * 0.15), [-1, 1], [0.4, 1]);

  const exitOp = interpolate(frame, [90, 105], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: "#0a0a0f",
        justifyContent: "center",
        alignItems: "center",
        opacity: exitOp,
      }}
    >
      {/* Top accent line */}
      <div
        style={{
          position: "absolute",
          top: 0,
          left: 0,
          right: 0,
          height: 4,
          background: `linear-gradient(90deg, transparent, ${WC3_GOLD}, ${ACCENT}, ${WC3_GOLD}, transparent)`,
        }}
      />
      {/* Bottom accent line */}
      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: 0,
          right: 0,
          height: 4,
          background: `linear-gradient(90deg, transparent, ${WC3_GOLD}, ${ACCENT}, ${WC3_GOLD}, transparent)`,
        }}
      />

      {/* Corner decorations */}
      {[
        { top: 20, left: 20 },
        { top: 20, right: 20 },
        { bottom: 20, left: 20 },
        { bottom: 20, right: 20 },
      ].map((pos, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            ...pos,
            width: 40,
            height: 40,
            borderTop: i < 2 ? `2px solid ${WC3_GOLD}` : "none",
            borderBottom: i >= 2 ? `2px solid ${WC3_GOLD}` : "none",
            borderLeft: i % 2 === 0 ? `2px solid ${WC3_GOLD}` : "none",
            borderRight: i % 2 === 1 ? `2px solid ${WC3_GOLD}` : "none",
            opacity: 0.4,
          } as React.CSSProperties}
        />
      ))}

      {/* Main content - stacked vertically */}
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
        }}
      >
        {/* INTRODUCING... */}
        <div
          style={{
            fontFamily: "'JetBrains Mono', monospace",
            fontSize: 24,
            color: RED,
            letterSpacing: 14,
            textTransform: "uppercase",
            opacity: introSpring,
            transform: `translateY(${interpolate(introSpring, [0, 1], [15, 0])}px)`,
            marginBottom: 28,
          }}
        >
          INTRODUCING
        </div>

        {/* Peon-Ping logo + name */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 18,
            opacity: logoSpring,
            transform: `scale(${interpolate(logoSpring, [0, 1], [0.8, 1])}) translateY(${interpolate(logoSpring, [0, 1], [15, 0])}px)`,
            marginBottom: 16,
          }}
        >
          <Img
            src={staticFile("peon-portrait.gif")}
            style={{
              width: 80,
              height: 80,
              borderRadius: 8,
              border: `3px solid ${WC3_GOLD}`,
              boxShadow: `0 0 ${20 * glowPulse}px rgba(255,171,1,0.3)`,
            }}
          />
          <span
            style={{
              fontFamily: "Georgia, 'Palatino Linotype', serif",
              fontSize: 72,
              fontWeight: 700,
              color: "#fff",
              textShadow: "3px 3px 0 rgba(0,0,0,0.8)",
            }}
          >
            Peon-Ping
          </span>
        </div>

        {/* 2.0 - massive gold number */}
        <div
          style={{
            opacity: versionSpring,
            transform: `scale(${interpolate(versionSpring, [0, 1], [0.3, 1])})`,
          }}
        >
          <div
            style={{
              fontFamily: "'JetBrains Mono', monospace",
              fontSize: 180,
              fontWeight: 900,
              color: WC3_GOLD,
              textShadow: `0 0 ${60 * glowPulse}px rgba(255,171,1,0.5), 0 0 ${120 * glowPulse}px rgba(255,171,1,0.2), 0 4px 0 rgba(0,0,0,0.8)`,
              letterSpacing: -4,
              lineHeight: 0.9,
            }}
          >
            2.0
          </div>
        </div>

        {/* Tagline */}
        <div
          style={{
            fontFamily: "Georgia, serif",
            fontSize: 30,
            color: "rgba(255,255,255,0.45)",
            marginTop: 24,
            opacity: taglineSpring,
            transform: `translateY(${interpolate(taglineSpring, [0, 1], [10, 0])}px)`,
          }}
        >
          Get jacked while you code
        </div>
      </div>

      {/* Peon render bottom right */}
      <div
        style={{
          position: "absolute",
          bottom: 15,
          right: 25,
          opacity: peonSpring,
          transform: `scale(${interpolate(peonSpring, [0, 1], [0.6, 1])}) translateY(${interpolate(peonSpring, [0, 1], [30, 0])}px)`,
        }}
      >
        <Img
          src={staticFile("peon-render.png")}
          style={{
            width: 150,
            height: 180,
            objectFit: "contain",
            filter: "drop-shadow(0 4px 20px rgba(0,0,0,0.8))",
          }}
        />
      </div>
    </AbsoluteFill>
  );
};

// --- Act 2: Lucacs "jacked" tweet (the meme/context) ---
const JackedTweetReveal: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const imgSpring = spring({ frame, fps, config: { damping: 14 }, delay: 5 });
  // Slow zoom in for dramatic effect
  const zoom = interpolate(frame, [0, 120], [1, 1.05], {
    extrapolateRight: "clamp",
  });

  const exitOp = interpolate(frame, [100, 115], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: "#0a0a0f",
        justifyContent: "center",
        alignItems: "center",
        opacity: exitOp,
      }}
    >
      <div
        style={{
          opacity: imgSpring,
          transform: `scale(${interpolate(imgSpring, [0, 1], [0.85, 1]) * zoom})`,
        }}
      >
        <Img
          src={staticFile("lucacs-jacked-tweet.png")}
          style={{
            width: 950,
            borderRadius: 16,
            boxShadow: "0 8px 60px rgba(0,0,0,0.8)",
          }}
        />
      </div>
    </AbsoluteFill>
  );
};

// --- Act 3: Gigachad tweet (the meme) ---
const GigachadReveal: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const imgSpring = spring({ frame, fps, config: { damping: 14 }, delay: 5 });
  const zoom = interpolate(frame, [0, 120], [1, 1.05], {
    extrapolateRight: "clamp",
  });

  const exitOp = interpolate(frame, [100, 115], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: "#0a0a0f",
        justifyContent: "center",
        alignItems: "center",
        opacity: exitOp,
      }}
    >
      <div
        style={{
          opacity: imgSpring,
          transform: `scale(${interpolate(imgSpring, [0, 1], [0.85, 1]) * zoom})`,
        }}
      >
        <Img
          src={staticFile("steipete-gigachad.png")}
          style={{
            width: 950,
            borderRadius: 16,
            boxShadow: "0 8px 60px rgba(0,0,0,0.8)",
          }}
        />
      </div>
    </AbsoluteFill>
  );
};

// --- Act 4: Steipete reply tweet (the ask) ---
const PushupTweetReveal: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const imgSpring = spring({ frame, fps, config: { damping: 14 }, delay: 5 });
  const zoom = interpolate(frame, [0, 120], [1, 1.04], {
    extrapolateRight: "clamp",
  });

  const exitOp = interpolate(frame, [100, 115], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: "#0a0a0f",
        justifyContent: "center",
        alignItems: "center",
        opacity: exitOp,
      }}
    >
      <div
        style={{
          opacity: imgSpring,
          transform: `scale(${interpolate(imgSpring, [0, 1], [0.85, 1]) * zoom})`,
        }}
      >
        <Img
          src={staticFile("steipete-pushup-tweet.png")}
          style={{
            width: 950,
            borderRadius: 16,
            boxShadow: "0 8px 60px rgba(0,0,0,0.8)",
          }}
        />
      </div>
    </AbsoluteFill>
  );
};

// --- Act 4: "Say no more." hard cut punchline ---
const SayNoMore: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const textSpring = spring({ frame, fps, config: { damping: 8, mass: 1.5 }, delay: 5 });
  const glowPulse = interpolate(Math.sin(frame * 0.2), [-1, 1], [0.5, 1]);

  const exitOp = interpolate(frame, [55, 70], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: "#000",
        justifyContent: "center",
        alignItems: "center",
        opacity: exitOp,
      }}
    >
      <div
        style={{
          opacity: textSpring,
          transform: `scale(${interpolate(textSpring, [0, 1], [0.7, 1])})`,
        }}
      >
        <div
          style={{
            fontFamily: "Georgia, 'Palatino Linotype', serif",
            fontSize: 90,
            fontWeight: 700,
            fontStyle: "italic",
            color: WC3_GOLD,
            textShadow: `0 0 ${40 * glowPulse}px rgba(255,171,1,0.4), 0 0 ${80 * glowPulse}px rgba(255,171,1,0.15)`,
            textAlign: "center",
          }}
        >
          Say no more.
        </div>
      </div>
    </AbsoluteFill>
  );
};

// --- Act 5: Terminal demo ---
// Narrative: user starts session → peon immediately greets with workout encouragement → user does pushups → logs → back to coding → another reminder
const TERMINAL_EVENTS = [
  {
    frame: 0,
    type: "line" as const,
    text: "$ peon trainer on",
    style: "cmd" as const,
  },
  {
    frame: 20,
    type: "line" as const,
    text: "peon-ping: trainer enabled  (0/300 pushups, 0/300 squats)",
    style: "output" as const,
  },
  {
    frame: 55,
    type: "line" as const,
    text: "$ claude",
    style: "cmd" as const,
  },
  {
    frame: 75,
    type: "line" as const,
    text: "  Starting session...",
    style: "dim" as const,
  },
  {
    frame: 100,
    type: "sound-line" as const,
    text: '\u{1F50A} "Session start! You know the rules."',
    sound: "trainer/know_the_rules.mp3",
    label: "\u2014 pushups first, code second!",
  },
  {
    frame: 310,
    type: "line" as const,
    text: "  [drops and does 25 pushups]",
    style: "dim" as const,
  },
  {
    frame: 340,
    type: "line" as const,
    text: "$ /peon-ping-log 25 pushups",
    style: "cmd" as const,
  },
  {
    frame: 370,
    type: "sound-line" as const,
    text: '\u{1F50A} "Not bad for puny human."',
    sound: "trainer/not_bad.mp3",
    label: "\u2014 reps logged",
  },
  {
    frame: 475,
    type: "line" as const,
    text: "  pushups:  \u2588\u2588\u2591\u2591\u2591\u2591\u2591\u2591\u2591\u2591\u2591\u2591\u2591\u2591\u2591\u2591  25/300  (8%)",
    style: "progress" as const,
  },
  {
    frame: 495,
    type: "line" as const,
    text: "  squats:   \u2591\u2591\u2591\u2591\u2591\u2591\u2591\u2591\u2591\u2591\u2591\u2591\u2591\u2591\u2591\u2591   0/300  (0%)",
    style: "progress" as const,
  },
  {
    frame: 530,
    type: "line" as const,
    text: "  [back to coding... 20 min later]",
    style: "dim" as const,
  },
  {
    frame: 560,
    type: "sound-line" as const,
    text: '\u{1F50A} "Work work... on MUSCLES!"',
    sound: "trainer/work_on_muscles.mp3",
    label: "\u2014 peon never stops",
  },
];

const TerminalDemo: React.FC = () => {
  const frame = useCurrentFrame();

  const tabTitle = "my-project: working";

  const termOp = interpolate(frame, [0, 10], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const termExitOp = interpolate(frame, [720, 740], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: "#0a0a0f",
        justifyContent: "center",
        alignItems: "center",
        opacity: Math.min(termOp, termExitOp),
      }}
    >
      <TerminalChrome tabTitle={tabTitle}>
        {TERMINAL_EVENTS.map((event, i) => {
          if (event.type === "line") {
            return (
              <TermLine key={i} appearFrame={event.frame}>
                {event.style === "cmd" ? (
                  <TypedText
                    text={event.text}
                    startFrame={event.frame}
                    color={
                      event.text.startsWith("$") || event.text.startsWith(">")
                        ? GREEN
                        : BRIGHT
                    }
                  />
                ) : event.style === "output" ? (
                  <span style={{ color: ACCENT }}>{event.text}</span>
                ) : event.style === "progress" ? (
                  <span style={{ color: GREEN }}>{event.text}</span>
                ) : (
                  <span style={{ color: DIM }}>{event.text}</span>
                )}
              </TermLine>
            );
          }
          if (event.type === "sound-line") {
            return (
              <TermLine key={i} appearFrame={event.frame}>
                <span style={{ color: WC3_GOLD, fontWeight: 500 }}>
                  {event.text}
                </span>
                <SoundBadge label={event.label!} />
              </TermLine>
            );
          }
          return null;
        })}
      </TerminalChrome>

      <div
        style={{
          position: "absolute",
          bottom: 30,
          left: 40,
          display: "flex",
          alignItems: "center",
          gap: 10,
          opacity: 0.6,
        }}
      >
        <Img
          src={staticFile("peon-portrait.gif")}
          style={{
            width: 36,
            height: 36,
            borderRadius: 4,
            border: `1px solid ${WC3_GOLD_DIM}`,
          }}
        />
        <span
          style={{
            fontFamily: "'JetBrains Mono', monospace",
            fontSize: 15,
            fontWeight: 700,
            color: "rgba(255,255,255,0.5)",
          }}
        >
          {"\u{1D54F}"}
        </span>
        <span
          style={{
            fontFamily: "'JetBrains Mono', monospace",
            fontSize: 14,
            color: "rgba(255,255,255,0.4)",
          }}
        >
          @PeonPing
        </span>
      </div>
    </AbsoluteFill>
  );
};

// --- Act 6: Outro ---
const OutroCard: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = spring({ frame, fps, config: { damping: 12 } });
  const logoEnter = spring({ frame, fps, config: { damping: 14 }, delay: 5 });
  const peonEnter = spring({ frame, fps, config: { damping: 10 }, delay: 8 });
  const ctaEnter = spring({ frame, fps, config: { damping: 12 }, delay: 20 });
  const glowPulse = interpolate(Math.sin(frame * 0.12), [-1, 1], [0.5, 1]);

  return (
    <AbsoluteFill
      style={{
        backgroundColor: "#0a0a0f",
        justifyContent: "center",
        alignItems: "center",
      }}
    >
      {/* Top accent line */}
      <div
        style={{
          position: "absolute",
          top: 0,
          left: 0,
          right: 0,
          height: 4,
          background: `linear-gradient(90deg, transparent, ${WC3_GOLD}, ${ACCENT}, ${WC3_GOLD}, transparent)`,
        }}
      />
      {/* Bottom accent line */}
      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: 0,
          right: 0,
          height: 4,
          background: `linear-gradient(90deg, transparent, ${WC3_GOLD}, ${ACCENT}, ${WC3_GOLD}, transparent)`,
        }}
      />

      <div
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          opacity: enter,
          transform: `scale(${interpolate(enter, [0, 1], [0.9, 1])})`,
        }}
      >
        {/* Logo + name */}
        <div
          style={{
            marginBottom: 24,
            display: "flex",
            alignItems: "center",
            gap: 14,
            opacity: logoEnter,
            transform: `translateY(${interpolate(logoEnter, [0, 1], [10, 0])}px)`,
          }}
        >
          <Img
            src={staticFile("peon-portrait.gif")}
            style={{
              width: 80,
              height: 80,
              borderRadius: 6,
              border: `2px solid ${WC3_GOLD}`,
              boxShadow: `0 0 ${20 * glowPulse}px rgba(255,171,1,0.3)`,
            }}
          />
          <div style={{ display: "flex", flexDirection: "column" }}>
            <span
              style={{
                fontFamily: "'JetBrains Mono', monospace",
                fontSize: 32,
                fontWeight: 700,
                color: WC3_GOLD,
                letterSpacing: 1,
              }}
            >
              peon-ping
            </span>
            <span
              style={{
                fontFamily: "'JetBrains Mono', monospace",
                fontSize: 18,
                color: "rgba(255,171,1,0.5)",
                letterSpacing: 2,
              }}
            >
              VERSION 2.0
            </span>
          </div>
        </div>

        {/* Main tagline */}
        <div
          style={{
            fontFamily: "Georgia, serif",
            fontSize: 52,
            fontWeight: 600,
            color: "#fff",
            textShadow: "2px 2px 0 rgba(0,0,0,0.8)",
            marginBottom: 14,
            textAlign: "center",
          }}
        >
          Get jacked while you code
        </div>

        {/* The numbers */}
        <div
          style={{
            fontFamily: "Georgia, serif",
            fontSize: 30,
            color: "rgba(255,255,255,0.5)",
            marginBottom: 32,
          }}
        >
          300 pushups. 300 squats. Every day.
        </div>

        {/* CTA commands */}
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            gap: 10,
            opacity: ctaEnter,
            transform: `translateY(${interpolate(ctaEnter, [0, 1], [10, 0])}px)`,
          }}
        >
          <div
            style={{
              fontFamily: "monospace",
              fontSize: 24,
              color: WC3_GOLD,
              backgroundColor: "rgba(255,171,1,0.06)",
              padding: "12px 32px",
              borderRadius: 8,
              border: `1px solid ${WC3_GOLD_DIM}`,
              boxShadow: `0 0 ${30 * glowPulse}px rgba(255,171,1,0.1)`,
              textAlign: "center",
            }}
          >
            peon update
          </div>
          <div
            style={{
              fontFamily: "monospace",
              fontSize: 24,
              color: WC3_GOLD,
              backgroundColor: "rgba(255,171,1,0.06)",
              padding: "12px 32px",
              borderRadius: 8,
              border: `1px solid ${WC3_GOLD_DIM}`,
              boxShadow: `0 0 ${30 * glowPulse}px rgba(255,171,1,0.1)`,
              textAlign: "center",
            }}
          >
            peon trainer on
          </div>
        </div>

        {/* GitHub link */}
        <div
          style={{
            fontFamily: "monospace",
            fontSize: 18,
            color: "rgba(255,255,255,0.35)",
            marginTop: 24,
            opacity: ctaEnter,
          }}
        >
          github.com/NSXBet/peon-nsx
        </div>

        {/* Social */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 8,
            marginTop: 14,
            opacity: ctaEnter,
          }}
        >
          <span
            style={{
              fontFamily: "'JetBrains Mono', monospace",
              fontSize: 22,
              fontWeight: 700,
              color: "rgba(255,255,255,0.5)",
            }}
          >
            {"\u{1D54F}"}
          </span>
          <span
            style={{
              fontFamily: "'JetBrains Mono', monospace",
              fontSize: 18,
              color: "rgba(255,255,255,0.4)",
            }}
          >
            @PeonPing
          </span>
        </div>
      </div>

      {/* Peon render */}
      <div
        style={{
          position: "absolute",
          bottom: 20,
          right: 30,
          opacity: peonEnter,
          transform: `scale(${interpolate(peonEnter, [0, 1], [0.7, 1])}) translateY(${interpolate(peonEnter, [0, 1], [20, 0])}px)`,
        }}
      >
        <Img
          src={staticFile("peon-render.png")}
          style={{
            width: 120,
            height: 144,
            objectFit: "contain",
            filter: "drop-shadow(0 4px 16px rgba(0,0,0,0.7))",
          }}
        />
      </div>
    </AbsoluteFill>
  );
};

// --- Main composition ---
// Timeline:
//   Act 1: Intro title        (0-105)
//   Act 2: Lucacs tweet        (105-220)
//   Act 3: Gigachad tweet      (220-335)
//   Act 4: Pushup tweet        (335-450)
//   Act 5: "Say no more."      (450-520)
//   Act 6: Terminal demo        (520-1270)
//   Act 7: Outro               (1270-1400)
// Total: 1400 frames @ 30fps = ~46.7s
export const TrainerPromo: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: "#0a0a0f" }}>
      {/* Act 1: Introducing... Peon-Ping 2.0 */}
      <Sequence from={0} durationInFrames={106}>
        <LaunchTitle />
      </Sequence>

      {/* Act 2: Lucacs "jacked" tweet */}
      <Sequence from={105} durationInFrames={116}>
        <JackedTweetReveal />
      </Sequence>

      {/* Act 3: Gigachad meme tweet */}
      <Sequence from={220} durationInFrames={116}>
        <GigachadReveal />
      </Sequence>

      {/* Act 4: Pushup tweet reply */}
      <Sequence from={335} durationInFrames={116}>
        <PushupTweetReveal />
      </Sequence>

      {/* Act 5: "Say no more." punchline */}
      <Sequence from={450} durationInFrames={71}>
        <SayNoMore />
      </Sequence>

      {/* Act 6: Terminal demo with trainer */}
      <Sequence from={520} durationInFrames={750}>
        <TerminalDemo />
      </Sequence>

      {/* Act 6 audio - durations match actual file lengths so nothing gets cut off */}
      {/* know_the_rules.mp3 = ~6.5s = 200 frames */}
      <Sequence from={520 + 100} durationInFrames={200}>
        <Audio
          src={staticFile("sounds/trainer/know_the_rules.mp3")}
          volume={0.9}
        />
      </Sequence>
      {/* not_bad.mp3 = ~3s = 100 frames */}
      <Sequence from={520 + 370} durationInFrames={100}>
        <Audio
          src={staticFile("sounds/trainer/not_bad.mp3")}
          volume={0.9}
        />
      </Sequence>
      {/* work_on_muscles.mp3 = ~5s = 160 frames */}
      <Sequence from={520 + 560} durationInFrames={160}>
        <Audio
          src={staticFile("sounds/trainer/work_on_muscles.mp3")}
          volume={0.9}
        />
      </Sequence>

      {/* Act 7: Outro */}
      <Sequence from={1270} durationInFrames={130}>
        <OutroCard />
      </Sequence>

      {/* Background music: WC3 Orc theme — skip slow intro, start where it kicks in */}
      <Sequence from={0} durationInFrames={1400}>
        <Audio
          src={staticFile("sounds/wc3-orc-theme.mp3")}
          startFrom={600}
          volume={0.15}
        />
      </Sequence>
    </AbsoluteFill>
  );
};
