#!/usr/bin/env osascript -l JavaScript
// Sakura / Japanese Zen Garden overlay notification for macOS
// Usage: osascript -l JavaScript mac-overlay-sakura.js <message> <color> <icon_path> <slot> <dismiss_seconds> [bundle_id] [ide_pid] [session_tty]

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

  var PI = Math.PI, TAU = 2 * PI;

  // ── Type text ──
  var typeText = 'INPUT REQUIRED';
  if (color === 'red') typeText = 'LIMIT REACHED';
  if (color === 'yellow') typeText = 'LIMIT REACHED';
  if (color === 'green') typeText = 'TASK COMPLETE';

  // ── Window dimensions ──
  var winW = 360, winH = 180;
  var padX = 20, padY = 20;
  var contentW = 320, contentH = 140;
  var cornerRadius = 20;

  // ── NSApp setup ──
  $.NSApplication.sharedApplication;
  $.NSApp.setActivationPolicy($.NSApplicationActivationPolicyAccessory);

  // ── Screen detection: find screen where mouse cursor is ──
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
  var x = vf.origin.x + vf.size.width - winW - 10;
  var y = vf.origin.y + vf.size.height - winH - (10 + slot * (winH + 8));

  // ── Window ──
  var win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(
    $.NSMakeRect(x, y, winW, winH),
    $.NSWindowStyleMaskBorderless, $.NSBackingStoreBuffered, false
  );
  win.setBackgroundColor($.NSColor.clearColor);
  win.setOpaque(false); win.setHasShadow(false); win.setAlphaValue(0.0);
  win.setLevel($.NSStatusWindowLevel);
  win.setCollectionBehavior($.NSWindowCollectionBehaviorCanJoinAllSpaces | $.NSWindowCollectionBehaviorStationary);
  win.contentView.wantsLayer = true;

  // ── Color palette ──
  function cg(r,g,b,a) { return $.NSColor.colorWithSRGBRedGreenBlueAlpha(r,g,b,a).CGColor; }

  // Sumi ink background
  var inkBgCG = cg(0.08, 0.06, 0.07, 0.92);

  // Cherry blossom palette
  var sakuraCG      = cg(1.0, 0.72, 0.77, 1.0);
  var sakuraLightCG = cg(1.0, 0.85, 0.88, 0.8);
  var sakuraDimCG   = cg(1.0, 0.72, 0.77, 0.3);
  var sakuraFaintCG = cg(1.0, 0.72, 0.77, 0.1);

  // Text
  var creamCG = cg(0.98, 0.96, 0.93, 0.9);

  // Accent color based on notification type
  var accentR, accentG, accentB;
  switch (color) {
    case 'red':    accentR=0.77; accentG=0.12; accentB=0.23; break; // deep red
    case 'yellow': accentR=0.77; accentG=0.65; accentB=0.26; break; // gold chrysanthemum
    case 'green':  accentR=0.31; accentG=0.47; accentB=0.26; break; // bamboo green
    case 'blue': default: accentR=1.0; accentG=0.72; accentB=0.77; break; // sakura pink
  }
  var accentCG = cg(accentR, accentG, accentB, 1.0);

  // ══════════════════════════════════════════════
  // HUD VIEW
  // ══════════════════════════════════════════════
  var hud = $.NSView.alloc.initWithFrame($.NSMakeRect(padX, padY, contentW, contentH));
  hud.setWantsLayer(true);

  // ── 1. Background — rounded rect filled with ink black ──
  var bgPath = $.CGPathCreateWithRoundedRect(
    $.CGRectMake(0, 0, contentW, contentH), cornerRadius, cornerRadius, null
  );
  var bg = $.CAShapeLayer.layer;
  bg.setPath(bgPath);
  bg.setFillColor(inkBgCG);
  hud.layer.addSublayer(bg);

  // ── 2. Ink wash splashes — watercolor texture ──
  // Splash 1 (top-right, large, very faint)
  var sp1 = $.CGPathCreateMutable();
  $.CGPathAddArc(sp1, null, contentW*0.75, contentH*0.65, 60, 0, TAU, false);
  var splash1 = $.CAShapeLayer.layer;
  splash1.setPath(sp1);
  splash1.setFillColor(cg(0.12, 0.08, 0.1, 0.15));
  hud.layer.addSublayer(splash1);

  // Splash 2 (bottom-left, smaller)
  var sp2 = $.CGPathCreateMutable();
  $.CGPathAddArc(sp2, null, contentW*0.25, contentH*0.3, 45, 0, TAU, false);
  var splash2 = $.CAShapeLayer.layer;
  splash2.setPath(sp2);
  splash2.setFillColor(cg(0.15, 0.1, 0.12, 0.12));
  hud.layer.addSublayer(splash2);

  // Splash 3 (center-top, subtle)
  var sp3 = $.CGPathCreateMutable();
  $.CGPathAddArc(sp3, null, contentW*0.5, contentH*0.8, 35, 0, TAU, false);
  var splash3 = $.CAShapeLayer.layer;
  splash3.setPath(sp3);
  splash3.setFillColor(cg(0.1, 0.07, 0.09, 0.1));
  hud.layer.addSublayer(splash3);

  // ── 3. Border — very thin sakura-tinted ──
  var border = $.CAShapeLayer.layer;
  border.setPath(bgPath);
  border.setFillColor(null);
  border.setStrokeColor(sakuraFaintCG);
  border.setLineWidth(1.0);
  hud.layer.addSublayer(border);

  // ── 4. Bonsai — classic style with thick trunk & canopy pads ──
  var bx = contentW - 48, by = 18;

  // Helper: organic cloud-pad shape (irregular bumpy outline)
  function cloudPad(cx, cy, rx, ry, bumps) {
    var p = $.CGPathCreateMutable();
    for (var i = 0; i <= bumps; i++) {
      var a = (i / bumps) * TAU;
      var bumpR = 0.85 + 0.3 * Math.sin(a * 3.7 + cx) + 0.15 * Math.cos(a * 2.3 + cy);
      var px = cx + Math.cos(a) * rx * bumpR;
      var py = cy + Math.sin(a) * ry * bumpR;
      if (i === 0) $.CGPathMoveToPoint(p, null, px, py);
      else $.CGPathAddLineToPoint(p, null, px, py);
    }
    $.CGPathCloseSubpath(p);
    return p;
  }

  // Pot — small rectangular base
  var pot = $.CAShapeLayer.layer, pp = $.CGPathCreateMutable();
  $.CGPathMoveToPoint(pp, null, bx-12, by);
  $.CGPathAddLineToPoint(pp, null, bx+12, by);
  $.CGPathAddLineToPoint(pp, null, bx+10, by+6);
  $.CGPathAddLineToPoint(pp, null, bx-10, by+6);
  $.CGPathCloseSubpath(pp);
  // Pot rim
  $.CGPathMoveToPoint(pp, null, bx-14, by+6);
  $.CGPathAddLineToPoint(pp, null, bx+14, by+6);
  $.CGPathAddLineToPoint(pp, null, bx+14, by+9);
  $.CGPathAddLineToPoint(pp, null, bx-14, by+9);
  $.CGPathCloseSubpath(pp);
  pot.setPath(pp);
  pot.setFillColor(cg(0.25, 0.15, 0.10, 0.50));
  pot.setStrokeColor(cg(0.30, 0.18, 0.12, 0.35));
  pot.setLineWidth(0.5);
  hud.layer.addSublayer(pot);

  // Trunk — filled shape, thick S-curve leaning slightly right
  var trunkL = $.CAShapeLayer.layer, tlp = $.CGPathCreateMutable();
  // Left contour (base thick → top thin)
  $.CGPathMoveToPoint(tlp, null, bx-5, by+9);
  $.CGPathAddCurveToPoint(tlp, null, bx-8, by+20, bx-10, by+32, bx-6, by+44);
  $.CGPathAddCurveToPoint(tlp, null, bx-3, by+52, bx-2, by+58, bx-2, by+62);
  // Top
  $.CGPathAddCurveToPoint(tlp, null, bx-1, by+64, bx+2, by+64, bx+3, by+62);
  // Right contour (top thin → base thick)
  $.CGPathAddCurveToPoint(tlp, null, bx+3, by+58, bx+4, by+52, bx+6, by+44);
  $.CGPathAddCurveToPoint(tlp, null, bx+9, by+32, bx+7, by+20, bx+5, by+9);
  $.CGPathCloseSubpath(tlp);
  trunkL.setPath(tlp);
  trunkL.setFillColor(cg(0.22, 0.14, 0.09, 0.50));
  trunkL.setStrokeColor(cg(0.18, 0.11, 0.07, 0.35));
  trunkL.setLineWidth(0.6);
  hud.layer.addSublayer(trunkL);

  // Trunk texture — faint vertical grain lines
  var grain = $.CAShapeLayer.layer, gp = $.CGPathCreateMutable();
  $.CGPathMoveToPoint(gp, null, bx-2, by+12);
  $.CGPathAddCurveToPoint(gp, null, bx-4, by+28, bx-3, by+44, bx-1, by+58);
  $.CGPathMoveToPoint(gp, null, bx+2, by+14);
  $.CGPathAddCurveToPoint(gp, null, bx+3, by+30, bx+4, by+44, bx+2, by+56);
  grain.setPath(gp); grain.setFillColor(null);
  grain.setStrokeColor(cg(0.15, 0.09, 0.06, 0.18));
  grain.setLineWidth(0.4); hud.layer.addSublayer(grain);

  // Branches — visible between canopy pads
  function addBr(x1,y1,cx1,cy1,cx2,cy2,x2,y2,w,a) {
    var bl = $.CAShapeLayer.layer, bp = $.CGPathCreateMutable();
    $.CGPathMoveToPoint(bp, null, x1, y1);
    $.CGPathAddCurveToPoint(bp, null, cx1, cy1, cx2, cy2, x2, y2);
    bl.setPath(bp); bl.setFillColor(null);
    bl.setStrokeColor(cg(0.20, 0.13, 0.08, a));
    bl.setLineWidth(w); bl.setLineCap('round');
    hud.layer.addSublayer(bl);
  }
  // Right main branch
  addBr(bx+1,by+54, bx+10,by+58, bx+22,by+62, bx+36,by+60, 2.0, 0.40);
  // Right sub-branch up
  addBr(bx+18,by+60, bx+22,by+66, bx+24,by+72, bx+22,by+78, 1.2, 0.32);
  // Left main branch
  addBr(bx-1,by+56, bx-14,by+62, bx-28,by+64, bx-38,by+60, 1.8, 0.38);
  // Left sub-branch up
  addBr(bx-22,by+62, bx-26,by+68, bx-28,by+74, bx-25,by+78, 1.0, 0.30);
  // Top branch
  addBr(bx,by+62, bx+1,by+70, bx+2,by+78, bx+3,by+86, 1.4, 0.35);
  // Top-left small branch
  addBr(bx-1,by+64, bx-8,by+72, bx-12,by+78, bx-10,by+84, 1.0, 0.28);

  // Canopy pads — organic cloud shapes with depth layers
  var fShadow = cg(accentR*0.4, accentG*0.4, accentB*0.4, 0.20);
  var fBase   = cg(accentR, accentG, accentB, 0.22);
  var fMid    = cg(accentR, accentG, accentB, 0.38);
  var fLight  = cg(accentR*0.7+0.3, accentG*0.7+0.3, accentB*0.7+0.3, 0.30);
  var fEdge   = cg(accentR, accentG, accentB, 0.15);

  // Pad definitions: {x, y, rx, ry} — elliptical cloud pads
  var pads = [
    // Right canopy (largest)
    {x:bx+36, y:by+62, rx:18, ry:12},
    // Right upper pad
    {x:bx+22, y:by+80, rx:13, ry:10},
    // Left canopy
    {x:bx-36, y:by+62, rx:16, ry:11},
    // Left upper pad
    {x:bx-24, y:by+80, rx:12, ry:9},
    // Top crown (tallest)
    {x:bx+3, y:by+90, rx:16, ry:13},
    // Top-left pad
    {x:bx-10, y:by+86, rx:11, ry:9},
  ];

  for (var pi = 0; pi < pads.length; pi++) {
    var pd = pads[pi];
    // Shadow (offset down-left, larger)
    var sl = $.CAShapeLayer.layer;
    sl.setPath(cloudPad(pd.x-1, pd.y-2, pd.rx+2, pd.ry+2, 32));
    sl.setFillColor(fShadow); sl.setStrokeColor(null);
    hud.layer.addSublayer(sl);
    // Base fill
    var bl = $.CAShapeLayer.layer;
    bl.setPath(cloudPad(pd.x, pd.y, pd.rx, pd.ry, 32));
    bl.setFillColor(fBase); bl.setStrokeColor(fEdge);
    bl.setLineWidth(0.6); hud.layer.addSublayer(bl);
    // Mid highlight (upper portion, smaller)
    var ml = $.CAShapeLayer.layer;
    ml.setPath(cloudPad(pd.x+1, pd.y+2, pd.rx*0.75, pd.ry*0.7, 24));
    ml.setFillColor(fMid); ml.setStrokeColor(null);
    hud.layer.addSublayer(ml);
    // Light spot (top, small)
    var ll = $.CAShapeLayer.layer;
    ll.setPath(cloudPad(pd.x+2, pd.y+3, pd.rx*0.4, pd.ry*0.35, 16));
    ll.setFillColor(fLight); ll.setStrokeColor(null);
    hud.layer.addSublayer(ll);
  }

  // ── 5. Cherry blossom petals (ANIMATED) ──
  var NUM_PETALS = 10;
  var petals = [];
  for (var pi = 0; pi < NUM_PETALS; pi++) {
    var petal = $.CAShapeLayer.layer;
    petal.setFillColor(pi % 3 === 0 ? sakuraLightCG : sakuraDimCG);
    petal.setStrokeColor(null);
    hud.layer.addSublayer(petal);
    petals.push({
      layer: petal,
      x: Math.random() * (contentW + 40) - 20,
      y: contentH + 10 + Math.random() * 40,  // start above (Cocoa: y=0 is bottom, higher y = higher visually)
      vx: -0.3 - Math.random() * 0.5,          // drift left
      vy: -0.5 - Math.random() * 0.8,          // fall down (decreasing y in Cocoa)
      rot: Math.random() * TAU,
      rotSpeed: (Math.random() - 0.5) * 0.08,
      wobblePhase: Math.random() * TAU,
      wobbleAmp: 0.3 + Math.random() * 0.6,
      wobbleFreq: 1.5 + Math.random() * 2.0,
      opacity: 0.4 + Math.random() * 0.5,
    });
  }

  // ── 6. Progress line — thin horizontal line at bottom ──
  var progressPath = $.CGPathCreateMutable();
  $.CGPathMoveToPoint(progressPath, null, 16, 8);
  $.CGPathAddLineToPoint(progressPath, null, contentW - 16, 8);
  var progressLine = $.CAShapeLayer.layer;
  progressLine.setPath(progressPath);
  progressLine.setFillColor(null);
  progressLine.setStrokeColor(accentCG);
  progressLine.setLineWidth(1.0);
  progressLine.setStrokeEnd(0);
  hud.layer.addSublayer(progressLine);

  // ── Shadow — sakura-tinted glow ──
  hud.layer.shadowColor = cg(accentR, accentG, accentB, 0.5);
  hud.layer.shadowRadius = 15;
  hud.layer.shadowOpacity = 0.3;
  hud.layer.shadowOffset = $.CGSizeMake(0, 0);

  win.contentView.addSubview(hud);

  // ══════════════════════════════════════════════
  // TEXT — zen calligraphy aesthetic
  // ══════════════════════════════════════════════
  var textShadow = $.NSShadow.alloc.init;
  textShadow.setShadowOffset($.NSMakeSize(0, -1));
  textShadow.setShadowBlurRadius(4);
  textShadow.setShadowColor($.NSColor.colorWithSRGBRedGreenBlueAlpha(0, 0, 0, 1.0));

  function makeCentered(text, yPos, fontSize, fontName, r, g, b, alpha) {
    var font = $.NSFont.fontWithNameSize(fontName, fontSize);
    if (!font || font.isNil()) font = $.NSFont.systemFontOfSize(fontSize);
    var label = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0, 0, 400, 40));
    label.setStringValue($(text)); label.setBezeled(false); label.setDrawsBackground(false);
    label.setEditable(false); label.setSelectable(false);
    label.setTextColor($.NSColor.colorWithSRGBRedGreenBlueAlpha(r, g, b, alpha));
    label.setFont(font); label.setShadow(textShadow); label.sizeToFit;
    var w = label.frame.size.width, h = label.frame.size.height;
    // Center horizontally within the window
    var wcx = padX + contentW / 2;
    label.setFrame($.NSMakeRect(wcx - w/2, yPos, w, h));
    return label;
  }

  // Mark: cherry blossom kanji at top
  win.contentView.addSubview(makeCentered('\u685C', padY + contentH - 42, 20, 'HiraginoSans-W3', accentR, accentG, accentB, 1.0));

  // Type label (e.g. "TASK COMPLETE")
  win.contentView.addSubview(makeCentered(typeText, padY + contentH - 58, 8, 'HelveticaNeue-Light', accentR, accentG, accentB, 0.5));

  // Message — word-wrap into individually centered lines
  var msgFontName = 'HelveticaNeue-Thin', msgFontSize = 12;
  var msgFont = $.NSFont.fontWithNameSize(msgFontName, msgFontSize);
  if (!msgFont || msgFont.isNil()) msgFont = $.NSFont.systemFontOfSize(msgFontSize);
  var maxMW = 260;
  var tmp = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0, 0, 400, 20));
  tmp.setFont(msgFont); tmp.setBezeled(false);

  // Word-wrap into lines that fit
  var words = message.split(' '), lines = [], curLine = '';
  for (var wi = 0; wi < words.length; wi++) {
    var test = curLine ? curLine + ' ' + words[wi] : words[wi];
    tmp.setStringValue($(test)); tmp.sizeToFit;
    if (tmp.frame.size.width > maxMW && curLine) {
      lines.push(curLine); curLine = words[wi];
    } else { curLine = test; }
  }
  if (curLine) lines.push(curLine);

  // Position block: center vertically in the lower portion
  var lineH = 16;
  var blockCenter = padY + 38;  // lower area of the card
  var topLineY = blockCenter + ((lines.length - 1) * lineH) / 2;
  for (var li = 0; li < lines.length; li++) {
    var yPos = topLineY - li * lineH;
    win.contentView.addSubview(makeCentered(lines[li], yPos, msgFontSize, msgFontName, 0.98, 0.96, 0.93, 0.9));
  }

  // ══════════════════════════════════════════════
  // CLICK-TO-DISMISS + focus correct window
  // ══════════════════════════════════════════════
  ObjC.registerSubclass({
    name: 'SakuraDismissHandler', superclass: 'NSObject',
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
  var dh = $.SakuraDismissHandler.alloc.init;
  var btn = $.NSButton.alloc.initWithFrame($.NSMakeRect(0, 0, winW, winH));
  btn.setTitle($('')); btn.setBordered(false); btn.setTransparent(true);
  btn.setTarget(dh); btn.setAction('handleDismiss');
  win.contentView.addSubview(btn);

  // ══════════════════════════════════════════════
  // ANIMATION
  // ══════════════════════════════════════════════
  win.orderFrontRegardless;
  win.animator.setAlphaValue(1.0);

  var animSteps = 120, animInterval = dismiss / animSteps;
  var step = { val: 0 };

  ObjC.registerSubclass({
    name: 'SakuraAnimator', superclass: 'NSObject',
    methods: { 'tick:': { types: ['void', ['id']], implementation: function(timer) {
      step.val++;
      var p = Math.min(step.val / animSteps, 1.0);
      var t = step.val * animInterval;

      // Update cherry blossom petals
      for (var pi = 0; pi < petals.length; pi++) {
        var pt = petals[pi];
        pt.x += pt.vx + Math.sin(t * pt.wobbleFreq + pt.wobblePhase) * pt.wobbleAmp;
        pt.y += pt.vy;
        pt.rot += pt.rotSpeed;
        // Wrap: if petal exits bottom or left, reset to top-right
        if (pt.y < -10 || pt.x < -20) {
          pt.x = contentW + Math.random() * 20;
          pt.y = contentH + Math.random() * 20;
        }
        // Recreate path at new position (fallback: no CGAffineTransform)
        var pp = $.CGPathCreateMutable();
        $.CGPathAddEllipseInRect(pp, null, $.CGRectMake(pt.x - 2, pt.y - 3, 4, 6));
        pt.layer.setPath(pp);
        pt.layer.setOpacity(pt.opacity * (0.7 + 0.3 * Math.sin(t * 2 + pt.wobblePhase)));
      }

      // Progress line
      progressLine.setStrokeEnd(p);

      // Progress complete — hide window (terminate handled by separate timer)
      if (step.val >= animSteps) {
        timer.invalidate();
        win.setAlphaValue(0.0);
        win.orderOut(null);
      }
    }}}
  });

  var anim = $.SakuraAnimator.alloc.init;
  $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
    animInterval, anim, 'tick:', null, true);

  // Hard terminate after dismiss time (independent timer — works reliably)
  $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
    dismiss + 0.3, $.NSApp, 'terminate:', null, false);

  $.NSApp.run;
}
