#!/usr/bin/env osascript -l JavaScript
// Jarvis HUD overlay notification for macOS
// Usage: osascript -l JavaScript mac-overlay.js <message> <color> <icon_path> <slot> <dismiss_seconds> [bundle_id] [ide_pid]

ObjC.import('Cocoa');
ObjC.import('QuartzCore');

function run(argv) {
  var message  = argv[0] || 'peon-ping';
  var color    = argv[1] || 'blue';
  var iconPath = argv[2] || '';   // kept for compat with notify.sh (unused)
  var slot     = parseInt(argv[3], 10) || 0;
  var dismiss  = parseFloat(argv[4]) || 5;
  var bundleId   = argv[5] || '';
  var idePid     = parseInt(argv[6], 10) || 0;
  var sessionTty = argv[7] || '';  // TTY of the Claude session (for window focus)

  var accentR = 0.0, accentG = 0.75, accentB = 1.0;
  switch (color) {
    case 'red':    accentR = 1.0;  accentG = 0.25; accentB = 0.15; break;
    case 'yellow': accentR = 1.0;  accentG = 0.8;  accentB = 0.0;  break;
    case 'green':  accentR = 0.2;  accentG = 0.9;  accentB = 0.4;  break;
    case 'blue':   accentR = 0.0;  accentG = 0.75; accentB = 1.0;  break;
  }

  var typeText = 'INPUT REQUIRED';
  if (color === 'red') typeText = 'LIMIT REACHED';
  if (color === 'yellow') typeText = 'LIMIT REACHED';
  if (color === 'green') typeText = 'TASK COMPLETE';

  var circleSize = 300;
  var padding = 20;
  var winSize = circleSize + padding * 2;
  var cx = circleSize / 2;
  var cy = circleSize / 2;
  var PI = Math.PI, TAU = 2 * PI;

  $.NSApplication.sharedApplication;
  $.NSApp.setActivationPolicy($.NSApplicationActivationPolicyAccessory);

  var mouseLocation = $.NSEvent.mouseLocation;
  var screens = $.NSScreen.screens;
  var focusedScreen = screens.objectAtIndex(0);
  for (var s = 0; s < screens.count; s++) {
    var scr = screens.objectAtIndex(s);
    var sf = scr.frame;
    if (mouseLocation.x >= sf.origin.x && mouseLocation.x <= sf.origin.x + sf.size.width &&
        mouseLocation.y >= sf.origin.y && mouseLocation.y <= sf.origin.y + sf.size.height) {
      focusedScreen = scr; break;
    }
  }

  var vf = focusedScreen.visibleFrame;
  var x = vf.origin.x + vf.size.width - winSize - 10;
  var y = vf.origin.y + vf.size.height - winSize - (10 + slot * (winSize + 5));

  var win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(
    $.NSMakeRect(x, y, winSize, winSize),
    $.NSWindowStyleMaskBorderless, $.NSBackingStoreBuffered, false
  );
  win.setBackgroundColor($.NSColor.clearColor);
  win.setOpaque(false); win.setHasShadow(false); win.setAlphaValue(0.0);
  win.setLevel($.NSStatusWindowLevel);
  win.setCollectionBehavior($.NSWindowCollectionBehaviorCanJoinAllSpaces | $.NSWindowCollectionBehaviorStationary);
  win.contentView.wantsLayer = true;

  var hud = $.NSView.alloc.initWithFrame($.NSMakeRect(padding, padding, circleSize, circleSize));
  hud.setWantsLayer(true);

  // ── Color palette ──
  function cg(r,g,b,a) { return $.NSColor.colorWithSRGBRedGreenBlueAlpha(r,g,b,a).CGColor; }

  var accentCG   = cg(accentR, accentG, accentB, 1.0);
  var brightCG   = cg(accentR, accentG, accentB, 0.75);
  var midCG      = cg(accentR, accentG, accentB, 0.5);
  var dimCG      = cg(accentR, accentG, accentB, 0.2);
  var faintCG    = cg(accentR, accentG, accentB, 0.08);
  // Light blue / white-ish accents (like the image highlights)
  var lightCG    = cg(0.55, 0.88, 1.0, 0.9);
  var lightDimCG = cg(0.55, 0.88, 1.0, 0.3);
  var lightFaintCG = cg(0.55, 0.88, 1.0, 0.12);
  // Gold/yellow accents
  var goldCG     = cg(0.85, 0.72, 0.15, 0.8);
  var goldDimCG  = cg(0.85, 0.72, 0.15, 0.3);
  var goldFaintCG = cg(0.85, 0.72, 0.15, 0.12);
  // Background
  var darkBgCG   = cg(0.03, 0.04, 0.08, 0.92);

  // ── Helpers ──
  function arc(r,s,e) { var p=$.CGPathCreateMutable(); $.CGPathAddArc(p,null,cx,cy,r,s,e,false); return p; }
  function dot(r,angle,radius) {
    var p=$.CGPathCreateMutable();
    $.CGPathAddArc(p,null,cx+Math.cos(angle)*r,cy+Math.sin(angle)*r,radius,0,TAU,false);
    return p;
  }
  function addArc(r,s,e,w,c) {
    var l=$.CAShapeLayer.layer; l.setPath(arc(r,s,e)); l.setFillColor(null);
    l.setStrokeColor(c); l.setLineWidth(w); hud.layer.addSublayer(l); return l;
  }
  function addDot(r,angle,radius,c) {
    var l=$.CAShapeLayer.layer; l.setPath(dot(r,angle,radius));
    l.setFillColor(c); l.setStrokeColor(null); hud.layer.addSublayer(l); return l;
  }

  // ── Futuristic background ──
  // Base fill — deep blue-black
  var bg=$.CAShapeLayer.layer; bg.setPath(arc(148,0,TAU));
  bg.setFillColor(cg(0.03, 0.05, 0.12, 0.93)); bg.setStrokeColor(null);
  hud.layer.addSublayer(bg);

  // Gradient simulation — concentric zones getting darker toward center
  var bgZones = [
    {r:140, c:cg(0.04, 0.06, 0.14, 0.25)},
    {r:120, c:cg(0.03, 0.05, 0.11, 0.30)},
    {r:100, c:cg(0.02, 0.04, 0.09, 0.35)},
    {r:70,  c:cg(0.01, 0.02, 0.06, 0.40)},
  ];
  for (var bz=0; bz<bgZones.length; bz++) {
    var zl=$.CAShapeLayer.layer; zl.setPath(arc(bgZones[bz].r,0,TAU));
    zl.setFillColor(bgZones[bz].c); zl.setStrokeColor(null);
    hud.layer.addSublayer(zl);
  }

  // Subtle edge glow — lighter at the very edge
  var edgeGlow=$.CAShapeLayer.layer; edgeGlow.setPath(arc(146,0,TAU));
  edgeGlow.setFillColor(null); edgeGlow.setStrokeColor(cg(0.1, 0.15, 0.3, 0.15));
  edgeGlow.setLineWidth(4); hud.layer.addSublayer(edgeGlow);

  // Fine structural concentric rings — very faint
  var bgRings = [138, 125, 115, 105, 85, 73, 65];
  for (var br=0; br<bgRings.length; br++) {
    var rl=$.CAShapeLayer.layer; rl.setPath(arc(bgRings[br],0,TAU));
    rl.setFillColor(null); rl.setStrokeColor(cg(0.12, 0.18, 0.35, 0.08));
    rl.setLineWidth(0.3); hud.layer.addSublayer(rl);
  }

  // Radial lines — compass-style, from center outward (24 lines, very faint)
  for (var rl=0; rl<24; rl++) {
    var rAngle = (rl/24)*TAU;
    var rLen = (rl%6===0) ? 148 : (rl%3===0) ? 130 : 115;
    var rStart = (rl%6===0) ? 20 : 45;
    var rOp = (rl%6===0) ? 0.08 : (rl%3===0) ? 0.05 : 0.03;
    var rW = (rl%6===0) ? 0.5 : 0.3;
    var rLine=$.CAShapeLayer.layer, rP=$.CGPathCreateMutable();
    $.CGPathMoveToPoint(rP,null,cx+Math.cos(rAngle)*rStart,cy+Math.sin(rAngle)*rStart);
    $.CGPathAddLineToPoint(rP,null,cx+Math.cos(rAngle)*rLen,cy+Math.sin(rAngle)*rLen);
    rLine.setPath(rP); rLine.setStrokeColor(cg(0.15, 0.25, 0.5, rOp));
    rLine.setLineWidth(rW); hud.layer.addSublayer(rLine);
  }

  // Dashed concentric circles — futuristic scanner lines
  var dashRing1=$.CAShapeLayer.layer; dashRing1.setPath(arc(130,0,TAU));
  dashRing1.setFillColor(null); dashRing1.setStrokeColor(cg(0.1, 0.2, 0.4, 0.06));
  dashRing1.setLineWidth(0.5); dashRing1.setLineDashPattern($([2, 8]));
  hud.layer.addSublayer(dashRing1);

  var dashRing2=$.CAShapeLayer.layer; dashRing2.setPath(arc(100,0,TAU));
  dashRing2.setFillColor(null); dashRing2.setStrokeColor(cg(0.1, 0.2, 0.4, 0.05));
  dashRing2.setLineWidth(0.4); dashRing2.setLineDashPattern($([3, 12]));
  hud.layer.addSublayer(dashRing2);

  var dashRing3=$.CAShapeLayer.layer; dashRing3.setPath(arc(82,0,TAU));
  dashRing3.setFillColor(null); dashRing3.setStrokeColor(cg(0.08, 0.15, 0.35, 0.05));
  dashRing3.setLineWidth(0.3); dashRing3.setLineDashPattern($([1, 6]));
  hud.layer.addSublayer(dashRing3);

  // ══════════════════════════════════════════════
  // LAYER 1: Outermost zone (r=144-148)
  // ══════════════════════════════════════════════
  addArc(147, 0, TAU, 0.5, dimCG);  // thin outer ring

  // ── Randomization (unique each launch) ──
  var rng = Math.random;
  // Random initial angle offsets per group
  var offA = rng()*TAU, offB = rng()*TAU, offC = rng()*TAU, offD = rng()*TAU, offE = rng()*TAU;
  // Random speed multipliers (±35% variation around base speed)
  var spdA = 0.35*(0.65+rng()*0.7), spdB = 0.5*(0.65+rng()*0.7), spdC = 0.7*(0.65+rng()*0.7);
  var spdD = 1.2*(0.65+rng()*0.7), spdE = 1.8*(0.65+rng()*0.7);
  // Sine wobble: each group oscillates speed slightly (frequency + amplitude)
  var wobA={f:0.3+rng()*0.5, a:0.2+rng()*0.4}, wobB={f:0.4+rng()*0.6, a:0.15+rng()*0.35};
  var wobC={f:0.2+rng()*0.4, a:0.25+rng()*0.4}, wobD={f:0.5+rng()*0.7, a:0.2+rng()*0.3};
  var wobE={f:0.3+rng()*0.6, a:0.3+rng()*0.5};

  // Helper: generate randomized arc defs from a template
  function randArcs(base) {
    var out = [];
    for (var i=0; i<base.length; i++) {
      var b = base[i];
      out.push({
        s: b.s + (rng()-0.5)*0.6,        // ±0.3 rad jitter on start angle
        len: b.len * (0.75+rng()*0.5),    // ±25% length variation
        r: b.r + (rng()-0.5)*2,           // ±1px radius jitter
        w: b.w, c: b.c
      });
    }
    return out;
  }

  // Rotating outer arcs (slow CW) — randomized
  var rotA = randArcs([
    {s:0, len:0.9, r:145, w:1.5, c:dimCG},
    {s:1.4, len:1.2, r:145, w:1.2, c:lightDimCG},
    {s:3.0, len:0.8, r:145, w:1.0, c:faintCG},
    {s:4.2, len:1.4, r:145, w:1.5, c:dimCG},
    {s:5.9, len:0.6, r:145, w:1.0, c:lightDimCG},
  ]);
  var rotAL = [];
  for (var i=0;i<rotA.length;i++) {
    var l=$.CAShapeLayer.layer; l.setFillColor(null); l.setStrokeColor(rotA[i].c); l.setLineWidth(rotA[i].w);
    hud.layer.addSublayer(l); rotAL.push(l);
  }

  // Rotating outer arcs layer 2 (slow CCW) — randomized
  var rotB = randArcs([
    {s:0.3, len:0.7, r:142, w:0.8, c:faintCG},
    {s:1.8, len:1.0, r:142, w:1.0, c:dimCG},
    {s:3.5, len:0.6, r:142, w:0.7, c:lightFaintCG},
    {s:4.6, len:1.1, r:142, w:0.8, c:faintCG},
  ]);
  var rotBL = [];
  for (var i=0;i<rotB.length;i++) {
    var l=$.CAShapeLayer.layer; l.setFillColor(null); l.setStrokeColor(rotB[i].c); l.setLineWidth(rotB[i].w);
    hud.layer.addSublayer(l); rotBL.push(l);
  }

  // Gold accent dots on outer ring
  addDot(144, 0.3, 1.5, goldCG);
  addDot(144, 2.8, 1.0, goldDimCG);
  addDot(144, 5.1, 1.5, goldCG);

  // ══════════════════════════════════════════════
  // LAYER 2: Main ring zone (r=128-136)
  // ══════════════════════════════════════════════
  addArc(134, 0, TAU, 1.5, midCG);  // main ring

  // Rotating arcs (medium CW) — randomized
  var rotC = randArcs([
    {s:0, len:1.5, r:136, w:0.8, c:dimCG},
    {s:2.0, len:1.0, r:136, w:0.6, c:lightFaintCG},
    {s:3.8, len:1.3, r:136, w:0.8, c:dimCG},
    {s:5.5, len:0.7, r:136, w:0.6, c:faintCG},
  ]);
  var rotCL = [];
  for (var i=0;i<rotC.length;i++) {
    var l=$.CAShapeLayer.layer; l.setFillColor(null); l.setStrokeColor(rotC[i].c); l.setLineWidth(rotC[i].w);
    hud.layer.addSublayer(l); rotCL.push(l);
  }

  // 120 graduation ticks (very dense like the image)
  for (var t=0; t<120; t++) {
    var ang = (t/120)*TAU - PI/2;
    var r1=132, r2=128, tC=faintCG, tW=0.4;
    if (t%30===0)      { r2=118; tC=lightCG;  tW=2.5; }  // 4 major (light blue)
    else if (t%15===0) { r2=120; tC=brightCG; tW=1.5; }  // 4 secondary
    else if (t%10===0) { r2=122; tC=midCG;    tW=1.2; }  // medium
    else if (t%5===0)  { r2=124; tC=dimCG;    tW=0.8; }  // minor
    else if (t%2===0)  { r2=126; tC=dimCG;    tW=0.4; }
    var tk=$.CAShapeLayer.layer, tp=$.CGPathCreateMutable();
    $.CGPathMoveToPoint(tp,null,cx+Math.cos(ang)*r2,cy+Math.sin(ang)*r2);
    $.CGPathAddLineToPoint(tp,null,cx+Math.cos(ang)*r1,cy+Math.sin(ang)*r1);
    tk.setPath(tp); tk.setStrokeColor(tC); tk.setLineWidth(tW);
    hud.layer.addSublayer(tk);
  }

  // Gold tick accents (every 40 ticks)
  for (var gt=0; gt<3; gt++) {
    var gAng = (gt/3)*TAU + 0.5;
    var gTk=$.CAShapeLayer.layer, gTp=$.CGPathCreateMutable();
    $.CGPathMoveToPoint(gTp,null,cx+Math.cos(gAng)*124,cy+Math.sin(gAng)*124);
    $.CGPathAddLineToPoint(gTp,null,cx+Math.cos(gAng)*132,cy+Math.sin(gAng)*132);
    gTk.setPath(gTp); gTk.setStrokeColor(goldCG); gTk.setLineWidth(1.5);
    hud.layer.addSublayer(gTk);
  }

  // ══════════════════════════════════════════════
  // LAYER 3: Progress ring (r=110) — continuous light band + dark ticks overlay
  // ══════════════════════════════════════════════

  // Base: wide, lighter continuous band
  var progressBase = $.CAShapeLayer.layer, pbP = $.CGPathCreateMutable();
  $.CGPathAddArc(pbP,null,cx,cy,110,-PI/2,-PI/2-TAU,true);
  progressBase.setPath(pbP); progressBase.setFillColor(null);
  progressBase.setStrokeColor(cg(accentR, accentG, accentB, 0.35));
  progressBase.setLineWidth(10.0); progressBase.setLineCap('butt');
  progressBase.setStrokeStart(0); progressBase.setStrokeEnd(0.0);
  hud.layer.addSublayer(progressBase);

  // Overlay: segmented dark ticks inside the light band
  var progressTicks = $.CAShapeLayer.layer, ptP = $.CGPathCreateMutable();
  $.CGPathAddArc(ptP,null,cx,cy,110,-PI/2,-PI/2-TAU,true);
  progressTicks.setPath(ptP); progressTicks.setFillColor(null);
  progressTicks.setStrokeColor(accentCG);
  progressTicks.setLineWidth(10.0); progressTicks.setLineCap('butt');
  progressTicks.setLineDashPattern($([3, 6]));  // thin bright bars inside
  progressTicks.setStrokeStart(0); progressTicks.setStrokeEnd(0.0);
  hud.layer.addSublayer(progressTicks);

  // Glow behind progress
  var progressGlow = $.CAShapeLayer.layer, pgP = $.CGPathCreateMutable();
  $.CGPathAddArc(pgP,null,cx,cy,110,-PI/2,-PI/2-TAU,true);
  progressGlow.setPath(pgP); progressGlow.setFillColor(null);
  progressGlow.setStrokeColor(accentCG);
  progressGlow.setLineWidth(16.0); progressGlow.setLineCap('butt');
  progressGlow.setStrokeStart(0); progressGlow.setStrokeEnd(0.0); progressGlow.setOpacity(0.15);
  hud.layer.insertSublayerBelow(progressGlow, progressBase);

  // Static track ring (dim, shows where progress will fill)
  addArc(110, 0, TAU, 1.0, faintCG);

  // ══════════════════════════════════════════════
  // LAYER 4: Inner detail zone (r=88-96)
  // ══════════════════════════════════════════════
  addArc(96, 0, TAU, 1.0, dimCG);  // inner ring

  // Light blue accent ring
  addArc(94, 0, TAU, 0.3, lightFaintCG);

  // 60 fine inner ticks
  for (var it=0; it<60; it++) {
    var iA=(it/60)*TAU, ir1=95, ir2=91, itC=faintCG, itW=0.4;
    if (it%15===0) { ir2=86; itC=lightDimCG; itW=1.0; }
    else if (it%5===0) { ir2=88; itC=dimCG; itW=0.6; }
    var iTk=$.CAShapeLayer.layer, itp=$.CGPathCreateMutable();
    $.CGPathMoveToPoint(itp,null,cx+Math.cos(iA)*ir2,cy+Math.sin(iA)*ir2);
    $.CGPathAddLineToPoint(itp,null,cx+Math.cos(iA)*ir1,cy+Math.sin(iA)*ir1);
    iTk.setPath(itp); iTk.setStrokeColor(itC); iTk.setLineWidth(itW);
    hud.layer.addSublayer(iTk);
  }

  // Gold dots on inner ring
  addDot(93, 1.2, 1.2, goldCG);
  addDot(93, 4.0, 1.0, goldDimCG);

  // Rotating inner arcs (fast CW) — randomized
  var rotD = randArcs([
    {s:0, len:0.8, r:88, w:0.7, c:dimCG},
    {s:1.5, len:1.0, r:88, w:0.5, c:lightFaintCG},
    {s:3.2, len:0.9, r:88, w:0.7, c:dimCG},
    {s:4.8, len:0.7, r:88, w:0.5, c:faintCG},
  ]);
  var rotDL = [];
  for (var i=0;i<rotD.length;i++) {
    var l=$.CAShapeLayer.layer; l.setFillColor(null); l.setStrokeColor(rotD[i].c); l.setLineWidth(rotD[i].w);
    hud.layer.addSublayer(l); rotDL.push(l);
  }

  // ══════════════════════════════════════════════
  // LAYER 5: Innermost zone (r=72-80)
  // ══════════════════════════════════════════════
  addArc(80, 0, TAU, 0.5, faintCG);
  addArc(76, 0, TAU, 0.3, lightFaintCG);

  // Rotating innermost arcs (fastest CCW) — randomized
  var rotE = randArcs([
    {s:0.2, len:0.6, r:78, w:0.5, c:faintCG},
    {s:1.8, len:0.9, r:78, w:0.4, c:lightFaintCG},
    {s:3.5, len:0.7, r:78, w:0.5, c:faintCG},
    {s:5.0, len:0.8, r:78, w:0.4, c:goldFaintCG},
  ]);
  var rotEL = [];
  for (var i=0;i<rotE.length;i++) {
    var l=$.CAShapeLayer.layer; l.setFillColor(null); l.setStrokeColor(rotE[i].c); l.setLineWidth(rotE[i].w);
    hud.layer.addSublayer(l); rotEL.push(l);
  }

  // Small gold accent dots inner
  addDot(74, 0.8, 0.8, goldDimCG);
  addDot(74, 3.5, 0.8, goldDimCG);

  // ── Glow ──
  hud.layer.shadowColor = accentCG;
  hud.layer.shadowRadius = 30;
  hud.layer.shadowOpacity = 0.5;
  hud.layer.shadowOffset = $.CGSizeMake(0, 0);

  win.contentView.addSubview(hud);

  // ══════════════════════════════════════════════
  // TEXT
  // ══════════════════════════════════════════════
  var wcx = padding + cx, wcy = padding + cy;

  var textShadow = $.NSShadow.alloc.init;
  textShadow.setShadowOffset($.NSMakeSize(0, -1));
  textShadow.setShadowBlurRadius(4);
  textShadow.setShadowColor($.NSColor.colorWithSRGBRedGreenBlueAlpha(0, 0, 0, 1.0));

  function makeCentered(text, yPos, fontSize, fontName, r, g, b, alpha) {
    var font = $.NSFont.fontWithNameSize(fontName, fontSize);
    if (!font || font.isNil()) font = $.NSFont.boldSystemFontOfSize(fontSize);
    var label = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0, 0, 400, 40));
    label.setStringValue($(text)); label.setBezeled(false); label.setDrawsBackground(false);
    label.setEditable(false); label.setSelectable(false);
    label.setTextColor($.NSColor.colorWithSRGBRedGreenBlueAlpha(r, g, b, alpha));
    label.setFont(font); label.setShadow(textShadow); label.sizeToFit;
    var w=label.frame.size.width, h=label.frame.size.height;
    label.setFrame($.NSMakeRect(wcx - w/2, yPos, w, h));
    return label;
  }

  win.contentView.addSubview(makeCentered('J.A.R.V.I.S', wcy+16, 24, 'AvenirNext-Bold', accentR, accentG, accentB, 1.0));
  win.contentView.addSubview(makeCentered(typeText, wcy-2, 9, 'AvenirNext-Medium', accentR, accentG, accentB, 0.6));

  // Message — split into individually centered lines that fit within maxMW
  var msgFontName = 'AvenirNext-Regular', msgFontSize = 11;
  var msgFont = $.NSFont.fontWithNameSize(msgFontName, msgFontSize);
  if (!msgFont || msgFont.isNil()) msgFont = $.NSFont.systemFontOfSize(msgFontSize);
  var maxMW = 180;
  var tmp = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0,0,400,20));
  tmp.setFont(msgFont); tmp.setBezeled(false);

  // Word-wrap into lines that fit
  var words = message.split(' '), lines = [], curLine = '';
  for (var wi=0; wi<words.length; wi++) {
    var test = curLine ? curLine + ' ' + words[wi] : words[wi];
    tmp.setStringValue($(test)); tmp.sizeToFit;
    if (tmp.frame.size.width > maxMW && curLine) {
      lines.push(curLine); curLine = words[wi];
    } else { curLine = test; }
  }
  if (curLine) lines.push(curLine);

  // Position block: center vertically in the lower portion of the circle
  var lineH = 14;
  var blockCenter = wcy - 46;
  var topLineY = blockCenter + ((lines.length - 1) * lineH) / 2;
  for (var li=0; li<lines.length; li++) {
    var yPos = topLineY - li * lineH;
    win.contentView.addSubview(makeCentered(lines[li], yPos, msgFontSize, msgFontName, 0.85, 0.9, 1.0, 0.75));
  }

  // ── Click-to-dismiss + focus correct window ──
  ObjC.registerSubclass({
    name: 'JarvisDismissHandler', superclass: 'NSObject',
    methods: { 'handleDismiss': { types: ['void', []], implementation: function() {
      // iTerm2: raise the specific window containing our session
      if (sessionTty && bundleId === 'com.googlecode.iterm2') {
        var task = $.NSTask.alloc.init;
        task.setLaunchPath($('/usr/bin/osascript'));
        task.setArguments($(['-l', 'JavaScript', '-e',
          'var iTerm=Application("iTerm2");var ws=iTerm.windows();var f=0;' +
          'for(var w=0;w<ws.length&&!f;w++){var ts=ws[w].tabs();' +
          'for(var t=0;t<ts.length&&!f;t++){var ss=ts[t].sessions();' +
          'for(var s=0;s<ss.length&&!f;s++){try{if(ss[s].tty()==="' + sessionTty + '")' +
          '{ts[t].select();ss[s].select();var wn=ws[w].name();' +
          'var se=Application("System Events");var sw=se.processes["iTerm2"].windows();' +
          'for(var i=0;i<sw.length;i++){try{if(sw[i].name()===wn){sw[i].actions["AXRaise"].perform();break}}catch(e2){}}' +
          'ws[w].index=1;iTerm.activate();f=1}}catch(e){}}}}'
        ]));
        task.launch;
        task.waitUntilExit;
      } else if (bundleId || idePid > 0) {
        var activated = false;
        if (bundleId) {
          var ws=$.NSWorkspace.sharedWorkspace, apps=ws.runningApplications;
          for (var i=0;i<apps.count;i++) {
            var app=apps.objectAtIndex(i), bid=app.bundleIdentifier;
            if (!bid.isNil() && bid.js===bundleId) {
              app.activateWithOptions($.NSApplicationActivateIgnoringOtherApps);
              activated=true; break;
            }
          }
        }
        if (!activated && idePid > 0) {
          var ideApp=$.NSRunningApplication.runningApplicationWithProcessIdentifier(idePid);
          if (ideApp && !ideApp.isNil()) ideApp.activateWithOptions($.NSApplicationActivateIgnoringOtherApps);
        }
      }
      $.NSApp.terminate(null);
    }}}
  });
  var dh=$.JarvisDismissHandler.alloc.init;
  var btn=$.NSButton.alloc.initWithFrame($.NSMakeRect(0,0,winSize,winSize));
  btn.setTitle($('')); btn.setBordered(false); btn.setTransparent(true);
  btn.setTarget(dh); btn.setAction('handleDismiss');
  win.contentView.addSubview(btn);

  // ══════════════════════════════════════════════
  // ANIMATION
  // ══════════════════════════════════════════════
  win.orderFrontRegardless;
  win.animator.setAlphaValue(1.0);

  function updateRotArcs(layers, defs, angle) {
    for (var i=0; i<layers.length; i++) {
      var d=defs[i], p=$.CGPathCreateMutable();
      $.CGPathAddArc(p,null,cx,cy,d.r, d.s+angle, d.s+d.len+angle, false);
      layers[i].setPath(p);
    }
  }

  var animSteps = 120, animInterval = dismiss / animSteps;
  var step = { val: 0 };

  ObjC.registerSubclass({
    name: 'JarvisAnimator', superclass: 'NSObject',
    methods: { 'tick:': { types: ['void', ['id']], implementation: function(timer) {
      step.val++;
      var p = Math.min(step.val / animSteps, 1.0);
      var t = step.val * animInterval;

      // Rotate with random offsets, speeds, and sine wobble
      updateRotArcs(rotAL, rotA, offA + t*spdA + Math.sin(t*wobA.f)*wobA.a);
      updateRotArcs(rotBL, rotB, offB - t*spdB + Math.sin(t*wobB.f)*wobB.a);
      updateRotArcs(rotCL, rotC, offC + t*spdC + Math.sin(t*wobC.f)*wobC.a);
      updateRotArcs(rotDL, rotD, offD - t*spdD + Math.sin(t*wobD.f)*wobD.a);
      updateRotArcs(rotEL, rotE, offE + t*spdE + Math.sin(t*wobE.f)*wobE.a);

      // Progress fill
      progressBase.setStrokeEnd(p);
      progressTicks.setStrokeEnd(p);
      progressGlow.setStrokeEnd(p);

      // Progress complete → hide window (terminate handled by separate timer)
      if (step.val >= animSteps) {
        timer.invalidate();
        win.setAlphaValue(0.0);
        win.orderOut(null);
      }
    }}}
  });

  var anim = $.JarvisAnimator.alloc.init;
  $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
    animInterval, anim, 'tick:', null, true);

  // Hard terminate after dismiss time (independent timer — works reliably)
  $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
    dismiss + 0.3, $.NSApp, 'terminate:', null, false);

  $.NSApp.run;
}
