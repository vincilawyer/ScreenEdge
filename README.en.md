# ScreenEdge · 跨屏边缘

A native macOS utility that highlights the screen edges your pointer can cross. Works alongside macOS extended displays and Apple Universal Control.

[中文说明](README.md) · [Download the latest release](https://github.com/vincilawyer/ScreenEdge/releases/latest) · [MIT license](LICENSE)

![ScreenEdge passage diagram](docs/images/passages.svg)

## Download and use

1. Download `ScreenEdge-1.3.0-macOS-arm64.zip` from [Releases](https://github.com/vincilawyer/ScreenEdge/releases/latest). The prebuilt app supports Apple Silicon Macs running macOS 13 or later.
2. Unzip it, move **跨屏边缘.app** to Applications, and open it. The app's interface is currently in Chinese.
3. Extended displays get blue/green gradients at their shared edges. Connected Universal Control passages get orange/red gradients.
4. Enable **靠近任意屏幕边缘时显示全部通道** to show every enabled passage when your pointer approaches any screen edge. Move away from all edges to hide them together.
5. Disable **显示菜单栏图标** to hide the menu bar icon. Open the app again to return to settings. Login launch is optional; keep the app in a permanent location before enabling it.

The download is ad-hoc signed and **not notarized by Apple**. macOS may ask you to approve it on first launch. See [Apple's official instructions for opening downloaded apps](https://support.apple.com/en-gb/102445); you can also build from source below.

## Behavior and limits

- Extended-display passages use public AppKit/CoreGraphics geometry. Matching gradient positions correspond across the overlapping edges, including different screen sizes and scaling settings.
- Universal Control uses a dynamically loaded, private, read-only Apple interface. It was tested on macOS 26.6.2; other versions may require manual fallback. See the [implementation notes](docs/universal-control.md).
- The remote screen in the preview is a **schematic destination**, not measured remote geometry. Remote screen names, full dimensions, and two-device color correspondence have not been verified.
- Another Mac needs its own copy of the app to draw its edges. This macOS app cannot run on an iPad.
- Overlays pass clicks through and do not intercept, inject, or move input. The app requests no Accessibility, Input Monitoring, or Screen Recording permission and makes no network requests.
- This branch adds optional post-login lock-screen overlays via a temporary SkyLight space, with a separate always-visible setting. Native simulated-transition checks pass; an actual lock/unlock cycle is still awaiting validation. Boot login, FileVault, exclusive display modes and other special surfaces are outside its scope. See [lock-screen notes](docs/lock-screen.md).

## Build

Requires macOS and Xcode Command Line Tools. No third-party runtime dependencies.

```sh
git clone https://github.com/vincilawyer/ScreenEdge.git
cd ScreenEdge
./scripts/test.sh
./scripts/build.sh
open "build/跨屏边缘.app"
```

The default target is Apple Silicon. For an Intel build, use `SCREENEDGE_ARCH=x86_64 ./scripts/build.sh`. This branch's mirror compatibility fix has been tested on Intel with macOS 15.7.9; it is not included in the existing v1.3.0 release archive.

With Python 3 available, run `./scripts/package.sh` to build a ZIP and SHA-256 checksum under `dist/`. Live overlay checks require a logged-in graphical macOS session:

```sh
"build/跨屏边缘.app/Contents/MacOS/ScreenEdge" --smoke-test
"build/跨屏边缘.app/Contents/MacOS/ScreenEdge" --uc-check
```

Preferences stay in the `local.screenedge.app` defaults domain and are not included in the repository or download. To remove the app, disable login launch if enabled, quit it, and remove the app bundle.

Bug reports and contributions are welcome. Include your macOS version, Mac architecture, and a schematic of your display arrangement; omit personal device identifiers and private diagnostics.
