#!/usr/bin/env osascript -l JavaScript
// mac-overlay.js — JXA Cocoa overlay notification for macOS
// Usage: osascript -l JavaScript mac-overlay.js <message> <color> <icon_path> <slot> <dismiss_seconds> [bundle_id]
//
// Creates a borderless, always-on-top overlay on every screen.
// Dismisses automatically after <dismiss_seconds> seconds.
// If bundle_id is provided, clicking the overlay activates that app (click-to-focus).

ObjC.import('Cocoa');

function run(argv) {
  var message  = argv[0] || 'peon-ping';
  var color    = argv[1] || 'red';
  var iconPath = argv[2] || '';
  var slot     = parseInt(argv[3], 10) || 0;
  var dismiss  = parseFloat(argv[4]) || 4;
  var bundleId = argv[5] || '';
  // argv[6] = ide_pid (reserved for future GUI IDE click-to-focus via NSRunningApplication(pid:))

  // Color map
  var r = 180/255, g = 0, b = 0;
  switch (color) {
    case 'blue':   r = 30/255;  g = 80/255;  b = 180/255; break;
    case 'yellow': r = 200/255; g = 160/255; b = 0;       break;
    case 'red':    r = 180/255; g = 0;       b = 0;       break;
  }

  var bgColor = $.NSColor.colorWithSRGBRedGreenBlueAlpha(r, g, b, 1.0);
  var winWidth = 500, winHeight = 80;

  $.NSApplication.sharedApplication;
  $.NSApp.setActivationPolicy($.NSApplicationActivationPolicyAccessory);

  // Register a click handler if we have a target bundle ID
  var clickHandler = null;
  if (bundleId) {
    ObjC.registerSubclass({
      name: 'PeonClickHandler',
      superclass: 'NSObject',
      methods: {
        'handleClick': {
          types: ['void', []],
          implementation: function() {
            var ws = $.NSWorkspace.sharedWorkspace;
            var apps = ws.runningApplications;
            var count = apps.count;
            for (var i = 0; i < count; i++) {
              var app = apps.objectAtIndex(i);
              var bid = app.bundleIdentifier;
              if (!bid.isNil() && bid.js === bundleId) {
                app.activateWithOptions($.NSApplicationActivateIgnoringOtherApps);
                break;
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

    var yOffset = 40 + slot * 90;
    var x = visibleFrame.origin.x + (visibleFrame.size.width - winWidth) / 2;
    var y = visibleFrame.origin.y + visibleFrame.size.height - winHeight - yOffset;
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
    win.contentView.layer.cornerRadius = 12;
    win.contentView.layer.masksToBounds = true;

    var contentView = win.contentView;
    var textX = 10, textWidth = winWidth - 30;

    if (iconPath !== '' && $.NSFileManager.defaultManager.fileExistsAtPath(iconPath)) {
      var iconImage = $.NSImage.alloc.initWithContentsOfFile(iconPath);
      if (iconImage && !iconImage.isNil()) {
        var iconSize = 60;
        var iconView = $.NSImageView.alloc.initWithFrame(
          $.NSMakeRect(10, (winHeight - iconSize) / 2, iconSize, iconSize)
        );
        iconView.setImage(iconImage);
        iconView.setImageScaling($.NSImageScaleProportionallyUpOrDown);
        contentView.addSubview(iconView);
        textX = 10 + iconSize + 5;
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
      hintLabel.setStringValue($('click to focus'));
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

  // Auto-dismiss timer
  $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
    dismiss,
    $.NSApp,
    'terminate:',
    null,
    false
  );

  $.NSApp.run;
}
