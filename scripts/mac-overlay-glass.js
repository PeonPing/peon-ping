#!/usr/bin/env osascript -l JavaScript
// Glass / Glassmorphism overlay notification for macOS
// Usage: osascript -l JavaScript mac-overlay-glass.js <message> <color> <icon_path> <slot> <dismiss_seconds> [bundle_id] [ide_pid] [session_tty]

ObjC.import('Cocoa');
ObjC.import('QuartzCore');

function run(argv) {
  var message  = argv[0] || 'peon-ping';
  var color    = argv[1] || 'blue';
  var iconPath = argv[2] || '';   // kept for compat with notify.sh (unused)
  var slot     = parseInt(argv[3], 10) || 0;
  var dismiss  = argv[4] !== undefined ? parseFloat(argv[4]) : 5;
  if (isNaN(dismiss)) dismiss = 5;
  var bundleId   = argv[5] || '';
  var idePid     = parseInt(argv[6], 10) || 0;
  var sessionTty  = argv[7] || '';  // TTY of the Claude session (for window focus)
  var subtitle    = argv[8] || '';  // Context subtitle (e.g. tool info, last message)
  var position    = argv[9] || 'top-center';
  var notifType   = argv[10] || ''; // Semantic type: complete|permission|limit|idle|question
  var allScreens  = argv[11] === 'true';
  var screenIdx   = (argv[12] !== undefined && argv[12] !== '') ? parseInt(argv[12], 10) : -1;

  // ── Type text ──
  var typeText;
  switch (notifType) {
    case 'complete':   typeText = 'TASK COMPLETE';   break;
    case 'permission': typeText = 'APPROVAL NEEDED'; break;
    case 'limit':      typeText = 'LIMIT REACHED';   break;
    case 'idle':       typeText = 'STANDING BY';     break;
    case 'question':   typeText = 'INPUT REQUIRED';  break;
    default:
      // Fallback for relay.sh and other callers that don't set notifType
      if (color === 'blue')   typeText = 'TASK COMPLETE';
      else if (color === 'red' || color === 'yellow') typeText = 'LIMIT REACHED';
      else                    typeText = 'INPUT REQUIRED';
  }

  // ── Window dimensions ──
  var winW = 380, winH = 160;
  var padX = 20, padY = 20;
  var contentW = 340, contentH = 120;
  var cornerRadius = 16;

  // ── NSApp setup ──
  $.NSApplication.sharedApplication;
  $.NSApp.setActivationPolicy($.NSApplicationActivationPolicyAccessory);

  // Generate unique notification ID for all sibling overlays (all-screens mode)
  var slotForNotification = parseInt(argv[3], 10) || 0;
  var dismissNotificationName = 'com.peonping.dismiss.glass.' + slotForNotification;

  // ── Screen detection ──
  var screens = $.NSScreen.screens;
  var targetScreen;
  if (screenIdx >= 0 && screenIdx < screens.count) {
    targetScreen = screens.objectAtIndex(screenIdx);
  } else {
    // Find screen where mouse cursor is
    var mouseLocation = $.NSEvent.mouseLocation;
    targetScreen = screens.objectAtIndex(0);
    for (var s = 0; s < screens.count; s++) {
      var scr = screens.objectAtIndex(s);
      var sf = scr.frame;
      if (mouseLocation.x >= sf.origin.x && mouseLocation.x <= sf.origin.x + sf.size.width &&
          mouseLocation.y >= sf.origin.y && mouseLocation.y <= sf.origin.y + sf.size.height) {
        targetScreen = scr; break;
      }
    }
  }

  var vf = targetScreen.visibleFrame;
  var margin = 10;
  var slotStep = winH + 8;
  var ySlotOffset = margin + slot * slotStep;
  var x, y;
  switch (position) {
    case 'top-right':
      x = vf.origin.x + vf.size.width - winW - margin;
      y = vf.origin.y + vf.size.height - winH - ySlotOffset;
      break;
    case 'top-left':
      x = vf.origin.x + margin;
      y = vf.origin.y + vf.size.height - winH - ySlotOffset;
      break;
    case 'bottom-right':
      x = vf.origin.x + vf.size.width - winW - margin;
      y = vf.origin.y + ySlotOffset;
      break;
    case 'bottom-left':
      x = vf.origin.x + margin;
      y = vf.origin.y + ySlotOffset;
      break;
    case 'bottom-center':
      x = vf.origin.x + (vf.size.width - winW) / 2;
      y = vf.origin.y + ySlotOffset;
      break;
    default: // top-center
      x = vf.origin.x + (vf.size.width - winW) / 2;
      y = vf.origin.y + vf.size.height - winH - ySlotOffset;
  }

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

  // Glass dark background
  var inkBgCG = cg(0.10, 0.10, 0.14, 0.88);

  // Glass border
  var glassBorderCG = cg(0.99, 0.99, 0.99, 0.10);

  // Accent color based on notification type
  var accentR, accentG, accentB;
  switch (color) {
    case 'red':    accentR=0.90; accentG=0.25; accentB=0.30; break;
    case 'yellow': accentR=0.95; accentG=0.75; accentB=0.20; break;
    case 'green':  accentR=0.30; accentG=0.80; accentB=0.40; break;
    case 'blue': default: accentR=0.40; accentG=0.60; accentB=0.99; break;
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

  // ── 2. Border ──
  var border = $.CAShapeLayer.layer;
  border.setPath(bgPath);
  border.setFillColor(null);
  border.setStrokeColor(glassBorderCG);
  border.setLineWidth(1.0);
  hud.layer.addSublayer(border);

  // ── 4. Progress line — thin horizontal line at bottom ──
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

  // ── Shadow ──
  hud.layer.shadowColor = cg(0.01, 0.01, 0.01, 0.99);
  hud.layer.shadowRadius = 20;
  hud.layer.shadowOpacity = 0.3;
  hud.layer.shadowOffset = $.CGSizeMake(0, -3);

  win.contentView.addSubview(hud);

  // ══════════════════════════════════════════════
  // ACCENT BAR — vertical bar on the left
  // ══════════════════════════════════════════════
  var barPath = $.CGPathCreateMutable();
  $.CGPathMoveToPoint(barPath, null, padX + 12, padY + 24);
  $.CGPathAddLineToPoint(barPath, null, padX + 12, padY + contentH - 24);
  var accentBar = $.CAShapeLayer.layer;
  accentBar.setPath(barPath);
  accentBar.setFillColor(null);
  accentBar.setStrokeColor(accentCG);
  accentBar.setLineWidth(3.0);
  accentBar.setLineCap('round');
  win.contentView.layer.addSublayer(accentBar);

  // ══════════════════════════════════════════════
  // TEXT — clean glassmorphism, left-aligned
  // ══════════════════════════════════════════════
  function makeLabel(text, xPos, yPos, fontSize, fontName, r, g, b, alpha) {
    var font = $.NSFont.fontWithNameSize(fontName, fontSize);
    if (!font || font.isNil()) font = $.NSFont.systemFontOfSize(fontSize);
    var label = $.NSTextField.alloc.initWithFrame($.NSMakeRect(xPos, yPos, contentW - 40, 30));
    label.setStringValue($(text)); label.setBezeled(false); label.setDrawsBackground(false);
    label.setEditable(false); label.setSelectable(false);
    label.setTextColor($.NSColor.colorWithSRGBRedGreenBlueAlpha(r, g, b, alpha));
    label.setFont(font); label.sizeToFit;
    return label;
  }

  var textX = padX + 24;

  // Type label (e.g. "TASK COMPLETE")
  win.contentView.addSubview(makeLabel(typeText, textX, padY + contentH - 38, 10, 'HelveticaNeue-Bold', accentR, accentG, accentB, 0.7));

  // Message — word-wrap
  var msgFontName = 'HelveticaNeue', msgFontSize = 13;
  var msgFont = $.NSFont.fontWithNameSize(msgFontName, msgFontSize);
  if (!msgFont || msgFont.isNil()) msgFont = $.NSFont.systemFontOfSize(msgFontSize);
  var maxMW = contentW - 50;
  var tmp = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0, 0, 400, 20));
  tmp.setFont(msgFont); tmp.setBezeled(false);

  var words = message.split(' '), lines = [], curLine = '';
  for (var wi = 0; wi < words.length; wi++) {
    var test = curLine ? curLine + ' ' + words[wi] : words[wi];
    tmp.setStringValue($(test)); tmp.sizeToFit;
    if (tmp.frame.size.width > maxMW && curLine) {
      lines.push(curLine); curLine = words[wi];
    } else { curLine = test; }
  }
  if (curLine) lines.push(curLine);

  var lineH = 18;
  var topLineY = padY + contentH - 56;
  for (var li = 0; li < lines.length; li++) {
    var yPos = topLineY - li * lineH;
    win.contentView.addSubview(makeLabel(lines[li], textX, yPos, msgFontSize, msgFontName, 0.95, 0.95, 0.95, 0.9));
  }

  // Context subtitle — smaller, word-wrapped, below message
  if (subtitle) {
    var subFontSize = 10, subFontName = 'HelveticaNeue';
    var subFont = $.NSFont.fontWithNameSize(subFontName, subFontSize);
    if (!subFont || subFont.isNil()) subFont = $.NSFont.systemFontOfSize(subFontSize);
    var subTmp = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0,0,400,20));
    subTmp.setFont(subFont); subTmp.setBezeled(false);
    var subMaxW = maxMW - 20;
    var subWords = subtitle.split(' '), subLines = [], subCur = '';
    for (var sw=0; sw<subWords.length; sw++) {
      var subTest = subCur ? subCur + ' ' + subWords[sw] : subWords[sw];
      subTmp.setStringValue($(subTest)); subTmp.sizeToFit;
      if (subTmp.frame.size.width > subMaxW && subCur) {
        subLines.push(subCur); subCur = subWords[sw];
      } else { subCur = subTest; }
    }
    if (subCur) subLines.push(subCur);
    if (subLines.length > 2) subLines = [subLines[0], subLines[1] + '...'];
    var subLineH = 13;
    var subTopY = topLineY - lines.length * lineH - 3;
    for (var sl=0; sl<subLines.length; sl++) {
      var subYPos = subTopY - sl * subLineH;
      win.contentView.addSubview(makeLabel(subLines[sl], textX, subYPos, subFontSize, subFontName, 0.7, 0.75, 0.85, 0.55));
    }
  }

  // Timestamp
  var now = new Date();
  var ts = ('0'+now.getHours()).slice(-2)+':'+('0'+now.getMinutes()).slice(-2);
  win.contentView.addSubview(makeLabel(ts, textX, padY + 10, 10, 'HelveticaNeue', 0.6, 0.6, 0.6, 0.5));

  // ══════════════════════════════════════════════
  // CLICK-TO-DISMISS + focus correct window
  // ══════════════════════════════════════════════
  ObjC.registerSubclass({
    name: 'GlassDismissHandler', superclass: 'NSObject',
    methods: { 'handleDismiss': { types: ['void', []], implementation: function() {
      // Focus the terminal/IDE
      if (bundleId || idePid > 0) {
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
        // iTerm2: try tab/window-level focus after app activation (fire-and-forget)
        if (sessionTty && bundleId === 'com.googlecode.iterm2') {
          try {
            var task = $.NSTask.alloc.init;
            task.setLaunchPath($('/usr/bin/osascript'));
            task.setArguments($(['-l', 'JavaScript', '-e',
              'var iTerm=Application("iTerm2");var ws=iTerm.windows();var f=0;' +
              'for(var w=0;w<ws.length&&!f;w++){var ts=ws[w].tabs();' +
              'for(var t=0;t<ts.length&&!f;t++){var ss=ts[t].sessions();' +
              'for(var s=0;s<ss.length&&!f;s++){try{if(ss[s].tty()==="' + sessionTty + '")' +
              '{ts[t].select();ss[s].select();ws[w].index=1;f=1}}catch(e){}}}}'
            ]));
            task.launch;
          } catch(e) {}
        }
      }
      // Signal ALL sibling overlays to dismiss (event-driven, no polling!)
      $.NSDistributedNotificationCenter.defaultCenter.postNotificationNameObject($(dismissNotificationName), $.NSString.string);
      // Small delay to ensure notification is delivered before we terminate
      $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
        0.05, $.NSApp, 'terminate:', null, false
      );
    }}}
  });
  var dh = $.GlassDismissHandler.alloc.init;
  var btn = $.NSButton.alloc.initWithFrame($.NSMakeRect(0, 0, winW, winH));
  btn.setTitle($('')); btn.setBordered(false); btn.setTransparent(true);
  btn.setTarget(dh); btn.setAction('handleDismiss');
  win.contentView.addSubview(btn);

  // ══════════════════════════════════════════════
  // ANIMATION
  // ══════════════════════════════════════════════
  win.orderFrontRegardless;
  win.animator.setAlphaValue(1.0);

  if (dismiss > 0) {
    var animSteps = 120, animInterval = dismiss / animSteps;
    var step = { val: 0 };

    ObjC.registerSubclass({
      name: 'GlassAnimator', superclass: 'NSObject',
      methods: { 'tick:': { types: ['void', ['id']], implementation: function(timer) {
        step.val++;
        var p = Math.min(step.val / animSteps, 1.0);

        // Progress line
        progressLine.setStrokeEnd(p);

        // Fade out in last 15%
        if (p > 0.85) {
          var fadeP = (p - 0.85) / 0.15;
          win.setAlphaValue(0.99 - fadeP * 0.99);
        }

        // Progress complete — hide window
        if (step.val >= animSteps) {
          timer.invalidate();
          win.setAlphaValue(0.0);
          win.orderOut(null);
        }
      }}}
    });

    var anim = $.GlassAnimator.alloc.init;
    $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
      animInterval, anim, 'tick:', null, true);

    // Hard terminate after dismiss time (independent timer — works reliably)
    $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
      dismiss + 0.3, $.NSApp, 'terminate:', null, false);
  }

  // Event-driven dismissal: observe distributed notifications from sibling overlays
  ObjC.registerSubclass({
    name: 'GlassDismissObserver',
    superclass: 'NSObject',
    methods: {
      'handleDismiss:': {
        types: ['void', ['id']],
        implementation: function(notification) {
          $.NSApp.terminate(null);
        }
      }
    }
  });
  var glassObserver = $.GlassDismissObserver.alloc.init;
  $.NSDistributedNotificationCenter.defaultCenter.addObserverSelectorNameObject(
    glassObserver,
    'handleDismiss:',
    $(dismissNotificationName),
    $.NSString.string
  );

  $.NSApp.run;
}
