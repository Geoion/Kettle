# Kettle Changelog

## Version 1.1.0 (2026-03-03)

### ✨ New Features

#### Packages
- Full package info via `brew info --json=v2`: version, description, homepage, license, tap, install date, disk size
- Outdated badge with version comparison (`1.2.3 → 1.3.0`)
- One-click **Upgrade All** button when outdated packages exist
- Filter to show only outdated packages
- Dependency packages labeled with `Dependency` tag

#### Casks
- Full cask info: version, description, homepage, tap, install path, disk size, auto-updates flag
- App icons displayed in list rows
- Outdated version comparison badge
- Fixed Open button to use actual installed path

#### Services
- Added search bar
- Added **Restart** button for running services
- Shows PID when available
- Config panel: array values fully expanded (no truncation)
- XML view: full content displayed without height limit

#### Settings
- **Export**: full backup (packages + casks + taps + services), plus individual exports for each type
- **Cleanup tab**: preview and run `brew cleanup` to free disk space; preview and run `brew autoremove` to remove unused dependencies
- **Status tab**: shows installed counts for packages, casks, taps, services, and outdated items

### 🔧 Improvements
- Rewrote UI following macOS native design patterns (FrameworkScanner style)
- All list views: expandable rows with inline detail panels instead of split-view detail columns
- Last refresh time shown in footer of every list view
- Localization system aligned with FrameworkScanner: global `L()` function with dynamic bundle switching
- All 5 languages (en, zh-Hans, zh-Hant, ja, ko) fully updated with new strings

### 🐛 Bug Fixes
- Fixed casks not loading (`brew info --json=v2 --cask --installed` unsupported; now uses `brew list --cask` + batch info query)
- Fixed last-updated time never showing in footer
- Fixed `enum Settings` naming conflict with SwiftUI `Settings` scene

---

## Version 1.0.8 (2025-04-30)

### 🔧 Improvements
- Enhanced DMG creation and build process
  - Improved versioning in Info.plist
  - Added fallback mechanisms for build failures
  - Creates more visually appealing DMG with Applications folder link

### 🛠️ Technical Updates
- Updated GitHub Actions to latest versions (upload-artifact v4)
- Improved release workflow automation and reliability

## Version 1.0.7 (2025-04-30)

### 🔧 Improvements
- Enhanced release workflow for better automation
- Added permissions for repository content writing
- Improved DMG artifact management

## Version 1.0.6 (2025-04-30)

### 🛠️ Technical Updates
- Simplified release creation process
- Streamlined workflow by removing redundant checks
- Direct creation of GitHub releases

## Version 1.0.5 (2025-04-30)

### 🔧 Improvements
- Enhanced macOS release workflow
- Dynamic Info.plist updating for correct versioning
- Added robustness to build and DMG creation process

## Version 1.0.4 (2025-04-30)

### ✨ New Features
- Added auto-update functionality
  - Automatic checks for new versions
  - User notifications for available updates
  - One-click update download

### 🛠️ Technical Updates
- Improved build and packaging process
- Automatic DMG creation and GitHub Release publishing

## Version 1.0.3 (2025-04-30)

### ✨ New Features
- Added iOS app icons
- Included script to generate correctly sized icons

### 🔧 Improvements
- Enhanced service detail panel with XML view
- Added segmented control for form/XML view switching
- Improved error handling and feedback

## Version 1.0.2 (2024-04-28)

### 🔧 Improvements
- Enhanced UI for better user experience
- Improved error handling system-wide
- Optimized performance for larger brew installations

## Version 1.0.1 (2025-04-27)

### 🔧 Improvements

#### Tap Management
- Enhanced tap addition dialog with improved UI
- Added real-time command preview for tap operations
- Added log display for tap operations
- Added ability to cancel ongoing tap operations
- Improved input validation for tap names (user/repo format)
- Added optional URL support for custom tap repositories

### 🐛 Bug Fixes
- Fixed layout issues in tap management dialogs
- Improved error handling for tap operations
- Added proper process termination for brew commands


## Version 1.0.0 (2025-04-27)

### 🎉 Major Features

#### Package Management
- View and manage installed Homebrew packages
- Real-time display of package versions, dependencies, and descriptions
- Package search functionality

#### Tap Management
- View and manage Homebrew Taps
- Display Tap installation status and repository URLs
- Support for adding and removing Taps
- Open Tap directory in Finder
- Access Tap source code repositories

#### Service Management
- Manage Homebrew Services
- Display service status (running, stopped, error, etc.)
- Start/Stop service operations
- View service configurations
- Show service user and file path information

#### System Features
- Multi-language interface (English, Simplified Chinese, Traditional Chinese, Japanese, Korean)
- Light/Dark theme support with system preference integration
- Configurable default file manager and editor
- System status monitoring including:
  - CPU model information
  - Homebrew installation status
  - Homebrew version information
  - Core and Cask status

#### Backup & Restore
- Export Tap list to JSON file
- Backup and restore Homebrew configurations

#### Diagnostic Tools
- Built-in `brew doctor` diagnostics
- Detailed diagnostic reports and problem-solving suggestions

### 💻 System Requirements
- macOS 15.4 or later
- Homebrew installed

### 🔧 Installation
1. Download the latest version of Kettle.app
2. Drag the application to Applications folder
3. Grant necessary system permissions on first launch

### 📝 Notes
- Some features may require administrator privileges
- Regular configuration backup is recommended

### 🤝 Feedback & Support
- GitHub Repository: https://github.com/Geoion/kettle
- Issue Reporting: eski.yin@gmail.com

---
Made with ❤️ by Geoion
