# ⚡ Portkey (macOS Menu Bar Port Manager)

**Portkey** is a native, ultra-lightweight macOS menu bar application designed for developers to effortlessly monitor, manage, inspect, and free up network ports (`localhost`, `127.0.0.1`, `0.0.0.0`, `192.168.x.x`, `[::1]`, etc.).

Built with **Swift & SwiftUI** for macOS 14+ (Sonoma, Sequoia, and beyond), Portkey runs with near-zero resource consumption (<20 MB RAM) without any Electron overhead.

---

## ✨ Features

- 🟢 **Real-Time Port Discovery:**
  - Instantly lists all listening TCP & UDP sockets.
  - Automatically identifies process name, PID, user, binding address, and full command line arguments.
  - Smart categorization: Web & Dev servers (`node`, `python`, `bun`, `next`, `vite`, `rails`), Databases (`postgres`, `mysql`, `redis`, `mongo`), Containers (`docker`, `colima`), and macOS System daemons.
  
- ⚡ **One-Click Port Freeing:**
  - Instant process termination (`SIGTERM` with escalation to `SIGKILL`).
  - "Kill All Dev Servers" bulk action to clean up multiple running projects simultaneously.
  - Graceful fallback with authorization prompt if elevated permissions are required.

- ⚪ **Dormant & Saved Presets:**
  - Track common developer ports (`:3000`, `:5432`, `:8000`, `:6379`, `:8080`, etc.) to see at a glance whether expected services are running or free.
  - Add custom presets with expected process names and descriptions.

- 🌐 **Developer Quick Actions:**
  - **Open in Browser:** One-click to open `http://localhost:<port>` or `http://<ip>:<port>`.
  - **Copy Details:** Copy URLs, port numbers, PIDs, full command strings, or `kill -9 <PID>` commands to clipboard.
  - **Inspect & Reveal:** Inspect process executable paths and reveal them directly in macOS Finder.
  - **Favorites:** Star frequently used ports to pin them at the top.

- ⚙️ **Customizable Preferences:**
  - Auto-refresh frequency (1s, 2s, 5s, 10s, or manual).
  - Hide macOS system daemons by default.
  - Optional confirmation prompts before killing processes.
  - Native Launch at Login support via `SMAppService`.

---

## 🚀 Quick Start

### Build & Run
To compile and assemble the native macOS app:

```bash
# Build the release .app bundle
./Scripts/build_app.sh release

# Launch Portkey
open Portkey.app
```

You can also move `Portkey.app` into `/Applications`:
```bash
cp -r Portkey.app /Applications/
```

### Running from Command Line / Xcode
```bash
# Run in development mode
swift run

# Run unit tests
swift test
```

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `⌘R` | Refresh listening ports immediately |
| `⌘,` | Open Preferences |
| `⌘Q` | Quit Portkey |

---

## 🏗️ Architecture

```
Sources/Portkey/
├── PortkeyApp.swift               # @main SwiftUI MenuBarExtra app entrypoint & NSApp accessory setup
├── Models/
│   ├── PortItem.swift             # Model for active listening ports (PID, port, proto, binding, category)
│   ├── PortPreset.swift           # Model for saved & dormant port presets
│   └── FilterOptions.swift        # Filtering categories and sorting options
├── Services/
│   ├── PortScanner.swift          # High-performance lsof & libproc socket parser with diffing
│   ├── ProcessManager.swift       # Graceful SIGTERM/SIGKILL termination, URL opener, clipboard, login item
│   └── PresetManager.swift        # Preset persistence & dormant port evaluation
└── Views/
    ├── MainMenuBarView.swift      # Popover UI with header, filters, active list, and actions
    ├── PortRowView.swift          # Individual port card with quick actions and expandable inspector
    ├── DormantPortRowView.swift   # Row component for dormant / preset ports
    ├── AddPresetView.swift        # Modal to configure custom port presets
    ├── SettingsView.swift         # Preferences sheet
    └── Components/
        ├── SearchField.swift      # macOS search bar
        └── StatusBadge.swift      # Protocol and address badges
```

---

## 🧪 Testing

Run the test suite:
```bash
swift test
```

---

## 📄 License
MIT License.
