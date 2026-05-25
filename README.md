# Crosshair

A tiny single-file macOS utility that draws a click-through crosshair (or dot) overlay at the center of your screen. Toggle it with a hotkey. Useful for windowed/borderless games that don't have a built-in crosshair — especially Minecraft when used alongside [SlackowWall](https://github.com/Slackow/SlackowWall).

## Features

- Single Swift file. No dependencies beyond the macOS SDK.
- Toggleable global hotkey (default: `;`).
- Click-through overlay that floats above other windows, including across Spaces and most fullscreen apps.
- **Auto-detects Minecraft window dimensions from SlackowWall** — zero configuration if you use it.
- Follows the frontmost Minecraft window across multiple monitors.
- Manual constants in source as an escape hatch for non-SlackowWall users.

---

## Install

### 1. Get the prerequisites

You need Apple's Xcode command line tools. If you've never run `git` or `swiftc` on this Mac, install them:

```sh
xcode-select --install
```

A small installer window will pop up — accept and let it finish. Skip this step if you already have them.

### 2. Clone

```sh
git clone https://github.com/chriswang06/crosshair.git
cd crosshair
```

### 3. Customize (optional)

Open `crosshair.swift` in any text editor and adjust the constants at the top:

- `useCrosshair` — `true` for a crosshair, `false` for a dot
- `dotColor` — e.g. `.systemRed`, `.systemGreen`, `.white`
- `dotSize`, `crosshairArm`, `crosshairThickness` — size in points
- `triggerKeyCode` — the hotkey (see [Picking a different hotkey](#picking-a-different-hotkey))
- Manual positioning constants — only needed if you don't use SlackowWall

If you skip this step, the defaults (red crosshair, hotkey `;`, SlackowWall auto-detect) will be used.

### 4. Build

```sh
./build_crosshair_app.sh
```

This produces `Crosshair.app` in the same directory.

### 5. Launch the app

```sh
open Crosshair.app
```

(Or double-click `Crosshair.app` in Finder.)

### 6. Grant Input Monitoring permission

The first time you launch, the hotkey won't do anything. macOS requires Input Monitoring permission for a global hotkey listener:

1. Open **System Settings → Privacy & Security → Input Monitoring**.
2. Click **`+`**, navigate to `Crosshair.app`, add it, and make sure the toggle is **on**.
3. Quit Crosshair (Dock → ⌘Q) and re-launch it. The permission only applies at launch.

### 7. Use it

Press `;` (or whatever hotkey you set) to toggle the dot on/off. That's it.

---

## Updating / changing settings

All settings are constants at the top of `crosshair.swift` (color, size, hotkey, dot vs crosshair, manual positioning overrides). To change them:

1. Edit the constants in `crosshair.swift`.
2. Run `./build_crosshair_app.sh` again.
3. **Important:** since rebuilds produce a new code signature, macOS forgets your permission grant. Go back to System Settings → Input Monitoring, remove `Crosshair`, then re-add the freshly built one.
4. Relaunch.

If you plan to rebuild a lot, see the [Avoiding the permission re-grant dance](#avoiding-the-permission-re-grant-dance) section below.

---

## SlackowWall integration

If you use [SlackowWall](https://github.com/Slackow/SlackowWall) for Minecraft speedrunning, Crosshair automatically reads your **Settings → Dimensions → Gameplay Mode** values (W, H, X, Y) and centers the crosshair inside that region. No editing required.

It works by reading:

- The active profile UUID from SlackowWall's preferences (`UserDefaults(suiteName: "com.slackow.SlackowWall")` key `currentProfileRawID`).
- The profile JSON at `~/Library/Application Support/SlackowWall/Profiles/<UUID>.json`, specifically `mode.baseMode`.

A file watcher reloads the dimensions whenever you save changes in SlackowWall, so you don't need to restart Crosshair after retuning your Gameplay Mode values. The hotkey itself never re-reads the file — it just shows/hides at the cached position. (Important if `;` is also a SlackowWall resize keybind; both apps see the keypress but neither steps on the other.)

If SlackowWall isn't installed or hasn't been configured, Crosshair falls back to centering on the full main display (or whatever you've put in the manual constants — see next section).

---

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

// Manual positioning (overrides SlackowWall when non-zero)
let targetScreenWidth: CGFloat = 0       // 0 = use main display
let manualWindowWidth: CGFloat = 0       // 0 = defer to SlackowWall or full screen
let manualWindowHeight: CGFloat = 0
let manualWindowX: CGFloat = 0
let manualWindowTopOffset: CGFloat = 0
```

**Positioning priority** (highest wins):

1. Explicit manual constants (if both width and height are non-zero)
2. SlackowWall config
3. Full main screen center

### Picking a different hotkey

`triggerKeyCode` accepts any `kVK_ANSI_*` constant from `Carbon.HIToolbox`. Examples:

- Letters: `kVK_ANSI_A` … `kVK_ANSI_Z`
- Numbers: `kVK_ANSI_0` … `kVK_ANSI_9`
- Others: `kVK_Space`, `kVK_Return`, `kVK_Escape`, `kVK_F1` … `kVK_F12`

Because the tap is `listenOnly`, your hotkey is *not* consumed — it still types normally and reaches other apps. Pick a key that doesn't interfere with what you're doing.

### Manual centering (no SlackowWall)

To pin the crosshair to a specific game window:

```swift
let manualWindowWidth: CGFloat = 1470
let manualWindowHeight: CGFloat = 858
let manualWindowX: CGFloat = 0
let manualWindowTopOffset: CGFloat = 33
```

---

## Avoiding the permission re-grant dance

Every rebuild of the app changes its code signature, which makes macOS think it's a new app and forget your permission grants. To avoid this, sign with a stable self-signed certificate.

### One-time setup

1. Open **Keychain Access** (Cmd-Space → "Keychain Access").
2. Menu bar → **Keychain Access → Certificate Assistant → Create a Certificate…**
3. Fill in:
   - **Name:** `Crosshair Self-Signed`
   - **Identity Type:** Self Signed Root
   - **Certificate Type:** Code Signing
   - Check **"Let me override defaults"**
4. Click through the rest accepting defaults. Store it in the **login** keychain.

That's it — the build script auto-detects this cert. From now on, rebuilds keep your permission grants.

---

## Quitting

- Click the Dock icon → Quit (⌘Q).
- Or from the terminal: `killall Crosshair`.

## Limitations

- Ad-hoc signing means TCC permissions don't survive rebuilds (workaround above).
- Settings are source-file constants; no in-app UI.

## License

MIT — see [LICENSE](LICENSE).
