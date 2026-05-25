# Crosshair

A tiny single-file macOS utility that draws a click-through crosshair (or dot) overlay at a fixed screen position. Toggle it with a hotkey. Useful for windowed/borderless games that don't have a built-in crosshair — especially Minecraft when used alongside [SlackowWall](https://github.com/Slackow/SlackowWall).

## Features

- One Swift file, ~180 lines. No dependencies beyond the macOS SDK.
- Toggleable global hotkey (default: `;`).
- Click-through overlay that floats above other windows, including across Spaces and most fullscreen apps.
- **Auto-detects Minecraft window dimensions from SlackowWall** — zero configuration if you use it.
- Manual constants in source as an escape hatch for non-SlackowWall users.

## Build & install

Requires the Xcode command line tools:

```sh
xcode-select --install     # if you don't already have them
```

Then:

```sh
git clone https://github.com/chriswang06/crosshair.git
cd crosshair
./build_crosshair_app.sh
open Crosshair.app
```

You can also run the source directly without building an app:

```sh
swift crosshair.swift
```

In script mode, the parent terminal needs the TCC permissions (see below) and the app exits when you Ctrl-C or close the terminal.

## Permissions

`Crosshair` uses a `CGEventTap` to listen for the hotkey globally. macOS requires **both** of these for that to work:

1. System Settings → **Privacy & Security → Accessibility** → add `Crosshair.app`, toggle on.
2. System Settings → **Privacy & Security → Input Monitoring** → add `Crosshair.app`, toggle on.

**Important:** the build is ad-hoc signed, which means each rebuild produces a new code-signing identity. macOS treats the rebuilt app as a *different* app, so after every rebuild you have to **remove the old entry** from both lists and re-add the freshly built `Crosshair.app`. If you don't, the hotkey will silently do nothing.

## SlackowWall integration

If you use [SlackowWall](https://github.com/Slackow/SlackowWall) for Minecraft speedrunning, Crosshair automatically reads your **Settings → Dimensions → Gameplay Mode** values (W, H, X, Y) and centers the crosshair inside that region. No editing of `crosshair.swift` required.

It works by reading:

- The active profile UUID from SlackowWall's `UserDefaults` (`com.slackow.SlackowWall` / `currentProfileRawID`).
- The profile JSON at `~/Library/Application Support/SlackowWall/Profiles/<UUID>.json`, specifically the `mode.baseMode` object.

A file watcher reloads the dimensions whenever you save changes in SlackowWall, so you don't need to restart Crosshair after retuning your Gameplay Mode values. The hotkey itself never re-queries — it just shows/hides the overlay at the cached position. That matters because `;` is also commonly a SlackowWall resize keybind; you don't want both apps doing redundant work on each press.

If SlackowWall is not installed or has no profile, Crosshair falls back to centering on the full main display (or whatever you've put in the manual constants — see next section).

## Configuration

All settings are constants at the top of `crosshair.swift`:

```swift
// Appearance
let useCrosshair: Bool = true       // false = solid dot
let dotColor: NSColor = .systemRed
let dotSize: CGFloat = 12           // dot diameter (points)
let crosshairArm: CGFloat = 10
let crosshairThickness: CGFloat = 2

// Hotkey
let triggerKeyCode: Int64 = Int64(kVK_ANSI_Semicolon)

// Manual positioning (overrides SlackowWall config when non-zero)
let targetScreenWidth: CGFloat = 0       // 0 = use main display
let manualWindowWidth: CGFloat = 0       // 0 = defer to SlackowWall or full screen
let manualWindowHeight: CGFloat = 0
let manualWindowX: CGFloat = 0
let manualWindowTopOffset: CGFloat = 0
```

**Priority order** for positioning: explicit manual constants → SlackowWall config → full main screen.

Edit, rebuild (`./build_crosshair_app.sh`), and re-grant TCC permissions as described above.

### Picking a different hotkey

`triggerKeyCode` accepts any `kVK_ANSI_*` constant from `Carbon.HIToolbox`. Examples:

- Letters: `kVK_ANSI_A` … `kVK_ANSI_Z`
- Numbers: `kVK_ANSI_0` … `kVK_ANSI_9`
- Others: `kVK_Space`, `kVK_Return`, `kVK_Escape`, `kVK_F1` … `kVK_F12`

Because the tap is `listenOnly`, your hotkey is *not* consumed — it still types into whatever app is focused, and other apps (like SlackowWall) still receive it.

### Manual centering without SlackowWall

If you want to pin the crosshair to a game window without SlackowWall, set:

```swift
let manualWindowWidth: CGFloat = 1470
let manualWindowHeight: CGFloat = 858
let manualWindowX: CGFloat = 0
let manualWindowTopOffset: CGFloat = 33
```

The overlay will then center inside that virtual rectangle.

## Quitting

- Click the Dock icon → Quit (`⌘Q`).
- Or from the terminal: `killall Crosshair`.

## Limitations

- macOS only.
- No menu-bar or preferences UI — everything is in source constants.
- Position math assumes a single intended target display. Multi-monitor setups work but only one display gets the overlay.
- Ad-hoc signing means TCC permissions don't survive rebuilds. If this becomes annoying, you'll want a paid Apple Developer ID.

## License

MIT — see [LICENSE](LICENSE).
