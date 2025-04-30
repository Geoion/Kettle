# Kettle Changelog

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
