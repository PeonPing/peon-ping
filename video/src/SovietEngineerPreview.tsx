import React from "react";
import {
  AbsoluteFill,
  Audio,
  Sequence,
  useCurrentFrame,
  interpolate,
  spring,
  useVideoConfig,
  staticFile,
} from "remotion";

// --- Timeline (in frames at 30fps) ---
// Each event: frame it appears, what shows in terminal, optional sound
const TIMELINE = [
  // Intro title
  { frame: 0, type: "title" as const },
  // Terminal appears
  { frame: 75, type: "terminal-start" as const },
  // Type: claude
  { frame: 90, type: "line" as const, text: "$ claude", style: "cmd" as const },
  // Session starts → greeting sound
  { frame: 120, type: "sound-line" as const, text: '🔊 "Tools ready"', sound: "ToolsReady.mp3", label: "— session started" },
  // Type prompt
  { frame: 170, type: "line" as const, text: "> Refactor the database connection pool", style: "cmd" as const },
  // Working...
  { frame: 210, type: "line" as const, text: "  Claude is working...", style: "dim" as const },
  // Acknowledge sound
  { frame: 240, type: "sound-line" as const, text: '🔊 "Engineering"', sound: "Engineering.mp3", label: "— reading files" },
  // More work
  { frame: 290, type: "line" as const, text: "  [you switch to Slack]", style: "dim" as const },
  // Permission needed
  { frame: 330, type: "sound-line" as const, text: '🔊 "Yes, commander"', sound: "YesCommander.mp3", label: "— permission needed" },
  // Approve
  { frame: 390, type: "line" as const, text: "  [you hear it, switch back, approve]", style: "dim" as const },
  // Continue working
  { frame: 430, type: "line" as const, text: "  Claude continues working...", style: "dim" as const },
  // Checking designs
  { frame: 470, type: "sound-line" as const, text: '🔊 "Checking designs"', sound: "CheckingDesigns.mp3", label: "— analyzing code" },
  // Done
  { frame: 530, type: "sound-line" as const, text: '🔊 "Power up"', sound: "PowerUp.mp3", label: "— task complete" },
  // Cursor
  { frame: 580, type: "line" as const, text: "> ", style: "cursor" as const },
  // Error scenario
  { frame: 620, type: "line" as const, text: "> Deploy to production --force", style: "cmd" as const },
  { frame: 660, type: "line" as const, text: "  Error: Permission denied", style: "error" as const },
  { frame: 680, type: "sound-line" as const, text: '🔊 "Get me outta here!"', sound: "GetMeOuttaHere.mp3", label: "— error" },
  // Outro
  { frame: 740, type: "outro" as const },
];

const TOTAL_FRAMES = 840;

const BG = "#1a1b26";
const BAR_BG = "#0c0d14";
const GREEN = "#4ade80";
const GOLD = "#d4a520";
const RED = "#c41e1e";
const DIM = "#505a79";
const BRIGHT = "#e0e8ff";
const MUTED = "#9ca8c5";

const TermLine: React.FC<{
  children: React.ReactNode;
  appearFrame: number;
}> = ({ children, appearFrame }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const localFrame = frame - appearFrame;
  if (localFrame < 0) return null;

  const opacity = spring({
    frame: localFrame,
    fps,
    config: { damping: 20 },
  });
  const y = interpolate(opacity, [0, 1], [8, 0]);

  return (
    <div style={{ opacity, transform: `translateY(${y}px)`, marginBottom: 4 }}>
      {children}
    </div>
  );
};

// Typing animation for command text
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

// Blinking cursor
const Cursor: React.FC = () => {
  const frame = useCurrentFrame();
  const visible = Math.floor(frame / 15) % 2 === 0;
  return (
    <span
      style={{
        display: "inline-block",
        width: 10,
        height: "1.1em",
        backgroundColor: visible ? GREEN : "transparent",
        verticalAlign: "text-bottom",
      }}
    />
  );
};

// Sound indicator that pulses
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

// Terminal window chrome
const TerminalChrome: React.FC<{ children: React.ReactNode; tabTitle: string }> = ({
  children,
  tabTitle,
}) => {
  return (
    <div
      style={{
        width: 940,
        borderRadius: 12,
        overflow: "hidden",
        border: "1px solid #222233",
        boxShadow: "0 0 60px rgba(0,0,0,0.6), 0 0 2px rgba(212,165,32,0.15)",
      }}
    >
      {/* Title bar */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 8,
          padding: "14px 18px",
          backgroundColor: BAR_BG,
          borderBottom: "1px solid #222233",
        }}
      >
        <div style={{ width: 14, height: 14, borderRadius: "50%", backgroundColor: "#ff5f57" }} />
        <div style={{ width: 14, height: 14, borderRadius: "50%", backgroundColor: "#febc2e" }} />
        <div style={{ width: 14, height: 14, borderRadius: "50%", backgroundColor: "#28c840" }} />
        <div
          style={{
            marginLeft: "auto",
            fontFamily: "'JetBrains Mono', monospace",
            fontSize: 14,
            color: DIM,
          }}
        >
          {tabTitle}
        </div>
      </div>
      {/* Body */}
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
};

// Title card
const TitleCard: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const titleSpring = spring({ frame, fps, config: { damping: 12 }, delay: 5 });
  const subSpring = spring({ frame, fps, config: { damping: 12 }, delay: 20 });
  const exitOp = interpolate(frame, [60, 75], [1, 0], {
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
      <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: 4, background: RED }} />
      <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, height: 4, background: RED }} />
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          opacity: titleSpring,
          transform: `translateY(${interpolate(titleSpring, [0, 1], [20, 0])}px)`,
        }}
      >
        <div style={{ fontFamily: "monospace", fontSize: 22, color: RED, letterSpacing: 6, textTransform: "uppercase", marginBottom: 16, opacity: subSpring }}>
          peon-ping sound pack
        </div>
        <div style={{ fontFamily: "Georgia, 'Palatino Linotype', serif", fontSize: 76, fontWeight: 700, color: "#fff", textShadow: "3px 3px 0 rgba(0,0,0,0.8)", textAlign: "center", lineHeight: 1.2 }}>
          Soviet Engineer
        </div>
        <div style={{ fontFamily: "Georgia, serif", fontSize: 36, color: "rgba(255,255,255,0.5)", marginTop: 12, opacity: subSpring }}>
          Red Alert 2
        </div>
        <div style={{ fontFamily: "monospace", fontSize: 18, color: "rgba(255,255,255,0.3)", marginTop: 24, opacity: subSpring }}>
          peon-ping
        </div>
      </div>
    </AbsoluteFill>
  );
};

// Outro card
const OutroCard: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = spring({ frame, fps, config: { damping: 12 } });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: "#0a0a0f",
        justifyContent: "center",
        alignItems: "center",
      }}
    >
      <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: 4, background: RED }} />
      <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, height: 4, background: RED }} />
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          opacity: enter,
          transform: `scale(${interpolate(enter, [0, 1], [0.9, 1])})`,
        }}
      >
        <div style={{ fontFamily: "Georgia, serif", fontSize: 52, fontWeight: 600, color: "#fff", textShadow: "2px 2px 0 rgba(0,0,0,0.8)", marginBottom: 24 }}>
          Install peon-ping
        </div>
        <div style={{ fontFamily: "monospace", fontSize: 24, color: GOLD, backgroundColor: "rgba(255,255,255,0.05)", padding: "14px 28px", borderRadius: 6, border: "1px solid rgba(212,165,32,0.3)" }}>
          github.com/PeonPing/peon-ping
        </div>
        <div style={{ fontFamily: "monospace", fontSize: 18, color: "rgba(255,255,255,0.35)", marginTop: 30 }}>
          Submit your own pack via PR
        </div>
      </div>
    </AbsoluteFill>
  );
};

export const SovietEngineerPreview: React.FC = () => {
  const frame = useCurrentFrame();

  // Compute tab title based on current state
  let tabTitle = "my-project: ready";
  if (frame >= 170 && frame < 530) tabTitle = "my-project: working";
  if (frame >= 330 && frame < 390) tabTitle = "● my-project: needs approval";
  if (frame >= 530 && frame < 620) tabTitle = "● my-project: done";
  if (frame >= 620 && frame < 740) tabTitle = "my-project: working";
  if (frame >= 660) tabTitle = "● my-project: error";

  // Filter terminal lines visible
  const terminalLines = TIMELINE.filter((e) => e.type !== "title" && e.type !== "terminal-start" && e.type !== "outro");

  // Terminal visibility
  const termEnter = frame >= 75;
  const termExit = frame >= 730;
  const termOp = termExit ? interpolate(frame, [730, 740], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }) : termEnter ? interpolate(frame, [75, 85], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }) : 0;

  return (
    <AbsoluteFill style={{ backgroundColor: "#0a0a0f" }}>
      {/* Title card */}
      <Sequence from={0} durationInFrames={76}>
        <TitleCard />
      </Sequence>

      {/* Terminal session */}
      {termEnter && (
        <AbsoluteFill
          style={{
            justifyContent: "center",
            alignItems: "center",
            opacity: termOp,
          }}
        >
          <TerminalChrome tabTitle={tabTitle}>
            {terminalLines.map((event, i) => {
              if (event.type === "line") {
                return (
                  <TermLine key={i} appearFrame={event.frame}>
                    {event.style === "cmd" ? (
                      <TypedText
                        text={event.text!}
                        startFrame={event.frame}
                        color={event.text!.startsWith("$") || event.text!.startsWith(">") ? GREEN : BRIGHT}
                      />
                    ) : event.style === "error" ? (
                      <span style={{ color: RED }}>{event.text}</span>
                    ) : event.style === "cursor" ? (
                      <span>
                        <span style={{ color: GREEN }}>&gt; </span>
                        <Cursor />
                      </span>
                    ) : (
                      <span style={{ color: DIM }}>{event.text}</span>
                    )}
                  </TermLine>
                );
              }
              if (event.type === "sound-line") {
                return (
                  <TermLine key={i} appearFrame={event.frame}>
                    <span style={{ color: GOLD, fontWeight: 500 }}>{event.text}</span>
                    <SoundBadge label={event.label!} />
                  </TermLine>
                );
              }
              return null;
            })}
          </TerminalChrome>
        </AbsoluteFill>
      )}

      {/* Audio sequences */}
      {TIMELINE.filter((e) => e.type === "sound-line" && e.sound).map((event, i) => (
        <Sequence key={`audio-${i}`} from={event.frame} durationInFrames={50}>
          <Audio src={staticFile(`sounds/${event.sound}`)} volume={0.9} />
        </Sequence>
      ))}

      {/* Outro */}
      <Sequence from={740} durationInFrames={100}>
        <OutroCard />
      </Sequence>
    </AbsoluteFill>
  );
};
