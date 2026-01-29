# OpenMenu - Feature Requirements & Development Plan

## Project Overview

OpenMenu is a native macOS menu bar utility designed for solo developers to monitor and control their local OpenCode development server. The app serves as a "command center" that removes the need to keep a browser tab or terminal window pinned just to check server health.

---

## Technical Specifications

| Specification | Value |
|---------------|-------|
| **Framework** | SwiftUI |
| **Minimum macOS** | 14.0+ |
| **App Mode** | Background Agent (`LSUIElement = YES`) |
| **Networking** | URLSession (async/await) |
| **Default Server** | `http://127.0.0.1:4096` |

---

## Architecture

```
OpenMenu/
├── OpenMenuApp.swift          # App entry point with MenuBarExtra
├── Models/
│   ├── ServerStatus.swift     # Health response model
│   └── AppSettings.swift      # User preferences model
├── Services/
│   ├── HeartbeatService.swift # Networking & polling logic
│   └── SettingsManager.swift  # UserDefaults persistence
├── Views/
│   ├── MenuBarView.swift      # Main menu bar content
│   ├── SettingsWindow.swift   # Settings window view
│   └── Components/
│       ├── StatusIndicator.swift
│       └── ActionButton.swift
└── Resources/
    └── Assets.xcassets        # App icons
```

---

## Opencode API Reference

### Health Check Endpoint

```
GET http://127.0.0.1:4096/global/health
```

**Response:**
```json
{
  "healthy": true,
  "version": "1.0.0"
}
```

### Session Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/session/list` | List all sessions |
| GET | `/session/get?path={id}` | Get session details |
| POST | `/session/create` | Create new session |
| DELETE | `/session/delete?path={id}` | Delete session |

---

## Feature Requirements

### F1: Menu Bar Status Icon

**Priority:** High

- [ ] Dynamic SF Symbol icon reflecting server status
- [ ] Online state: `checkmark.circle.fill` (green tint)
- [ ] Offline state: `xmark.circle.fill` (red tint)
- [ ] Optional: Show status text alongside icon (configurable)

### F2: Heartbeat Monitor

**Priority:** High

- [ ] Periodic HTTP GET to `/global/health`
- [ ] Configurable interval: 5s, 10s, 30s (default: 10s)
- [ ] Non-blocking async/await networking
- [ ] Graceful error handling (network errors → offline status)
- [ ] Display server version when online

### F3: Quick Actions

**Priority:** High

#### F3.1: Open Portal
- [ ] Opens `http://127.0.0.1:4096` in default browser
- [ ] Uses `NSWorkspace.shared.open(url)`

#### F3.2: Copy Session ID
- [ ] Fetches current session from `/session/list`
- [ ] Copies session ID to system clipboard
- [ ] Shows brief confirmation feedback

#### F3.3: Restart Server
- [ ] Executes shell command in background
- [ ] Command: `opencode restart` (configurable)
- [ ] Non-blocking execution via `Process`

### F4: Settings Window

**Priority:** Medium

- [ ] Native macOS window with `.hiddenTitleBar` style
- [ ] Keyboard shortcut: `⌘,`

#### F4.1: Server Configuration
- [ ] Text field for server URL/port
- [ ] Default: `http://127.0.0.1:4096`
- [ ] URL validation before saving

#### F4.2: General Options
- [ ] "Launch at Login" toggle (via `SMAppService`)
- [ ] "Heartbeat Interval" dropdown (5s / 10s / 30s)

#### F4.3: Appearance
- [ ] "Show status text in menu bar" toggle

### F5: Design Language

**Priority:** Medium

- [ ] "Liquid Glass" effect using `.ultraThinMaterial` / `.thinMaterial`
- [ ] San Francisco system font throughout
- [ ] SF Symbols exclusively for icons
- [ ] High-breathing room spacing (16pt padding, 12pt gaps)
- [ ] Linear/Raycast-inspired minimal aesthetic

---

## Implementation Phases

### Phase 1: Project Configuration

| Task | Status |
|------|--------|
| Configure `Info.plist` with `LSUIElement = YES` | ⬜ |
| Add `com.apple.security.network.client` entitlement | ⬜ |
| Set deployment target to macOS 14.0+ | ⬜ |

### Phase 2: Networking & Heartbeat Service

| Task | Status |
|------|--------|
| Create `ServerStatus` model | ⬜ |
| Implement `HeartbeatService` with health check | ⬜ |
| Add timer-based polling with configurable interval | ⬜ |
| Handle network errors gracefully | ⬜ |

### Phase 3: Menu Bar UI

| Task | Status |
|------|--------|
| Replace `WindowGroup` with `MenuBarExtra` | ⬜ |
| Create dynamic status icon label | ⬜ |
| Build `MenuBarView` with status header | ⬜ |
| Apply `.menuBarExtraStyle(.window)` | ⬜ |
| Implement `.ultraThinMaterial` background | ⬜ |

### Phase 4: Quick Actions

| Task | Status |
|------|--------|
| Implement "Open Portal" action | ⬜ |
| Implement "Copy Session ID" action | ⬜ |
| Implement "Restart Server" action | ⬜ |

### Phase 5: Settings Window

| Task | Status |
|------|--------|
| Create `SettingsManager` with `@AppStorage` | ⬜ |
| Build `SettingsWindow` UI | ⬜ |
| Implement server URL configuration | ⬜ |
| Implement heartbeat interval picker | ⬜ |
| Implement "Launch at Login" via `SMAppService` | ⬜ |
| Implement appearance toggle | ⬜ |

### Phase 6: Polish

| Task | Status |
|------|--------|
| Add accessibility labels to all controls | ⬜ |
| Validate URL input in settings | ⬜ |
| Add keyboard shortcuts | ⬜ |
| Final UI polish and spacing adjustments | ⬜ |

---

## Key SwiftUI APIs

### MenuBarExtra (macOS 13+)

```swift
MenuBarExtra("Title", systemImage: "icon.name") {
    ContentView()
}
.menuBarExtraStyle(.window)  // Popover-style panel
```

### Materials

```swift
.background(.ultraThinMaterial)  // Liquid glass effect
.background(.thinMaterial)       // Slightly more opaque
```

### Settings Scene

```swift
Settings {
    SettingsView()
}
.windowStyle(.hiddenTitleBar)
```

### Launch at Login (macOS 13+)

```swift
import ServiceManagement

let service = SMAppService.mainApp
try service.register()    // Enable
try service.unregister()  // Disable
```

---

## Dependencies

- **None** - Pure SwiftUI + Foundation implementation
- No external packages required

---

## Entitlements Required

```xml
<!-- OpenMenu.entitlements -->
<key>com.apple.security.network.client</key>
<true/>
```

---

## References

- [Opencode API Documentation](https://github.com/sst/opencode)
- [SwiftUI MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [SF Symbols](https://developer.apple.com/sf-symbols/)
