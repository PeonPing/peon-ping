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
  { frame: 90, type: "terminal-start" as const },
  { frame: 105, type: "line" as const, text: "$ npx ts-node ton-agent.ts", style: "cmd" as const },
  { frame: 145, type: "sound-line" as const, text: '🔊 "Ready to work!"', sound: "PeonReady1.wav", label: "— agent started" },
  { frame: 200, type: "line" as const, text: "  Wallet connected: UQ...7xK", style: "dim" as const },
  { frame: 230, type: "line" as const, text: "  Submitting swap: 50 TON → USDT", style: "dim" as const },
  { frame: 260, type: "sound-line" as const, text: '🔊 "Yes, me lord"', sound: "PeonYes1.wav", label: "— tx submitted" },
  { frame: 310, type: "line" as const, text: "  [you switch to VS Code]", style: "dim" as const },
  { frame: 350, type: "sound-line" as const, text: '🔊 "Something need doing?"', sound: "PeonWhat1.wav", label: "— approval needed" },
  { frame: 400, type: "line" as const, text: "  [you hear it, switch back, approve]", style: "dim" as const },
  { frame: 440, type: "line" as const, text: "  High-value tx approved. Confirming...", style: "dim" as const },
  { frame: 480, type: "sound-line" as const, text: '🔊 "Work complete!"', sound: "PeonYes2.wav", label: "— tx confirmed" },
  { frame: 540, type: "line" as const, text: "  Swap confirmed: +98.2 USDT", style: "success" as const },
  { frame: 570, type: "line" as const, text: "  Next: Staking 98 USDT in pool...", style: "dim" as const },
  { frame: 600, type: "line" as const, text: "  Error: Contract reverted (gas)", style: "error" as const },
  { frame: 620, type: "sound-line" as const, text: '🔊 *peon death sound*', sound: "PeonDeath.wav", label: "— tx failed" },
  { frame: 680, type: "line" as const, text: "  Retrying with higher gas...", style: "dim" as const },
  { frame: 710, type: "sound-line" as const, text: '🔊 "Right-o"', sound: "PeonYes1.wav", label: "— tx confirmed" },
  { frame: 760, type: "line" as const, text: "  Staked 98 USDT. Agent idle.", style: "success" as const },
  { frame: 800, type: "outro" as const },
];

// TON-inspired palette — blue/teal
const BG = "#0d1117";
const BAR_BG = "#080b10";
const GREEN = "#4ade80";
const TON_BLUE = "#0098EA";
const TON_BLUE_DIM = "rgba(0, 152, 234, 0.3)";
const WC3_GOLD = "#ffab01";
const WC3_GOLD_DIM = "rgba(255, 171, 1, 0.3)";
const DIM = "#505a79";
const BRIGHT = "#e0e8ff";
const RED = "#f87171";

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
  <div style={{ width: 940, borderRadius: 12, overflow: "hidden", border: "1px solid rgba(0,152,234,0.15)", boxShadow: "0 0 60px rgba(0,0,0,0.6), 0 0 4px rgba(0,152,234,0.1)" }}>
    <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "14px 18px", backgroundColor: BAR_BG, borderBottom: "1px solid rgba(0,152,234,0.1)" }}>
      <div style={{ width: 14, height: 14, borderRadius: "50%", backgroundColor: "#ff5f57" }} />
      <div style={{ width: 14, height: 14, borderRadius: "50%", backgroundColor: "#febc2e" }} />
      <div style={{ width: 14, height: 14, borderRadius: "50%", backgroundColor: "#28c840" }} />
      <div style={{ marginLeft: "auto", display: "flex", alignItems: "center", gap: 8 }}>
        <Img src={staticFile("peon-portrait.gif")} style={{ width: 20, height: 20, borderRadius: 3, border: `1px solid ${WC3_GOLD_DIM}` }} />
        <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 14, color: DIM }}>{tabTitle}</span>
      </div>
    </div>
    <div style={{ padding: "24px 28px", backgroundColor: BG, fontFamily: "'JetBrains Mono', monospace", fontSize: 21, lineHeight: 1.9, minHeight: 500 }}>
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
  const statsSpring = spring({ frame, fps, config: { damping: 12 }, delay: 30 });
  const exitOp = interpolate(frame, [75, 90], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ backgroundColor: "#060810", justifyContent: "center", alignItems: "center", opacity: exitOp }}>
      <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: 3, background: `linear-gradient(90deg, transparent, ${TON_BLUE}, transparent)` }} />
      <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, height: 3, background: `linear-gradient(90deg, transparent, ${TON_BLUE}, transparent)` }} />
      <div style={{ position: "absolute", top: "50%", left: "50%", width: 600, height: 600, transform: "translate(-50%, -50%)", borderRadius: "50%", background: "radial-gradient(circle, rgba(0,152,234,0.06) 0%, transparent 70%)", pointerEvents: "none" }} />

      <div style={{ position: "absolute", top: 50, display: "flex", alignItems: "center", gap: 12, opacity: logoSpring, transform: `translateY(${interpolate(logoSpring, [0, 1], [10, 0])}px)` }}>
        <Img src={staticFile("peon-portrait.gif")} style={{ width: 48, height: 48, borderRadius: 6, border: `2px solid ${WC3_GOLD}`, boxShadow: "0 0 12px rgba(255,171,1,0.25)" }} />
        <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 20, color: WC3_GOLD, letterSpacing: 0.5, textShadow: "0 1px 4px rgba(0,0,0,0.6)" }}>CESP for TON Agents</span>
      </div>

      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", opacity: titleSpring, transform: `translateY(${interpolate(titleSpring, [0, 1], [20, 0])}px)` }}>
        <div style={{ fontFamily: "monospace", fontSize: 20, color: TON_BLUE, letterSpacing: 6, textTransform: "uppercase", marginBottom: 16, opacity: subSpring }}>audio observability</div>
        <div style={{ fontFamily: "Georgia, 'Palatino Linotype', serif", fontSize: 62, fontWeight: 700, color: "#fff", textShadow: "3px 3px 0 rgba(0,0,0,0.8)", textAlign: "center", lineHeight: 1.2 }}>Hear Your TON Agent Work</div>
        <div style={{ fontFamily: "Georgia, serif", fontSize: 32, color: "rgba(255,255,255,0.45)", marginTop: 14, opacity: subSpring }}>100+ sound packs via CESP</div>
      </div>

      <div style={{ position: "absolute", bottom: 60, display: "flex", gap: 32, opacity: statsSpring, transform: `translateY(${interpolate(statsSpring, [0, 1], [10, 0])}px)` }}>
        {[
          { num: "2.7k+", label: "GitHub stars" },
          { num: "100+", label: "sound packs" },
          { num: "11", label: "IDEs" },
        ].map(({ num, label }) => (
          <div key={label} style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
            <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 28, fontWeight: 700, color: WC3_GOLD }}>{num}</span>
            <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 14, color: "rgba(255,255,255,0.4)", marginTop: 4 }}>{label}</span>
          </div>
        ))}
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
  const codeEnter = spring({ frame, fps, config: { damping: 12 }, delay: 15 });

  return (
    <AbsoluteFill style={{ backgroundColor: "#060810", justifyContent: "center", alignItems: "center" }}>
      <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: 3, background: `linear-gradient(90deg, transparent, ${TON_BLUE}, transparent)` }} />
      <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, height: 3, background: `linear-gradient(90deg, transparent, ${TON_BLUE}, transparent)` }} />
      <div style={{ position: "absolute", top: "40%", left: "50%", width: 500, height: 500, transform: "translate(-50%, -50%)", borderRadius: "50%", background: "radial-gradient(circle, rgba(0,152,234,0.05) 0%, transparent 70%)", pointerEvents: "none" }} />

      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", opacity: enter, transform: `scale(${interpolate(enter, [0, 1], [0.9, 1])})` }}>
        <div style={{ marginBottom: 30, display: "flex", alignItems: "center", gap: 14, opacity: logoEnter, transform: `translateY(${interpolate(logoEnter, [0, 1], [10, 0])}px)` }}>
          <Img src={staticFile("peon-portrait.gif")} style={{ width: 90, height: 90, borderRadius: 6, border: `2px solid ${WC3_GOLD}`, boxShadow: "0 0 12px rgba(255,171,1,0.25)" }} />
          <div style={{ display: "flex", flexDirection: "column" }}>
            <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 28, fontWeight: 700, color: WC3_GOLD, letterSpacing: 1, textShadow: "0 1px 4px rgba(0,0,0,0.6)" }}>cesp-ton</span>
            <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 16, color: TON_BLUE }}>Audio for TON Agents</span>
          </div>
        </div>
        <div style={{ fontFamily: "Georgia, serif", fontSize: 44, fontWeight: 600, color: "#fff", textShadow: "2px 2px 0 rgba(0,0,0,0.8)", marginBottom: 24, textAlign: "center", lineHeight: 1.3 }}>Stop watching logs.<br/>Start hearing your agent.</div>

        <div style={{ opacity: codeEnter, fontFamily: "'JetBrains Mono', monospace", fontSize: 18, color: GREEN, backgroundColor: "rgba(74,222,128,0.06)", padding: "14px 28px", borderRadius: 8, border: "1px solid rgba(74,222,128,0.15)", marginBottom: 16, textAlign: "center", lineHeight: 1.6 }}>
          cesp.emit('task.complete') // 5 lines to integrate
        </div>

        <div style={{ fontFamily: "monospace", fontSize: 22, color: TON_BLUE, backgroundColor: "rgba(0,152,234,0.06)", padding: "14px 32px", borderRadius: 8, border: `1px solid ${TON_BLUE_DIM}`, boxShadow: "0 0 20px rgba(0,152,234,0.08)" }}>github.com/PeonPing/cesp-ton</div>
        <div style={{ fontFamily: "monospace", fontSize: 18, color: "rgba(255,255,255,0.4)", marginTop: 20 }}>100+ sound packs | 2.7k+ stars | Open standard</div>
      </div>

      <div style={{ position: "absolute", bottom: 20, right: 30, opacity: peonEnter, transform: `scale(${interpolate(peonEnter, [0, 1], [0.7, 1])}) translateY(${interpolate(peonEnter, [0, 1], [20, 0])}px)` }}>
        <Img src={staticFile("peon-render.png")} style={{ width: 120, height: 144, objectFit: "contain", filter: "drop-shadow(0 4px 16px rgba(0,0,0,0.7))" }} />
      </div>
    </AbsoluteFill>
  );
};

export const CespTonDemo: React.FC = () => {
  const frame = useCurrentFrame();

  let tabTitle = "ton-agent: starting";
  if (frame >= 145 && frame < 350) tabTitle = "ton-agent: running";
  if (frame >= 350 && frame < 440) tabTitle = "● ton-agent: needs approval";
  if (frame >= 440 && frame < 600) tabTitle = "ton-agent: running";
  if (frame >= 480 && frame < 570) tabTitle = "● ton-agent: tx confirmed";
  if (frame >= 600 && frame < 680) tabTitle = "● ton-agent: error";
  if (frame >= 680 && frame < 760) tabTitle = "ton-agent: retrying";
  if (frame >= 760) tabTitle = "ton-agent: idle";

  const terminalLines = TIMELINE.filter((e) => e.type !== "title" && e.type !== "terminal-start" && e.type !== "outro");
  const termEnter = frame >= 90;
  const termExit = frame >= 790;
  const termOp = termExit ? interpolate(frame, [790, 800], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }) : termEnter ? interpolate(frame, [90, 100], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }) : 0;

  return (
    <AbsoluteFill style={{ backgroundColor: "#060810" }}>
      <Sequence from={0} durationInFrames={91}><TitleCard /></Sequence>

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
                      <span style={{ color: RED }}>{event.text}</span>
                    ) : event.style === "success" ? (
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
            <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 15, color: TON_BLUE }}>CESP for TON</span>
            <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 14, color: "rgba(255,255,255,0.35)" }}>| 100+ sound packs</span>
          </div>
        </AbsoluteFill>
      )}

      {TIMELINE.filter((e) => e.type === "sound-line" && e.sound).map((event, i) => {
        const durations: Record<string, number> = {
          "PeonReady1.wav": 40,
          "PeonYes1.wav": 30,
          "PeonYes2.wav": 30,
          "PeonWhat1.wav": 35,
          "PeonAngry1.wav": 35,
          "PeonDeath.wav": 45,
        };
        const dur = durations[event.sound!] ?? 40;
        return (
          <Sequence key={`audio-${i}`} from={event.frame} durationInFrames={dur}>
            <Audio src={staticFile(`sounds/${event.sound}`)} volume={0.9} />
          </Sequence>
        );
      })}

      <Sequence from={800} durationInFrames={120}><OutroCard /></Sequence>
    </AbsoluteFill>
  );
};
