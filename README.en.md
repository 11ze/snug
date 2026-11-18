<div align="center">

[简体中文](README.md) · **English**

<img src="Assets/AppIcon/AppIcon-1024.png" width="128" alt="Snug icon">

# Snug

**Make UU Remote Native on Any Device**

Built for UU Remote · Display and touch enhancements for your remote Mac<br>A screen that fits every device · Native touch gestures · App Library

[![Latest release](https://img.shields.io/github/v/release/zephyr4123/snug?label=release&color=blue)](https://github.com/zephyr4123/snug/releases/latest) ![Apple Silicon · Intel](https://img.shields.io/badge/Apple%20Silicon%20%C2%B7%20Intel-Universal-success) ![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Notarized](https://img.shields.io/badge/Apple-Notarized-black?logo=apple) [![License MIT](https://img.shields.io/badge/License-MIT-green)](LICENSE)

[Download](#-download) · [Native Experience](#-native-on-every-device) · [Every Device](#-one-mac-every-device) · [App Library](#-app-library) · [Screenshots](#-screenshots) · [Comparison](#-compared-with-alternatives) · [Installation](#-installation) · [Usage](#-usage) · [Limitations](#-known-limitations) · [Development](#-development)

<br>

<img src="https://dl.zephyrxiang.com/snug/media/hero-architecture.0ee41447.png" width="92%" alt="Diagram: Snug creates a screen on the Mac for each phone, tablet, and computer, delivered through UU Remote to fill each device">
<p><sub>▶ <a href="https://dl.zephyrxiang.com/snug/media/phone-demo.a97e46d1.mp4">Watch the HD demo video</a></sub></p>

</div>

> Snug continues [aoyamashou/UUyc-companion](https://github.com/aoyamashou/UUyc-companion) (UU Remote Companion by AoyamaShou, MIT License), with the original author's copyright notices and commit history fully preserved. Since version 2.0, it has been redesigned around the phone screen; since 2.6, it extends to tablets and computers.

## 📥 Download

<img src="Assets/AppIcon/AppIcon-1024.png" width="88" align="left" alt="Snug icon">

**Snug for macOS** [![Latest release](https://img.shields.io/github/v/release/zephyr4123/snug?label=release&color=blue)](https://github.com/zephyr4123/snug/releases/latest)<br>A single universal package for Apple silicon and Intel, running on macOS 14 or later<br>Signed and notarized by Apple; simply drag it into Applications

<br clear="left">

| Source | Notes | Download |
| :--- | :--- | :--- |
| **China mirror** | Served via Tencent Cloud CDN; recommended in mainland China | [Snug.dmg](https://dl.zephyrxiang.com/snug/latest/Snug.dmg) |
| **GitHub Releases** | Release notes, checksums, and previous versions | [Go to Releases](https://github.com/zephyr4123/snug/releases/latest) |

Both sources provide the identical package. Install Snug only on the Mac being controlled; the controlling device needs nothing but UU Remote.

> On Windows? Community ports are available; see [Community Ports](#-community-ports) below.

## ✨ Native on Every Device

UU Remote scales your entire desktop proportionally to fit the controlling device: mismatched proportions leave black bars, and text and controls shrink along with it. Snug adds a screen with matching proportions for each controlling device. On phones and tablets, windows fill the screen at a mobile scale and touch follows mobile conventions; on computers, the resolution matches the device itself and the picture fills the screen with no black bars.

### Phone: Portrait · Landscape

<p align="center"><img src="https://dl.zephyrxiang.com/snug/media/compare-uu-original.cf4158d1.png" width="36%" alt="UU Remote alone: the whole desktop squeezed onto the phone"> <img src="https://dl.zephyrxiang.com/snug/media/phone-claude-code.93e21d9d.png" width="36%" alt="With Snug: the window fills the screen with larger text"><br><sub>Same content · Left: UU Remote alone · Right: with Snug</sub></p>

- **Portrait and landscape**: proportions calculated from your phone model, leaving room for UU Remote's toolbar, in 2x HiDPI; landscape suits code, terminals, and wide pages
- **Full-screen windows**: the selected window takes over the entire screen
- **Larger text**: Ghostty, Terminal, iTerm2, VS Code, Cursor, and Zed enlarge their text automatically, remembered per app

<p align="center"><img src="https://dl.zephyrxiang.com/snug/media/phone-landscape-web.a1670af8.png" width="72%" alt="iPhone in landscape: a web page shown in full, with UU Remote's toolbar on the right"><br><sub>Landscape: wide pages shown in full</sub></p>

### Native Gestures

UU Remote's mobile client carries over trackpad gesture conventions. On phone and tablet screens, Snug reinterprets them the way touchscreens are meant to be used.

| Touch | UU Remote alone | Snug |
| :--- | :--- | :--- |
| One-finger swipe | Mouse drag, often selecting text by accident | Scrolls, with momentum after release |
| Long-press, then drag | Mouse drag | Selects text |
| Long-press, then release | Regular click | Opens the context menu |

<p align="center"><img src="https://dl.zephyrxiang.com/snug/media/phone-demo.2cee4e81.webp" width="30%" alt="Live demo: opening a window, typing commands on the pop-up keyboard, resuming a session, one-finger scrolling, returning to the list"> <img src="https://dl.zephyrxiang.com/snug/media/phone-context-menu.997dd70f.png" width="30%" alt="Long-press context menu"><br><sub>One-finger scrolling · Long-press context menu</sub></p>

- Applies only within phone and tablet screens; other displays and the Mac's own trackpad and mouse are unaffected

### Tablet: Full Screen · Native Gestures

Controlling a Mac from a tablet used to call for an external keyboard and trackpad. Snug's tablet screen fills the display according to your tablet model, ready for touch.

- **Landscape and portrait**: proportions calculated from your tablet model, filling the screen
- **Native gestures**: the same as on the phone; scrolling, right-clicking, and selecting text all work by touch, with no external trackpad needed
- **Comfortable text size**: slightly larger than the tablet's native size, easy on the eyes over long sessions
- **Two columns**: in landscape, the App Library splits into an apps column and a windows column; see [App Library](#-app-library)

<p align="center"><img src="https://dl.zephyrxiang.com/snug/media/ipad-landscape-vscode.7524622f.png" width="56%" alt="iPad in landscape: VS Code fills the screen with larger text"> <img src="https://dl.zephyrxiang.com/snug/media/ipad-portrait-safari.22fa3ccc.png" width="27%" alt="iPad in portrait: Safari fills the screen"><br><sub>iPad · Landscape · Portrait</sub></p>

### Computer: Full Screen · No Black Bars

Snug's computer screen is created at the controlling computer's resolution, so what you see matches the computer itself.

> Removing black bars when remoting from a computer comes from Snug's predecessor, [UUyc-companion](https://github.com/aoyamashou/UUyc-companion) (UU Remote Companion by AoyamaShou). Snug carries the capability forward as an extra screen: your existing displays stay as they are, and the main display is unchanged by default.

<p align="center"><img src="https://dl.zephyrxiang.com/snug/media/macbook-uu-original.4c593493.png" width="46%" alt="UU Remote alone on a MacBook Air: the 4K display's picture with black bars above and below, and smaller text"> <img src="https://dl.zephyrxiang.com/snug/media/macbook-snug.32bf15ab.png" width="46%" alt="Snug computer screen on a MacBook Air: the same window fills the screen, with text at its native size"><br><sub>Same window · Left: UU Remote alone · Right: Snug computer screen</sub></p>

- **Native resolution**: default resolutions for the whole Mac lineup and common computer resolutions are built in, Windows PCs included; enter your own if yours isn't listed
- **Pixel for pixel**: on a MacBook with a notch, the top strip is left free and the picture isn't scaled
- **Computer controls kept as they are**: no gesture translation and no text enlargement; the mouse and trackpad work as usual
- **Set as main display** (optional, off by default; chosen at the bottom of the Screens page in Settings): UU Remote always starts each connection on the main display. Make this screen the main display and every connection lands on it, with the menu bar, the Dock, and the windows from the original main display moving over, so you pick up right where you left off; the main display and arrangement are put back when the session ends, even if Snug quits unexpectedly
- **App Library**: open it from the menu bar to bring windows from other screens to this one, and put them back with one click; see [App Library](#-app-library)

## 🧩 One Mac, Every Device

The Screens page of Snug's settings is the screen list: choose the device, model, and orientation for each screen, and turn each one on or off, up to 4.

| Screen | Proportions and size | On screen |
| :--- | :--- | :--- |
| Phone · portrait / landscape | Calculated from your phone model, leaving room for UU Remote's toolbar | App Library, home indicator, native gestures, larger text |
| Tablet · landscape / portrait | Calculated from your tablet model, with text slightly larger than native | Same as above; landscape uses two columns |
| Computer · landscape | Matches the controlling computer's resolution; on a MacBook with a notch it leaves the top strip free, pixel for pixel | Nothing added, just like an ordinary display |

<p align="center"><img src="https://dl.zephyrxiang.com/snug/media/settings-screens-remote.4475b8da.png" width="43%" alt="The Screens page of Snug's settings during a session: the screen list and Set as main display"> <img src="https://dl.zephyrxiang.com/snug/media/uu-screen-list.a161e201.png" width="46%" alt="UU Remote's screen menu listing four Snug screens"><br><sub>Left: the screen list in Snug's settings · Right: the screen list in UU Remote during a session</sub></p>

- **Switch devices, no setup**: UU Remote lets only one device control a Mac at a time; when you switch to another device, just choose its screen in UU Remote. Turn off the screens you aren't using; screens that are off aren't created during a session
- **Set as main display** (optional, off by default): any Snug screen can be the main display, so every connection lands on it; see [Computer](#computer-full-screen--no-black-bars)
- **Mac mini and Mac Studio without a display**: Snug's screen takes over from the system's default screen, giving you a full desktop at the controlling device's resolution
- **Model library**: 785 phones and 46 tablets across 19 brands are built in (every iPhone from iPhone 8 on, and mainstream Android models from Huawei, Xiaomi, OPPO, vivo, Samsung, and more, with the inner and outer screens of foldables listed separately), along with 13 Macs and 9 common computer resolutions; for a model that isn't listed, enter its resolution or aspect ratio

<p align="center"><img src="https://dl.zephyrxiang.com/snug/media/phone-models.391e818d.png" width="36%" alt="Model page: the current model, a custom resolution, and models listed by brand"><br><sub>Models: listed by brand, or enter a custom resolution</sub></p>

## 🗂 App Library

The home page of phone and tablet screens (「App 资源库」), for managing your Mac's apps from the device in your hand: find, open, switch, create, close, and quit, without going back to your desk. On computer screens, open the App Library from the menu bar.

- **Running** (「运行中」): each running app has its own card, with its windows listed beneath it. Every window is here, whichever display or Space it's on, even full-screen or minimized
- **All** (「全部」): a grid of every app on your Mac, sorted by name; tap an app that isn't running to launch it
- **Search**: matches app names and window titles, in Chinese, English, full pinyin, or pinyin initials, so "bwl" finds Notes (「备忘录」)

<p align="center"><img src="https://dl.zephyrxiang.com/snug/media/phone-app-library.865fc506.png" width="30%" alt="Running: the app whose window is on the phone screen is listed first"> <img src="https://dl.zephyrxiang.com/snug/media/phone-all-apps.7d4ada60.png" width="30%" alt="All: a grid of every app on the Mac"> <img src="https://dl.zephyrxiang.com/snug/media/phone-search.d365e194.png" width="30%" alt="Search: typing bwl finds Notes"><br><sub>Running · All · Searching by pinyin initials</sub></p>

- **Two columns**: on landscape phones and tablets, the left column lists apps and the right column lists the selected app's windows

<p align="center"><img src="https://dl.zephyrxiang.com/snug/media/phone-landscape-library.30220d6f.png" width="54%" alt="iPhone in landscape: the App Library lists apps on the left and the selected app's windows on the right"> <img src="https://dl.zephyrxiang.com/snug/media/ipad-landscape-library.b0f8b829.png" width="39%" alt="iPad in landscape: the App Library lists apps on the left and the selected app's windows on the right"><br><sub>Two columns · Landscape phone · Tablet</sub></p>

- **Computer screens**: there is no library panel; open the App Library window from the menu bar instead. It shows which screen each window is on, full-screen windows included, brings any window to this screen with one click, and puts the windows it brought back with one click. When the remote side can't see the other screens or drag windows across, this is how windows come over and go back

<p align="center"><img src="https://dl.zephyrxiang.com/snug/media/mac-library.796eed17.png" width="60%" alt="The App Library on a computer screen: which screen each window is on, one click to bring a window over, one click to put back the ones brought over"><br><sub>Computer screen: the App Library opened from the menu bar</sub></p>

| Action | How |
| :--- | :--- |
| Open a window | Tap a window to fill the screen; tap an app to open its most recently used window |
| New window | Tap "New Window" on the app's card; the new window opens at the screen's width |
| Close a window | Tap the close button next to the window, then tap again to confirm |
| Quit an app | Tap "Quit" on the app's card, then tap again to confirm; if it hasn't quit after 10 seconds, you can force quit it |
| Save unsaved changes | The save prompt that appears when closing or quitting shows up on the current screen, so you can answer it from your device |
| Exit this screen | Tap "Exit This Screen" at the top right, then tap again to confirm; windows return to where they were and this screen is removed for the rest of this session. It comes back next session (reconnecting within 15 seconds of disconnecting still counts as this session) |

### Works Like an iPhone

| iPhone | Snug phone and tablet screens |
| :--- | :--- |
| App Library | The home page: find, open, and manage the apps on your Mac |
| Home indicator | Bottom indicator bar, returning to the App Library |
| "‹ Back" in the top-left corner | "‹ App name" in the top-left corner, returning to the current window |

### Every App Works and Fills the Screen

Snug brings the Mac's windows themselves to the screen, so every app works as it is, with no tie to any AI vendor: Claude Code in a terminal and Codex in the ChatGPT desktop app work just as they do at your desk.

Some apps enforce a minimum width and can't shrink to the screen's width. Snug first fits the window to the screen's width; if the app won't go any narrower, it switches the screen to a resolution just wide enough to hold it, then fills the screen again.

- Every window is shown in full, never partly cut off
- The picture scales proportionally without distortion, and taps land exactly where you expect
- Text in such windows is slightly smaller; pinch to zoom on your device

<p align="center"><img src="https://dl.zephyrxiang.com/snug/media/phone-chatgpt.a28ef053.png" width="36%" alt="Codex in the ChatGPT desktop app, filling the Snug phone screen"> <img src="https://dl.zephyrxiang.com/snug/media/phone-fit-settings.4e526ad6.png" width="36%" alt="System Settings, which enforces a minimum width, filling the phone screen completely"><br><sub>Left: Codex in the ChatGPT desktop app (file links redacted) · Right: System Settings enforces a minimum width, yet still fills the screen completely</sub></p>

## 📸 Screenshots

Available on phone and tablet screens. Turn on Screenshot (「截图」) on the Touch page (「触控」) of Snug's settings, and a camera button appears on the left of the bottom indicator bar. Tap it to capture the window filling the screen and copy it to the Mac's clipboard, ready to paste into any app. You get the window's native pixels, unaffected by remote image compression.

- **Crop**: after a capture, a thumbnail appears in the bottom-left corner; tap it to crop. The whole image is selected by default — drag a corner or edge inward, then tap Done (「完成」) to replace the screenshot in the clipboard with the selection
- **Permission**: requires the separate Screen & System Audio Recording permission (Screen Recording on macOS 14); click Authorize… (「授权…」) on the General page (「通用」) of Settings, then reopen Snug when macOS asks. It is independent of the Accessibility permission
- **Off by default**: when it is off, the indicator bar shows no camera button and no recording permission is needed

<p align="center"><img src="https://dl.zephyrxiang.com/snug/media/phone-screenshot-thumbnail.3dfb4e94.png" width="30%" alt="A thumbnail appears in the bottom-left corner after a capture"> <img src="https://dl.zephyrxiang.com/snug/media/phone-screenshot-crop.0bd33902.png" width="30%" alt="Cropping: drag a corner or edge inward to narrow the selection"><br><sub>Left: the thumbnail after a capture · Right: tap it to crop</sub></p>

## 🆚 Compared with Alternatives

| Approach | Limitation | Snug |
| :--- | :--- | :--- |
| **Remote control in AI assistants** | Limited to that vendor's own AI sessions | Works with any terminal or app; see [Every App](#every-app-works-and-fills-the-screen) |
| **UU Remote's built-in terminal** | Separate from local terminals; processes linger after disconnecting | Uses the terminal windows already open on your Mac |
| **Display emulators and virtual display tools** | One screen, one set of proportions, so switching devices brings back black bars; no touch gestures or window management | A screen that fits each device; native gestures and the App Library on phones and tablets |

- **Remote control in AI assistants**: for example, Claude Remote Control and Codex in ChatGPT, each tied to a single product
- **UU Remote's built-in terminal**: runs in UU Remote's own tmux, so work in progress on your Mac (such as Claude Code running in your terminal) cannot be picked up there

## 📦 Installation

> **Requirements**: macOS 14 or later on the Mac being controlled, with [UU Remote](https://uuyc.163.com/) installed; the controlling device can be any phone, tablet, or computer with UU Remote installed.

**Download and install (recommended)**

1. Get the installer from the [Download](#-download) section (the China mirror is recommended in mainland China)
2. Drag Snug into Applications and open it
3. Grant the Accessibility permission when the welcome window prompts you (the setting was renamed in macOS 27)

Snug then stays in the menu bar; no further setup is needed. Open Snug again at any time to bring up Settings.

**Updates**: Snug checks at launch and installs new versions with one click, keeping your settings and permissions. You can also check manually or switch the update source on the General page (「通用」) of Settings. Versions before 2.1.0 must be replaced manually.

<div align="center">
<img src="https://dl.zephyrxiang.com/snug/media/welcome.d538a8c3.png" width="30%" alt="Welcome window: how it works and the Accessibility permission"> <img src="https://dl.zephyrxiang.com/snug/media/settings-screens.694e6c80.png" width="30%" alt="The Screens page of Settings: the screen list and Set as main display"> <img src="https://dl.zephyrxiang.com/snug/media/settings-general.4e8bfc2c.png" width="30%" alt="The General page of Settings: launch at login, permissions, and software update">
<p><sub>Welcome window · Settings: Screens · Settings: General</sub></p>
</div>

**Build from source** (requires Xcode and Swift 6)

```bash
git clone https://github.com/zephyr4123/snug.git
cd snug && scripts/snug install
```

<details>
<summary>Migrating from UU Remote Companion</summary>

Running both at the same time causes conflicts, so Snug prompts you to quit the old app at launch. If you enabled its watchdog helper, also run:

```bash
launchctl bootout gui/$(id -u)/com.corndog.uudisplay.watchdog-agent
rm ~/Library/LaunchAgents/com.corndog.uudisplay.watchdog-agent.plist
```

</details>

## 🧭 Usage

1. **Add screens** (as needed): by default there is a single portrait screen, "Snug 手机屏" (Snug Phone Screen). For a tablet, a computer, or a landscape phone, add a screen on the Screens page of Settings and choose its model
2. **Switch screens**: once connected, choose the matching screen in UU Remote's screen list
3. **Pick an app or window**: on phone and tablet screens, tap an app or window in the App Library and it fills the screen; on computer screens, open the App Library from the menu bar
4. **Switch windows**: tap the bottom indicator bar to return to the App Library; choosing another window returns the previous one to its place
5. **End the session**: windows return to their original positions, text sizes are restored, and Snug's screens are removed; if you set a main display, the main display and arrangement are put back too

> 💡 Set UU Remote's picture quality to the highest: at lower quality the picture looks blurry, especially on a tablet.

## 🔒 Isolation and Restoration

- **Only Snug's screens are touched**: no display is turned off and no other window is touched; when you are not on a Snug screen, UU Remote behaves exactly as it always has. The main display stays as it is unless you turn on "Set as main display", and it is put back when the session ends
- **Cleared before removal**: windows opened directly on a Snug screen are moved back to the main display before the screen is removed, instead of being pushed into a corner
- **Record first, then change**: each window's original position and text size are recorded in advance, so they can be restored even if Snug quits unexpectedly
- **Restored even when a window is closed directly**: if you close a window directly on your device, the next time the app opens it at the Snug screen's size, Snug moves it back and restores its text size
- **Unresponsive apps are left as they are**: if an app stops responding, Snug does not force its window to move and explains why on screen
- **No data collection**: apart from checking for updates, Snug connects to no servers and collects no data; screenshots only go to the Mac's clipboard and are not kept

## 🚧 Known Limitations

| Limitation | Details |
| :--- | :--- |
| Relies on undocumented macOS APIs | May break after a major macOS update |
| UU Remote lets only one device control a Mac at a time | Switch between screens as you switch devices; several devices can't remote in at once |
| UU Remote always starts each connection on the main display | Choose the screen once in the screen list; with "Set as main display", every connection lands on that screen |
| UU Remote on a Mac lists at most 5 screens | The Mac's own displays included; when remoting from a Mac, turn off the Snug screens you aren't using |
| A screen doesn't rotate between portrait and landscape | Add one of each if you use both, and switch in UU Remote when you turn the device |
| Not an official NetEase product | Unaffiliated with UU Remote or its developer; UU Remote updates may affect some features |
| A Snug screen may occasionally remain after a session ends | Occurs when the system log misses the end of the stream; the menu bar still shows the session as active (「远程中」). Turn off the screens that are on in Settings to restore |
| VS Code and Cursor may remember the enlarged text size if a window is closed on your device with a shortcut or menu | If the text looks too large when you reopen it after the session, press ⌘- to restore it (the screen shows how many steps when the window closes). With gestures on, tapping the window's own close button, or closing it from the App Library, is not affected |
| On a Mac with no display attached, you can't switch back to the original screen | macOS provides a default screen only when no display is connected, and removes it as soon as a Snug screen appears. Exit that screen from the top right of the App Library, or turn it off in Settings, to get the original screen back |

The technical reasons behind each limitation are explained in [How It Works](docs/how-it-works.md#已知限制的技术原因) (in Chinese).

## 🔧 Development

```bash
scripts/snug check     # build and run all tests
scripts/snug install   # build, install, and launch
```

- The code is organized in three layers: `SnugCore` (pure logic) → `SnugSystem` (system interfaces) → `Snug` (UI)
- Packaging, releases, launch arguments, and data locations: [Development guide](docs/development.md) (in Chinese)
- Connection detection, window placement, and gesture translation: [How It Works](docs/how-it-works.md) (in Chinese)

## 🧹 Uninstall

1. Quit Snug from the menu bar (windows are restored first)
2. Move Snug from Applications to the Trash
3. Optional: remove its settings and logs with `rm -rf ~/Library/Application\ Support/Snug ~/Library/Logs/Snug.log*`
4. Optional: remove Snug from Accessibility in System Settings, and from Screen & System Audio Recording if you turned on Screenshot

## 🌐 Community Ports

| Platform | Project | Maintainer | Notes |
| :--- | :--- | :--- | :--- |
| Windows 10 / 11 | [snug-win](https://github.com/nicocart/snug-win) | [nicocart](https://github.com/nicocart) | Ported from Snug 2.5.0; C# / .NET 8 / WPF |
| Windows x64 | [Snug for Windows](https://github.com/rizetngan/snug-for-windows) | [rizetngan](https://github.com/rizetngan) | Ported from Snug 2.5.0; C# / .NET 10 / WPF; community preview, no official release yet |

Community ports are developed, released, and maintained independently by their authors. This repository develops and tests the macOS version only and has not tested these ports; please report any issues to the corresponding repository.

## 🙏 Acknowledgments

First and foremost, we extend our sincere respect to **[UU Remote](https://uuyc.163.com/)**.

- **Exceptional quality**: stable connections, responsive control, and freely adjustable image quality and frame rate. Remote control spans encoding, transport, and connectivity across networks, among many other engineering challenges; reaching a standard that everyday work can depend on is a formidable technical achievement in its own right.
- **Entirely free**: a product with so high a technical barrier remains free for everyone. That goes well beyond generosity; it is a genuine gift to the entire remote-access ecosystem. This openness is what allows the community to keep building on it, from companion apps and one-finger scrolling to virtual displays, and Snug grew from it as well.

With heartfelt thanks.

We are equally grateful to the following projects and contributors:

- [UUyc-companion](https://github.com/aoyamashou/UUyc-companion) (MIT): by AoyamaShou, Snug's predecessor
- [Better Remote](https://github.com/pincc-debug/better-remote) (MIT): by pincc-debug, the approach to one-finger scrolling in UU Remote
- [PermissionFlow](https://github.com/jaywcjlove/PermissionFlow) (MIT): by jaywcjlove (小弟调调), the permission onboarding and drag-to-authorize panel
- [FreeDisplay](https://github.com/huberdf/FreeDisplay) (MIT): by huberdf, the `CGVirtualDisplay` interface declarations
- Community PR authors: bubble, gencheng liu, and Rongzheng Liu (#10, reading UU Remote windows in full-screen Spaces)
- The virtual display implementation draws on [DeskPad](https://github.com/Stengo/DeskPad), [Side Screen](https://github.com/tranvuongquocdat/SideScreen), and Chromium

## ⭐ Star History

<p align="center"><a href="https://www.star-history.com/#zephyr4123/snug&Date"><picture><source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=zephyr4123/snug&type=Date&theme=dark"><source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=zephyr4123/snug&type=Date"><img src="https://api.star-history.com/svg?repos=zephyr4123/snug&type=Date" width="80%" alt="Snug's GitHub stars over time"></picture></a></p>

## 📄 License

[MIT](LICENSE) © 2026 AoyamaShou, © 2026 zephyr4123
