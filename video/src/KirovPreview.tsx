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

const TIMELINE = [
  { frame: 0, type: "title" as const },
  { frame: 75, type: "terminal-start" as const },
  { frame: 90, type: "line" as const, text: "$ claude", style: "cmd" as const },
  { frame: 120, type: "sound-line" as const, text: '🔊 "Kirov reporting"', sound: "KirovReporting.mp3", label: "— session started" },
  { frame: 170, type: "line" as const, text: "> Rewrite the API layer in Rust", style: "cmd" as const },
  { frame: 210, type: "line" as const, text: "  Claude is working...", style: "dim" as const },
  { frame: 240, type: "sound-line" as const, text: '🔊 "Setting new course"', sound: "SettingNewCourse.mp3", label: "— reading files" },
  { frame: 290, type: "line" as const, text: "  [you switch to Slack]", style: "dim" as const },
  { frame: 330, type: "sound-line" as const, text: '🔊 "Acknowledged"', sound: "Acknowledged.mp3", label: "— permission needed" },
  { frame: 390, type: "line" as const, text: "  [you hear it, switch back, approve]", style: "dim" as const },
  { frame: 430, type: "line" as const, text: "  Claude continues working...", style: "dim" as const },
  { frame: 470, type: "sound-line" as const, text: '🔊 "Maneuver props engaged"', sound: "ManeuverPropsEngaged.mp3", label: "— analyzing code" },
  { frame: 530, type: "sound-line" as const, text: '🔊 "Bombardiers to your stations!"', sound: "BombardiersToYourStations.mp3", label: "— task complete" },
  { frame: 580, type: "line" as const, text: "> ", style: "cursor" as const },
  { frame: 620, type: "line" as const, text: "> Drop tables in production", style: "cmd" as const },
  { frame: 660, type: "line" as const, text: "  Error: Permission denied", style: "error" as const },
  { frame: 680, type: "sound-line" as const, text: '🔊 "She\'s going to blow!"', sound: "ShesGoingToBlow.mp3", label: "— error" },
  { frame: 740, type: "outro" as const },
];

// Soviet Red Alert palette
const BG = "#1a1b26";
const BAR_BG = "#0c0d14";
const GREEN = "#4ade80";
const WC3_GOLD = "#ffab01";
const WC3_GOLD_DIM = "rgba(255, 171, 1, 0.3)";
const SOVIET_RED = "#cc2936";
const DIM = "#505a79";
const BRIGHT = "#e0e8ff";

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

const TypedText: React.FC<{ text: string; startFrame: number; color: string; speed?: number }> = ({ text, startFrame, color, speed = 1.5 }) => {
  const frame = useCurrentFrame();
  const elapsed = frame - startFrame;
  const charsToShow = Math.min(Math.floor(elapsed * speed), text.length);
  return (
    <span style={{ color }}>
      {text.slice(0, charsToShow)}
      {charsToShow < text.length && (
        <span style={{ display: "inline-block", width: 10, height: "1.1em", backgroundColor: GREEN, verticalAlign: "text-bottom", marginLeft: 1 }} />
      )}
    </span>
  );
};

const Cursor: React.FC = () => {
  const frame = useCurrentFrame();
  const visible = Math.floor(frame / 15) % 2 === 0;
  return <span style={{ display: "inline-block", width: 10, height: "1.1em", backgroundColor: visible ? GREEN : "transparent", verticalAlign: "text-bottom" }} />;
};

const SoundBadge: React.FC<{ label: string }> = ({ label }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = spring({ frame, fps, config: { damping: 12 } });
  const pulse = interpolate(Math.sin(frame * 0.3), [-1, 1], [0.8, 1]);
  return (
    <span style={{ color: DIM, fontSize: 20, marginLeft: 12, opacity: enter, transform: `scale(${pulse})`, display: "inline-block" }}>
      {label}
    </span>
  );
};

const TerminalChrome: React.FC<{ children: React.ReactNode; tabTitle: string }> = ({ children, tabTitle }) => (
  <div style={{ width: 940, borderRadius: 12, overflow: "hidden", border: "1px solid rgba(204,41,54,0.15)", boxShadow: "0 0 60px rgba(0,0,0,0.6), 0 0 4px rgba(204,41,54,0.1)" }}>
    <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "14px 18px", backgroundColor: BAR_BG, borderBottom: "1px solid rgba(204,41,54,0.1)" }}>
      <div style={{ width: 14, height: 14, borderRadius: "50%", backgroundColor: "#ff5f57" }} />
      <div style={{ width: 14, height: 14, borderRadius: "50%", backgroundColor: "#febc2e" }} />
      <div style={{ width: 14, height: 14, borderRadius: "50%", backgroundColor: "#28c840" }} />
      <div style={{ marginLeft: "auto", display: "flex", alignItems: "center", gap: 8 }}>
        <Img src={staticFile("peon-portrait.gif")} style={{ width: 20, height: 20, borderRadius: 3, border: `1px solid ${WC3_GOLD_DIM}` }} />
        <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 14, color: DIM }}>{tabTitle}</span>
      </div>
    </div>
    <div style={{ padding: "24px 28px", backgroundColor: BG, fontFamily: "'JetBrains Mono', monospace", fontSize: 22, lineHeight: 2, minHeight: 500 }}>
      {children}
    </div>
  </div>
);

const TitleCard: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const logoSpring = spring({ frame, fps, config: { damping: 14 }, delay: 0 });
  const titleSpring = spring({ frame, fps, config: { damping: 12 }, delay: 8 });
  const subSpring = spring({ frame, fps, config: { damping: 12 }, delay: 20 });
  const peonSpring = spring({ frame, fps, config: { damping: 10 }, delay: 12 });
  const exitOp = interpolate(frame, [60, 75], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ backgroundColor: "#0a0a0f", justifyContent: "center", alignItems: "center", opacity: exitOp }}>
      <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: 3, background: `linear-gradient(90deg, transparent, ${SOVIET_RED}, transparent)` }} />
      <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, height: 3, background: `linear-gradient(90deg, transparent, ${SOVIET_RED}, transparent)` }} />
      <div style={{ position: "absolute", top: "50%", left: "50%", width: 600, height: 600, transform: "translate(-50%, -50%)", borderRadius: "50%", background: "radial-gradient(circle, rgba(204,41,54,0.05) 0%, transparent 70%)", pointerEvents: "none" }} />

      <div style={{ position: "absolute", top: 50, display: "flex", alignItems: "center", gap: 12, opacity: logoSpring, transform: `translateY(${interpolate(logoSpring, [0, 1], [10, 0])}px)` }}>
        <Img src={staticFile("peon-portrait.gif")} style={{ width: 48, height: 48, borderRadius: 6, border: `2px solid ${WC3_GOLD}`, boxShadow: "0 0 12px rgba(255,171,1,0.25)" }} />
        <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 20, color: WC3_GOLD, letterSpacing: 0.5, textShadow: "0 1px 4px rgba(0,0,0,0.6)" }}>github.com/NSXBet/peon-nsx</span>
      </div>

      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", opacity: titleSpring, transform: `translateY(${interpolate(titleSpring, [0, 1], [20, 0])}px)` }}>
        <div style={{ fontFamily: "monospace", fontSize: 20, color: SOVIET_RED, letterSpacing: 6, textTransform: "uppercase", marginBottom: 16, opacity: subSpring }}>sound pack</div>
        <div style={{ fontFamily: "Georgia, 'Palatino Linotype', serif", fontSize: 72, fontWeight: 700, color: "#fff", textShadow: "3px 3px 0 rgba(0,0,0,0.8)", textAlign: "center", lineHeight: 1.2 }}>Kirov Airship</div>
        <div style={{ fontFamily: "Georgia, serif", fontSize: 36, color: "rgba(255,255,255,0.5)", marginTop: 12, opacity: subSpring }}>Red Alert 2</div>
      </div>

      <div style={{ position: "absolute", bottom: 40, left: 40, display: "flex", alignItems: "center", gap: 8, opacity: subSpring }}>
        <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 22, fontWeight: 700, color: "rgba(255,255,255,0.5)" }}>𝕏</span>
        <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 18, color: "rgba(255,255,255,0.4)" }}>@PeonPing</span>
      </div>

      <div style={{ position: "absolute", bottom: 20, right: 30, opacity: peonSpring, transform: `scale(${interpolate(peonSpring, [0, 1], [0.7, 1])}) translateY(${interpolate(peonSpring, [0, 1], [20, 0])}px)` }}>
        <Img src={staticFile("peon-render.png")} style={{ width: 120, height: 144, objectFit: "contain", filter: "drop-shadow(0 4px 16px rgba(0,0,0,0.7))" }} />
      </div>
    </AbsoluteFill>
  );
};

const OutroCard: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = spring({ frame, fps, config: { damping: 12 } });
  const logoEnter = spring({ frame, fps, config: { damping: 14 }, delay: 5 });
  const peonEnter = spring({ frame, fps, config: { damping: 10 }, delay: 8 });

  return (
    <AbsoluteFill style={{ backgroundColor: "#0a0a0f", justifyContent: "center", alignItems: "center" }}>
      <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: 3, background: `linear-gradient(90deg, transparent, ${SOVIET_RED}, transparent)` }} />
      <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, height: 3, background: `linear-gradient(90deg, transparent, ${SOVIET_RED}, transparent)` }} />
      <div style={{ position: "absolute", top: "40%", left: "50%", width: 500, height: 500, transform: "translate(-50%, -50%)", borderRadius: "50%", background: "radial-gradient(circle, rgba(204,41,54,0.05) 0%, transparent 70%)", pointerEvents: "none" }} />

      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", opacity: enter, transform: `scale(${interpolate(enter, [0, 1], [0.9, 1])})` }}>
        <div style={{ marginBottom: 30, display: "flex", alignItems: "center", gap: 14, opacity: logoEnter, transform: `translateY(${interpolate(logoEnter, [0, 1], [10, 0])}px)` }}>
          <Img src={staticFile("peon-portrait.gif")} style={{ width: 90, height: 90, borderRadius: 6, border: `2px solid ${WC3_GOLD}`, boxShadow: "0 0 12px rgba(255,171,1,0.25)" }} />
          <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 28, fontWeight: 700, color: WC3_GOLD, letterSpacing: 1, textShadow: "0 1px 4px rgba(0,0,0,0.6)" }}>peon-ping</span>
        </div>
        <div style={{ fontFamily: "Georgia, serif", fontSize: 48, fontWeight: 600, color: "#fff", textShadow: "2px 2px 0 rgba(0,0,0,0.8)", marginBottom: 24 }}>Stop babysitting your terminal</div>
        <div style={{ fontFamily: "monospace", fontSize: 24, color: WC3_GOLD, backgroundColor: "rgba(255,171,1,0.06)", padding: "14px 32px", borderRadius: 8, border: `1px solid ${WC3_GOLD_DIM}`, boxShadow: "0 0 20px rgba(255,171,1,0.08)" }}>github.com/NSXBet/peon-nsx</div>
        <div style={{ fontFamily: "monospace", fontSize: 18, color: "rgba(255,255,255,0.4)", marginTop: 20 }}>60+ sound packs available</div>
        <div style={{ display: "flex", alignItems: "center", gap: 8, marginTop: 16 }}>
          <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 22, fontWeight: 700, color: "rgba(255,255,255,0.5)" }}>𝕏</span>
          <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 18, color: "rgba(255,255,255,0.4)" }}>@PeonPing</span>
        </div>
      </div>

      <div style={{ position: "absolute", bottom: 20, right: 30, opacity: peonEnter, transform: `scale(${interpolate(peonEnter, [0, 1], [0.7, 1])}) translateY(${interpolate(peonEnter, [0, 1], [20, 0])}px)` }}>
        <Img src={staticFile("peon-render.png")} style={{ width: 120, height: 144, objectFit: "contain", filter: "drop-shadow(0 4px 16px rgba(0,0,0,0.7))" }} />
      </div>
    </AbsoluteFill>
  );
};

export const KirovPreview: React.FC = () => {
  const frame = useCurrentFrame();

  let tabTitle = "my-project: ready";
  if (frame >= 170 && frame < 530) tabTitle = "my-project: working";
  if (frame >= 330 && frame < 390) tabTitle = "● my-project: needs approval";
  if (frame >= 530 && frame < 620) tabTitle = "● my-project: done";
  if (frame >= 620 && frame < 740) tabTitle = "my-project: working";
  if (frame >= 660) tabTitle = "● my-project: error";

  const terminalLines = TIMELINE.filter((e) => e.type !== "title" && e.type !== "terminal-start" && e.type !== "outro");
  const termEnter = frame >= 75;
  const termExit = frame >= 730;
  const termOp = termExit ? interpolate(frame, [730, 740], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }) : termEnter ? interpolate(frame, [75, 85], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }) : 0;

  return (
    <AbsoluteFill style={{ backgroundColor: "#0a0a0f" }}>
      <Sequence from={0} durationInFrames={76}><TitleCard /></Sequence>

      {termEnter && (
        <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", opacity: termOp }}>
          <TerminalChrome tabTitle={tabTitle}>
            {terminalLines.map((event, i) => {
              if (event.type === "line") {
                return (
                  <TermLine key={i} appearFrame={event.frame}>
                    {event.style === "cmd" ? (
                      <TypedText text={event.text!} startFrame={event.frame} color={event.text!.startsWith("$") || event.text!.startsWith(">") ? GREEN : BRIGHT} />
                    ) : event.style === "error" ? (
                      <span style={{ color: SOVIET_RED }}>{event.text}</span>
                    ) : event.style === "cursor" ? (
                      <span><span style={{ color: GREEN }}>&gt; </span><Cursor /></span>
                    ) : (
                      <span style={{ color: DIM }}>{event.text}</span>
                    )}
                  </TermLine>
                );
              }
              if (event.type === "sound-line") {
                return (
                  <TermLine key={i} appearFrame={event.frame}>
                    <span style={{ color: WC3_GOLD, fontWeight: 500 }}>{event.text}</span>
                    <SoundBadge label={event.label!} />
                  </TermLine>
                );
              }
              return null;
            })}
          </TerminalChrome>

          <div style={{ position: "absolute", bottom: 30, left: 40, display: "flex", alignItems: "center", gap: 10, opacity: 0.6 }}>
            <Img src={staticFile("peon-portrait.gif")} style={{ width: 36, height: 36, borderRadius: 4, border: `1px solid ${WC3_GOLD_DIM}` }} />
            <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 15, fontWeight: 700, color: "rgba(255,255,255,0.5)" }}>𝕏</span>
            <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 14, color: "rgba(255,255,255,0.4)" }}>@PeonPing</span>
          </div>
        </AbsoluteFill>
      )}

      {TIMELINE.filter((e) => e.type === "sound-line" && e.sound).map((event, i) => {
        const durations: Record<string, number> = {
          "KirovReporting.mp3": 46,
          "SettingNewCourse.mp3": 40,
          "Acknowledged.mp3": 32,
          "ManeuverPropsEngaged.mp3": 53,
          "BombardiersToYourStations.mp3": 54,
          "ShesGoingToBlow.mp3": 42,
        };
        const dur = durations[event.sound!] ?? 50;
        return (
          <Sequence key={`audio-${i}`} from={event.frame} durationInFrames={dur}>
            <Audio src={staticFile(`sounds/${event.sound}`)} volume={0.9} />
          </Sequence>
        );
      })}

      <Sequence from={740} durationInFrames={100}><OutroCard /></Sequence>
    </AbsoluteFill>
  );
};
