# quickshell config

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE-MIT)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](LICENSE-APACHE)
[![Third-Party Notices](https://img.shields.io/badge/Third--Party-Notices-6c757d.svg)](THIRD_PARTY_NOTICES.md)

Personal QuickShell configuration for a Hyprland-based Wayland desktop.

## Features

- Workspace switcher overlay (multi-row layout, optional “Alt mode” for window icons, window drag-to-workspace)
- Task switcher overlay (live thumbnails, hover focus, keyboard cycling)
- OSDs: volume/mic, brightness, keyboard backlight
- Hyprland screenshot tools (region/window/screen) — based on a modified copy of [hyprquickshot][hyprquickshot] (see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md))
- Launcher + desktop indexer integration

## Requirements

- QuickShell
- Hyprland
- `hyprctl` available in `PATH`
- desktop-indexer (required by the launcher to index/search desktop entries and to launch apps): [desktop-indexer][desktop-indexer]

## Run

From this folder:

- `qs` (or your usual QuickShell entrypoint)

If you want to run a specific entry file:

- `qs -c shell.qml`

## Structure

- `shell.qml`: main entrypoint
- `config/`: theme + behavior settings
- `services/`: Hyprland data polling
- `widgets/`: shared UI components
- `workspace_switcher/`, `task_switcher/`: overlays
- `launcher/`, `hyprquickshot/`, `volume/`, `brightness/`, `battery/`: feature modules

## License

Dual-licensed under either:

- MIT — see [LICENSE-MIT](LICENSE-MIT)
- Apache-2.0 — see [LICENSE-APACHE](LICENSE-APACHE)

[desktop-indexer]: https://github.com/Jeremis70/desktop-indexer/tree/master
[hyprquickshot]: https://github.com/JamDon2/hyprquickshot
