# Kettle

A native macOS GUI for Homebrew — manage packages, casks, taps, and services without touching the terminal.

![macOS 15.4+](https://img.shields.io/badge/macOS-15.4%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) [![GitHub release](https://img.shields.io/github/v/release/Geoion/Kettle)](https://github.com/Geoion/Kettle/releases/latest) [![License](https://img.shields.io/github/license/Geoion/Kettle)](LICENSE)

## Features

- Browse and manage installed Homebrew **Packages** (formulae) — view version, description, dependencies; update or uninstall with one click
- Browse and manage installed **Casks** — view details and uninstall
- Manage **Taps** — view repository, branch, HEAD commit, file count and size; add or remove taps
- Manage **Services** — start and stop services, view configuration files in form or raw XML view
- **Settings** — system status (CPU, Homebrew version, install path), preferences (language, appearance, default apps), tap export, `brew doctor` diagnostics, and auto-update
- Automatic cache for taps, packages, casks, and services — fast startup without waiting for Homebrew
- Auto-update: checks GitHub Releases on launch, shows changelog, one-click download
- 5 languages: English, Simplified Chinese, Traditional Chinese, Japanese, Korean
- Light / Dark / System appearance

## Requirements

- macOS 15.4 or later
- [Homebrew](https://brew.sh/) installed

## Installation

### Homebrew (Recommended)

```bash
brew tap Geoion/tap
brew install --cask kettle
```

If macOS Gatekeeper blocks the app on first launch, run:

```bash
xattr -cr /Applications/Kettle.app
```

### Direct Download

Download the latest DMG from the [Releases](https://github.com/Geoion/Kettle/releases) page, open it, and drag Kettle to your Applications folder.

### Build from Source

Requires Xcode 15+.

```bash
git clone https://github.com/Geoion/Kettle.git
cd Kettle
open Kettle.xcodeproj
```

## Usage

1. Launch **Kettle** from your Applications folder
2. If Homebrew is not installed, Kettle will offer to install it
3. Select a section from the sidebar — Taps, Packages, Casks, or Services
4. Click any row to expand and view details or perform actions
5. Use the toolbar buttons to refresh or add items

## Changelog

### v1.1.0

- **Packages**: full metadata (version, description, homepage, license, tap, install date, disk size), outdated badge with version comparison, one-click Upgrade All, filter by outdated
- **Casks**: full metadata, app icons in list rows, outdated badge, fixed Open button path
- **Services**: search bar, Restart button, PID display, config arrays fully expanded, XML view without height limit
- **Settings**: full backup export, individual package/cask/tap exports, new Cleanup tab (`brew cleanup` + `brew autoremove`)
- **Homebrew install**: now available via `brew install --cask kettle`
- Bug fixes: casks not loading, last-updated time not showing, `Settings` naming conflict

### v1.0.8

- Enhanced DMG creation and build process
- Improved versioning in Info.plist with fallback mechanisms

### v1.0.4

- **Auto-update**: automatic version checks, update notifications, one-click DMG download

### v1.0.3

- Enhanced service detail panel with XML view and segmented control for form/XML switching

### v1.0.1

- Enhanced tap addition dialog with real-time command preview, log display, and cancel support
- Improved input validation for tap names

### v1.0.0

- Initial release: package, cask, tap, and service management
- Multi-language support (5 languages), light/dark theme, `brew doctor` diagnostics, tap export

## License

MIT
