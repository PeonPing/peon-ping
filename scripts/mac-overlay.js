#!/usr/bin/env osascript -l JavaScript
// mac-overlay.js — JXA Cocoa overlay notification for macOS
// Usage: osascript -l JavaScript mac-overlay.js <message> <color> <icon_path> <slot> <dismiss_seconds> [bundle_id] [ide_pid] [session_tty] [subtitle] [position]
//
// Creates a borderless, always-on-top overlay on every screen.
// Dismisses automatically after <dismiss_seconds> seconds (0 = persistent until clicked).
// If bundle_id is provided, clicking the overlay activates that app (click-to-focus).
// position: top-center (default), top-right, top-left, bottom-right, bottom-left, bottom-center

ObjC.import('Cocoa');

function run(argv) {
  var message  = argv[0] || 'peon-nsx';
  var color    = argv[1] || 'red';
  var iconPath = argv[2] || '';
  var slot     = parseInt(argv[3], 10) || 0;
  var dismiss  = argv[4] !== undefined ? parseFloat(argv[4]) : 4;
  if (isNaN(dismiss)) dismiss = 4;
  var bundleId   = argv[5] || '';
  var idePid     = parseInt(argv[6], 10) || 0;
  var sessionTty = argv[7] || '';
  var subtitle    = argv[8] || '';
  var position    = argv[9] || 'top-center';

  // NSX Design System — backgroundBrand2 (#0B1429 deep navy) as base
  var bgColor = $.NSColor.colorWithSRGBRedGreenBlueAlpha(11/255, 20/255, 41/255, 1.0);

  // Accent stripe color by notification type (NSX Design System tokens)
  var accentR, accentG, accentB;
  switch (color) {
    case 'blue':   accentR = 37/255;  accentG = 128/255; accentB = 255/255; break; // brandPrimary1   #2580FF
    case 'yellow': accentR = 224/255; accentG = 117/255; accentB = 45/255;  break; // supportAlert2   #E0752D
    case 'green':  accentR = 51/255;  accentG = 184/255; accentB = 120/255; break; // supportSuccess2 #33B878
    default:       accentR = 224/255; accentG = 63/255;  accentB = 68/255;  break; // supportError2   #E03F44
  }
  var accentColor = $.NSColor.colorWithSRGBRedGreenBlueAlpha(accentR, accentG, accentB, 1.0);

  var winWidth = 500, winHeight = 80;
  var stripeWidth = 4;

  $.NSApplication.sharedApplication;
  $.NSApp.setActivationPolicy($.NSApplicationActivationPolicyAccessory);

  var persistent = dismiss <= 0;

  // Register a click handler if we have a target bundle ID, IDE PID, or persistent mode
  var clickHandler = null;
  if (bundleId || idePid > 0 || persistent) {
    ObjC.registerSubclass({
      name: 'PeonClickHandler',
      superclass: 'NSObject',
      methods: {
        'handleClick': {
          types: ['void', []],
          implementation: function() {
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
              $.NSApp.terminate(null);
              return;
            }
            var activated = false;
            // Primary: activate by bundle ID
            if (bundleId) {
              var ws = $.NSWorkspace.sharedWorkspace;
              var apps = ws.runningApplications;
              var count = apps.count;
              for (var i = 0; i < count; i++) {
                var app = apps.objectAtIndex(i);
                var bid = app.bundleIdentifier;
                if (!bid.isNil() && bid.js === bundleId) {
                  app.activateWithOptions($.NSApplicationActivateIgnoringOtherApps);
                  activated = true;
                  break;
                }
              }
            }
            // Fallback: activate by IDE PID (for embedded terminals)
            if (!activated && idePid > 0) {
              var ideApp = $.NSRunningApplication.runningApplicationWithProcessIdentifier(idePid);
              if (ideApp && !ideApp.isNil()) {
                ideApp.activateWithOptions($.NSApplicationActivateIgnoringOtherApps);
              }
            }
            $.NSApp.terminate(null);
          }
        }
      }
    });
    clickHandler = $.PeonClickHandler.alloc.init;
  }

  var screens = $.NSScreen.screens;
  var screenCount = screens.count;
  var windows = [];

  for (var i = 0; i < screenCount; i++) {
    var screen = screens.objectAtIndex(i);
    var visibleFrame = screen.visibleFrame;

    var margin = 10;
    var slotStep = winHeight + margin;
    var ySlotOffset = margin + slot * slotStep;
    var x, y;
    switch (position) {
      case 'top-right':
        x = visibleFrame.origin.x + visibleFrame.size.width - winWidth - margin;
        y = visibleFrame.origin.y + visibleFrame.size.height - winHeight - ySlotOffset;
        break;
      case 'top-left':
        x = visibleFrame.origin.x + margin;
        y = visibleFrame.origin.y + visibleFrame.size.height - winHeight - ySlotOffset;
        break;
      case 'bottom-right':
        x = visibleFrame.origin.x + visibleFrame.size.width - winWidth - margin;
        y = visibleFrame.origin.y + ySlotOffset;
        break;
      case 'bottom-left':
        x = visibleFrame.origin.x + margin;
        y = visibleFrame.origin.y + ySlotOffset;
        break;
      case 'bottom-center':
        x = visibleFrame.origin.x + (visibleFrame.size.width - winWidth) / 2;
        y = visibleFrame.origin.y + ySlotOffset;
        break;
      default: // top-center
        x = visibleFrame.origin.x + (visibleFrame.size.width - winWidth) / 2;
        y = visibleFrame.origin.y + visibleFrame.size.height - winHeight - ySlotOffset;
    }
    var frame = $.NSMakeRect(x, y, winWidth, winHeight);

    var win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(
      frame,
      $.NSWindowStyleMaskBorderless,
      $.NSBackingStoreBuffered,
      false
    );

    win.setBackgroundColor(bgColor);
    win.setAlphaValue(0.95);
    win.setLevel($.NSStatusWindowLevel);

    // Only ignore mouse events when there's no click handler
    if (!clickHandler) {
      win.setIgnoresMouseEvents(true);
    }

    win.setCollectionBehavior(
      $.NSWindowCollectionBehaviorCanJoinAllSpaces |
      $.NSWindowCollectionBehaviorStationary
    );

    win.contentView.wantsLayer = true;
    win.contentView.layer.cornerRadius = 8;
    win.contentView.layer.masksToBounds = true;

    var contentView = win.contentView;

    // Left accent stripe — NSX brand color for notification type
    var stripe = $.NSBox.alloc.initWithFrame($.NSMakeRect(0, 0, stripeWidth, winHeight));
    stripe.setBoxType($.NSBoxCustom);
    stripe.setFillColor(accentColor);
    stripe.setBorderWidth(0);
    stripe.setTitlePosition($.NSNoTitle);
    contentView.addSubview(stripe);

    var textX = stripeWidth + 10, textWidth = winWidth - stripeWidth - 30;

    if (iconPath !== '' && $.NSFileManager.defaultManager.fileExistsAtPath(iconPath)) {
      var iconImage = $.NSImage.alloc.initWithContentsOfFile(iconPath);
      if (iconImage && !iconImage.isNil()) {
        var iconSize = 60;
        var iconView = $.NSImageView.alloc.initWithFrame(
          $.NSMakeRect(textX, (winHeight - iconSize) / 2, iconSize, iconSize)
        );
        iconView.setImage(iconImage);
        iconView.setImageScaling($.NSImageScaleProportionallyUpOrDown);
        contentView.addSubview(iconView);
        textX = textX + iconSize + 5;
        textWidth = winWidth - textX - 20;
      }
    }

    // Message label — vertically centered
    var font = $.NSFont.boldSystemFontOfSize(16);
    var textHeight = font.ascender - font.descender + font.leading + 4;
    var textY = (winHeight - textHeight) / 2;
    var label = $.NSTextField.alloc.initWithFrame(
      $.NSMakeRect(textX, textY, textWidth, textHeight)
    );
    label.setStringValue($(message));
    label.setBezeled(false);
    label.setDrawsBackground(false);
    label.setEditable(false);
    label.setSelectable(false);
    label.setTextColor($.NSColor.whiteColor);
    label.setAlignment($.NSTextAlignmentCenter);
    label.setFont(font);
    label.setLineBreakMode($.NSLineBreakByTruncatingTail);
    label.cell.setWraps(false);
    contentView.addSubview(label);

    // "click to focus" hint at bottom-right when click action is available
    if (clickHandler) {
      var hintFont = $.NSFont.systemFontOfSize(10);
      var hintLabel = $.NSTextField.alloc.initWithFrame(
        $.NSMakeRect(winWidth - 108, 7, 100, 14)
      );
      var hintText = (bundleId || idePid > 0) ? 'click to focus' : 'click to dismiss';
      hintLabel.setStringValue($(hintText));
      hintLabel.setBezeled(false);
      hintLabel.setDrawsBackground(false);
      hintLabel.setEditable(false);
      hintLabel.setSelectable(false);
      hintLabel.setTextColor($.NSColor.colorWithSRGBRedGreenBlueAlpha(1, 1, 1, 0.6));
      hintLabel.setAlignment($.NSTextAlignmentRight);
      hintLabel.setFont(hintFont);
      contentView.addSubview(hintLabel);

      // Transparent click-capture button (added last so it sits on top)
      var btn = $.NSButton.alloc.initWithFrame($.NSMakeRect(0, 0, winWidth, winHeight));
      btn.setTitle($(''));
      btn.setBordered(false);
      btn.setTransparent(true);
      btn.setTarget(clickHandler);
      btn.setAction('handleClick');
      contentView.addSubview(btn);
    }

    win.orderFrontRegardless;
    windows.push(win);
  }

  // Auto-dismiss timer (skip when persistent — dismiss on click only)
  if (dismiss > 0) {
    $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
      dismiss,
      $.NSApp,
      'terminate:',
      null,
      false
    );
  }

  $.NSApp.run;
}
