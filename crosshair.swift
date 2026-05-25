import Cocoa
import Carbon.HIToolbox

// ---- Config ----
// Appearance
let useCrosshair: Bool = true                  // false = solid dot, true = crosshair
let dotColor: NSColor = .systemRed
let dotSize: CGFloat = 6                      // dot diameter (points)
let crosshairArm: CGFloat = 5                 // crosshair arm length per side
let crosshairThickness: CGFloat = 2

// Hotkey (see Carbon.HIToolbox for kVK_ANSI_* codes)
let triggerKeyCode: Int64 = Int64(kVK_ANSI_Semicolon)

// Manual positioning overrides. All zero by default; non-zero values take
// priority over SlackowWall config. Useful when you don't run SlackowWall.
let targetScreenWidth: CGFloat = 0             // 0 = use main display
let manualWindowWidth: CGFloat = 0             // 0 = defer to SlackowWall or full screen
let manualWindowHeight: CGFloat = 0            // 0 = defer to SlackowWall or full screen
let manualWindowX: CGFloat = 0                 // window x offset from screen origin (top-left)
let manualWindowTopOffset: CGFloat = 0         // window y offset from top of screen
// ----------------

struct GameplayDimensions {
    let width: CGFloat
    let height: CGFloat
    let x: CGFloat
    let y: CGFloat
}

/// Reads SlackowWall's saved "Gameplay Mode" dimensions.
/// See https://github.com/Slackow/SlackowWall — config lives at
/// ~/Library/Application Support/SlackowWall/Profiles/<UUID>.json
/// Active profile UUID is in `UserDefaults(suiteName: "com.slackow.SlackowWall")`
/// under key `currentProfileRawID`.
enum SlackowWallConfig {
    static let bundleID = "com.slackow.SlackowWall"
    static let profileKey = "currentProfileRawID"

    static func profileURL() -> URL? {
        guard let uuid = UserDefaults(suiteName: bundleID)?.string(forKey: profileKey),
              !uuid.isEmpty else { return nil }
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return appSupport
            .appendingPathComponent("SlackowWall")
            .appendingPathComponent("Profiles")
            .appendingPathComponent("\(uuid).json")
    }

    static func loadGameplayDimensions() -> GameplayDimensions? {
        guard let url = profileURL(),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mode = json["mode"] as? [String: Any],
              let base = mode["baseMode"] as? [String: Any],
              let w = (base["width"] as? NSNumber)?.doubleValue,
              let h = (base["height"] as? NSNumber)?.doubleValue,
              w > 0, h > 0
        else { return nil }
        let x = (base["x"] as? NSNumber)?.doubleValue ?? 0
        let y = (base["y"] as? NSNumber)?.doubleValue ?? 0
        return GameplayDimensions(width: CGFloat(w), height: CGFloat(h),
                                  x: CGFloat(x), y: CGFloat(y))
    }
}

var currentDimensions: GameplayDimensions? = SlackowWallConfig.loadGameplayDimensions()
var profileWatcher: DispatchSourceFileSystemObject?

/// Finds the NSScreen currently containing the frontmost Minecraft window.
/// Returns nil if no MC window is found. Reads only window owner name + bounds,
/// which do not require Screen Recording permission.
func findMinecraftScreen() -> NSScreen? {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]],
          let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero })
                        ?? NSScreen.screens.first
    else { return nil }

    // Windows are returned front-to-back, so the first match is frontmost.
    for window in windows {
        let owner = (window[kCGWindowOwnerName as String] as? String) ?? ""
        let layer = (window[kCGWindowLayer as String] as? Int) ?? -1
        guard layer == 0 else { continue }
        let isMC = owner.lowercased() == "java" || owner.lowercased().contains("minecraft")
        guard isMC else { continue }
        guard let rawBounds = window[kCGWindowBounds as String] else { continue }
        let boundsDict = rawBounds as! CFDictionary
        guard let bounds = CGRect(dictionaryRepresentation: boundsDict),
              bounds.width > 100, bounds.height > 100
        else { continue }

        // CGWindowBounds is top-left origin relative to the primary display.
        // Convert window center to Cocoa bottom-left coords for NSScreen lookup.
        let centerXGlobal = bounds.midX
        let centerYCocoa = primary.frame.height - bounds.midY
        let point = NSPoint(x: centerXGlobal, y: centerYCocoa)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) {
            return screen
        }
    }
    return nil
}

func startWatchingSlackowWallConfig() {
    guard let url = SlackowWallConfig.profileURL() else { return }
    let fd = open(url.path, O_EVTONLY)
    guard fd >= 0 else { return }
    let src = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: fd,
        eventMask: [.write, .extend, .rename, .delete],
        queue: .main)
    src.setEventHandler {
        currentDimensions = SlackowWallConfig.loadGameplayDimensions()
        // Editors often replace the file rather than writing in place, so
        // re-attach on delete/rename.
        let mask = src.data
        if mask.contains(.delete) || mask.contains(.rename) {
            src.cancel()
            // Re-arm after a brief delay to let the new file land.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                startWatchingSlackowWallConfig()
            }
        }
    }
    src.setCancelHandler { close(fd) }
    src.resume()
    profileWatcher = src
}

startWatchingSlackowWallConfig()

final class DotView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        dotColor.setFill()
        if useCrosshair {
            let cx = bounds.midX, cy = bounds.midY
            let h = NSRect(x: cx - crosshairArm, y: cy - crosshairThickness/2,
                           width: crosshairArm*2, height: crosshairThickness)
            let v = NSRect(x: cx - crosshairThickness/2, y: cy - crosshairArm,
                           width: crosshairThickness, height: crosshairArm*2)
            NSBezierPath(rect: h).fill()
            NSBezierPath(rect: v).fill()
        } else {
            NSBezierPath(ovalIn: bounds).fill()
        }
    }
}

final class Overlay {
    private var window: NSWindow?
    private(set) var visible = false

    func toggle() { visible ? hide() : show() }

    func show() {
        // Priority: live MC window location > configured screen width > main screen.
        let screen: NSScreen? = findMinecraftScreen()
            ?? (targetScreenWidth > 0
                ? NSScreen.screens.first(where: { $0.frame.width == targetScreenWidth })
                : nil)
            ?? NSScreen.main
        guard let screen = screen else { return }
        let frame = screen.frame
        let side = useCrosshair ? max(crosshairArm*2, crosshairThickness) : dotSize

        // Resolve dimensions: explicit manual overrides > SlackowWall > full screen.
        let w: CGFloat
        let h: CGFloat
        let xOffset: CGFloat
        let yOffset: CGFloat

        if manualWindowWidth > 0 && manualWindowHeight > 0 {
            w = manualWindowWidth
            h = manualWindowHeight
            xOffset = manualWindowX
            yOffset = manualWindowTopOffset
        } else if let dims = currentDimensions {
            w = dims.width
            h = dims.height
            xOffset = dims.x
            yOffset = dims.y
        } else {
            w = frame.width
            h = frame.height
            xOffset = 0
            yOffset = 0
        }

        let centerXFromLeft = xOffset + w / 2
        let centerYFromTop  = yOffset + h / 2

        let globalX = frame.origin.x + centerXFromLeft
        let globalY = frame.origin.y + frame.height - centerYFromTop

        let rect = NSRect(x: globalX - side/2,
                          y: globalY - side/2,
                          width: side, height: side)
        let win = NSWindow(contentRect: rect, styleMask: .borderless,
                           backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .screenSaver
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        win.hasShadow = false
        win.contentView = DotView(frame: NSRect(origin: .zero, size: rect.size))
        win.orderFrontRegardless()
        window = win
        visible = true
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        visible = false
    }
}

let overlay = Overlay()

let eventMask = (1 << CGEventType.keyDown.rawValue)
let tapCallback: CGEventTapCallBack = { _, type, event, _ in
    if type == .keyDown {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        if keyCode == triggerKeyCode && !isRepeat {
            DispatchQueue.main.async { overlay.toggle() }
        }
    }
    return Unmanaged.passUnretained(event)
}

guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                  place: .headInsertEventTap,
                                  options: .listenOnly,
                                  eventsOfInterest: CGEventMask(eventMask),
                                  callback: tapCallback,
                                  userInfo: nil) else {
    fputs("Crosshair: failed to create event tap. Grant Input Monitoring permission and re-launch.\n", stderr)
    exit(1)
}
let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.run()
