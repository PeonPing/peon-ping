#!/usr/bin/env osascript -l JavaScript
// mac-overlay.js — JXA Cocoa overlay notification for macOS
// Usage: osascript -l JavaScript mac-overlay.js <message> <color> <icon_path> <slot> <dismiss_seconds> [bundle_id] [ide_pid] [session_tty] [subtitle] [position] [notify_type] [all_screens] [screen_index]
//
// Creates a borderless, always-on-top overlay. Shows on all screens by default,
// or on a specific screen when screen_index is provided, or on the focused screen when all_screens is disabled in config.
// Dismisses automatically after <dismiss_seconds> seconds (0 = persistent until clicked).
// If bundle_id is provided, clicking the overlay activates that app (click-to-focus).
// position: top-center (default), top-right, top-left, bottom-right, bottom-left, bottom-center

ObjC.import('Cocoa');

function run(argv) {
  var message  = argv[0] || 'peon-ping';
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
  var allScreens  = argv[11] === 'true';
  var screenIdx   = (argv[12] !== undefined && argv[12] !== '') ? parseInt(argv[12], 10) : -1;
  var env = $.NSProcessInfo.processInfo.environment;
  var clickCommandValue = env.objectForKey($('PEON_CLICK_COMMAND'));
  var clickCommand = clickCommandValue && !clickCommandValue.isNil() ? ObjC.unwrap(clickCommandValue) : '';
  var cmuxFocusHelperValue = env.objectForKey($('PEON_CMUX_FOCUS_HELPER'));
  var cmuxFocusCliValue = env.objectForKey($('PEON_CMUX_FOCUS_CLI'));
  var cmuxFocusSocketValue = env.objectForKey($('PEON_CMUX_FOCUS_SOCKET'));
  var cmuxFocusWorkspaceValue = env.objectForKey($('PEON_CMUX_FOCUS_WORKSPACE'));
  var cmuxFocusSurfaceValue = env.objectForKey($('PEON_CMUX_FOCUS_SURFACE'));
  var cmuxFocusHelper = cmuxFocusHelperValue && !cmuxFocusHelperValue.isNil() ? ObjC.unwrap(cmuxFocusHelperValue) : '';
  var cmuxFocusCli = cmuxFocusCliValue && !cmuxFocusCliValue.isNil() ? ObjC.unwrap(cmuxFocusCliValue) : '';
  var cmuxFocusSocket = cmuxFocusSocketValue && !cmuxFocusSocketValue.isNil() ? ObjC.unwrap(cmuxFocusSocketValue) : '';
  var cmuxFocusWorkspace = cmuxFocusWorkspaceValue && !cmuxFocusWorkspaceValue.isNil() ? ObjC.unwrap(cmuxFocusWorkspaceValue) : '';
  var cmuxFocusSurface = cmuxFocusSurfaceValue && !cmuxFocusSurfaceValue.isNil() ? ObjC.unwrap(cmuxFocusSurfaceValue) : '';

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

  var persistent = dismiss <= 0;

  // Generate unique notification ID for all sibling overlays (all-screens mode)
  // All overlays with the same slot will coordinate dismissal
  var dismissNotificationName = 'com.peonping.dismiss.' + slot;

  // Register a click handler if we have a target bundle ID, IDE PID, or persistent mode
  var clickHandler = null;
  if (bundleId || idePid > 0 || persistent) {
    function activateBundle(targetBundleId) {
      if (!targetBundleId) return false;
      var ws = $.NSWorkspace.sharedWorkspace;
      var apps = ws.runningApplications;
      var count = apps.count;
      for (var i = 0; i < count; i++) {
        var app = apps.objectAtIndex(i);
        var bid = app.bundleIdentifier;
        if (!bid.isNil() && bid.js === targetBundleId) {
          app.activateWithOptions($.NSApplicationActivateIgnoringOtherApps);
          return true;
        }
      }
      return false;
    }

    function runClickCommand(command) {
      if (!command) return false;
      try {
        var task = $.NSTask.alloc.init;
        task.setLaunchPath($('/bin/bash'));
        task.setArguments($(['-lc', command]));
        task.launch;
        task.waitUntilExit;
        return task.terminationStatus === 0;
      } catch(e) {
        return false;
      }
    }

    function runCmuxFocusTask() {
      if (!cmuxFocusHelper || !cmuxFocusCli || !cmuxFocusSurface) return false;
      try {
        var args = [cmuxFocusCli];
        if (cmuxFocusSocket) args.push(cmuxFocusSocket);
        if (cmuxFocusWorkspace) args.push(cmuxFocusWorkspace);
        args.push(cmuxFocusSurface);
        var task = $.NSTask.alloc.init;
        task.setLaunchPath($(cmuxFocusHelper));
        task.setArguments($(args));
        task.launch;
        task.waitUntilExit;
        return task.terminationStatus === 0;
      } catch (e) {
        return false;
      }
    }

    ObjC.registerSubclass({
      name: 'PeonClickHandler',
      superclass: 'NSObject',
      methods: {
        'handleClick:': {
          types: ['void', ['id']],
          implementation: function(_sender) {
            if (cmuxFocusHelper && cmuxFocusCli && cmuxFocusSurface) {
              activateBundle(bundleId);
              runCmuxFocusTask();
              $.NSDistributedNotificationCenter.defaultCenter.postNotificationNameObject($(dismissNotificationName), $.NSString.string);
              $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
                0.05, $.NSApp, 'terminate:', null, false
              );
              return;
            }

            if (clickCommand) {
              activateBundle(bundleId);
              runClickCommand(clickCommand);
              $.NSDistributedNotificationCenter.defaultCenter.postNotificationNameObject($(dismissNotificationName), $.NSString.string);
              $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
                0.05, $.NSApp, 'terminate:', null, false
              );
              return;
            }

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
              // Signal ALL sibling overlays to dismiss (event-driven, no polling!)
              $.NSDistributedNotificationCenter.defaultCenter.postNotificationNameObject($(dismissNotificationName), $.NSString.string);
              // Small delay to ensure notification is delivered before we terminate
              $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
                0.05, $.NSApp, 'terminate:', null, false
              );
              return;
            }
            var activated = false;
            // Primary: activate by bundle ID
            if (bundleId) activated = activateBundle(bundleId);
            // Fallback: activate by IDE PID (for embedded terminals)
            if (!activated && idePid > 0) {
              var ideApp = $.NSRunningApplication.runningApplicationWithProcessIdentifier(idePid);
              if (ideApp && !ideApp.isNil()) {
                ideApp.activateWithOptions($.NSApplicationActivateIgnoringOtherApps);
              }
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

            // Signal ALL sibling overlays to dismiss
            $.NSDistributedNotificationCenter.defaultCenter.postNotificationNameObject($(dismissNotificationName), $.NSString.string);
            // Small delay to ensure notification is delivered before we terminate
            $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
              0.05, $.NSApp, 'terminate:', null, false
            );
          }
        }
      }
    });
    clickHandler = $.PeonClickHandler.alloc.init;
  }

  var screens = $.NSScreen.screens;
  var screenCount = screens.count;
  var windows = [];

  // Determine which screen(s) to display on
  var startIdx = 0, endIdx = screenCount;
  if (screenIdx >= 0 && screenIdx < screenCount) {
    // Specific screen requested (multi-process mode from notify.sh)
    startIdx = screenIdx;
    endIdx = screenIdx + 1;
  } else if (!allScreens) {
    // Single-screen mode: find screen where mouse cursor is
    var mouseLocation = $.NSEvent.mouseLocation;
    var focusedIdx = 0;
    for (var s = 0; s < screenCount; s++) {
      var scr = screens.objectAtIndex(s);
      var sf = scr.frame;
      if (mouseLocation.x >= sf.origin.x && mouseLocation.x <= sf.origin.x + sf.size.width &&
          mouseLocation.y >= sf.origin.y && mouseLocation.y <= sf.origin.y + sf.size.height) {
        focusedIdx = s; break;
      }
    }
    startIdx = focusedIdx;
    endIdx = focusedIdx + 1;
  }

  for (var i = startIdx; i < endIdx; i++) {
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
      btn.setAction('handleClick:');
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

  // Event-driven dismissal: observe distributed notifications from sibling overlays
  // No polling! All overlays with the same slot will dismiss when any one is clicked.
  ObjC.registerSubclass({
    name: 'PeonDismissObserver',
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
  var observer = $.PeonDismissObserver.alloc.init;
  $.NSDistributedNotificationCenter.defaultCenter.addObserverSelectorNameObject(
    observer,
    'handleDismiss:',
    $(dismissNotificationName),
    $.NSString.string
  );

  $.NSApp.run;
}
