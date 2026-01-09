# EdaBoard

<p align="center">
  <img src="Gemini_Generated_Image_l32kdnl32kdnl32k.png" width="128" height="128" alt="EdaBoard Icon">
</p>

<p align="center">
  <strong>A native macOS clipboard manager that lives in your menu bar.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2026.0+-blue" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-6.0-orange" alt="Swift">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
</p>

---

## Features

- **Automatic Clipboard History** - Captures text, images, files, rich text, and URLs automatically
- **Instant Search** - Find any past clipboard item instantly with fuzzy search
- **Global Hotkey** - Access your clipboard history from anywhere with `⌘⇧V`
- **Pin Important Items** - Keep frequently used items at the top
- **Privacy First** - All data stored locally, sensitive content filtered automatically
- **Native macOS Experience** - Built with SwiftUI, follows system appearance

## Screenshots

*Coming soon*

## Installation

### Requirements

- macOS 26.0 (Tahoe) or later
- Apple Silicon (arm64)

### Download

Download the latest release from the [Releases](https://github.com/sadopc/edaboard/releases) page.

### Build from Source

```bash
# Clone the repository
git clone https://github.com/sadopc/edaboard.git
cd edaboard

# Build with Xcode
xcodebuild -scheme ClipVault -configuration Release build

# Or open in Xcode
open ClipVault.xcodeproj
```

## Usage

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘⇧V` | Show/hide EdaBoard |
| `⌘1-9` | Quick paste items 1-9 |
| `↑↓` | Navigate history |
| `↩` | Paste selected item |
| `⌥↩` | Paste as plain text |
| `⌘P` | Pin/unpin item |
| `⎋` | Dismiss |

### Permissions

EdaBoard requires **Accessibility** permission to:
- Register global hotkeys
- Simulate paste commands in other apps

On first launch, you'll be guided through granting the necessary permissions.

## Configuration

Access settings via the gear icon in the popover or through the menu bar.

- **History Limit** - Store up to 1000 items
- **Polling Interval** - Adjust how often clipboard is checked
- **Sensitive Content** - Filter passwords and auto-generated content
- **Ignored Apps** - Exclude specific apps from clipboard capture
- **Sound Effects** - Enable/disable paste sounds
- **Start at Login** - Launch automatically on login

## Privacy

EdaBoard is designed with privacy in mind:

- All data is stored **locally** on your Mac
- No cloud sync, no analytics, no tracking
- Sensitive content (passwords, auto-generated content) is automatically filtered
- You can exclude specific apps from being captured
- Clear history anytime with one click

## Tech Stack

- **Language**: Swift 6.0 with strict concurrency
- **UI**: SwiftUI with MenuBarExtra
- **Storage**: Core Data (SQLite) for metadata, file system for images
- **Architecture**: MVVM with actor-isolated services

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with SwiftUI and AppKit
- Icon created with AI assistance

---

<p align="center">
  Made with ❤️ for macOS
</p>
