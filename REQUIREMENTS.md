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
├── ContentView.swift          # Unused - can be removed
├── Models/
│   ├── ServerStatus.swift     # Health response model
│   ├── AppSettings.swift      # User preferences model
│   ├── Session.swift          # Session model for session list
│   ├── Project.swift          # Project and VCS info models
│   ├── Provider.swift         # Provider and model info models
│   └── Tool.swift             # LSP, MCP, Formatter status models
├── Services/
│   ├── HeartbeatService.swift # Networking & polling logic
│   ├── SettingsManager.swift  # UserDefaults persistence (via @AppStorage)
│   ├── QuickActionsService.swift # Portal, restart, session actions
│   ├── TaskCompletionMonitor.swift # SSE event monitoring for task completion
│   ├── NotificationService.swift # macOS notifications
│   ├── ProjectService.swift   # Project and VCS API client
│   ├── SessionService.swift   # Full session management API client
│   ├── ProviderService.swift  # Provider and model API client
│   ├── ToolService.swift      # LSP, MCP, Formatter status API
│   └── APIService.swift       # Generic OpenCode API client
├── Views/
│   ├── MenuBarView.swift      # Main menu bar content
│   ├── SettingsWindow.swift   # Settings window view
│   ├── Components/
│   │   ├── StatusIndicator.swift
│   │   ├── ActionButton.swift
│   │   ├── SessionRow.swift
│   │   └── ProjectCard.swift
│   └── Sheets/
│       ├── CreateSessionSheet.swift
│       ├── SessionDetailSheet.swift
│       └── ProviderStatusSheet.swift
└── Resources/
    └── Assets.xcassets        # App icons
```

---

## OpenCode Server API Reference

### Global Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/global/health` | Get server health and version |
| GET | `/global/event` | Get global events (SSE stream) |

### Project Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/project` | List all projects |
| GET | `/project/current` | Get the current project |
| GET | `/path` | Get the current path |
| GET | `/vcs` | Get VCS info for the current project |

### Session Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/session` | List all sessions |
| POST | `/session` | Create a new session |
| GET | `/session/status` | Get session status for all sessions |
| GET | `/session/:id` | Get session details |
| DELETE | `/session/:id` | Delete a session |
| PATCH | `/session/:id` | Update session properties |
| POST | `/session/:id/fork` | Fork an existing session |
| POST | `/session/:id/abort` | Abort a running session |
| POST | `/session/:id/share` | Share a session |
| DELETE | `/session/:id/share` | Unshare a session |
| GET | `/session/:id/todo` | Get todo list for a session |
| POST | `/session/:id/init` | Analyze app and create AGENTS.md |

### Provider & Model Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/provider` | List all providers |
| GET | `/config/providers` | List providers and default models |
| GET | `/provider/auth` | Get provider authentication methods |

### Tool Status Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/lsp` | Get LSP server status |
| GET | `/formatter` | Get formatter status |
| GET | `/mcp` | Get MCP server status |

### Agent Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/agent` | List all available agents |

### Events

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/event` | Server-sent events stream |

---

## Feature Requirements

### F1: Menu Bar Status Icon

**Priority:** High

- [x] Dynamic SF Symbol icon reflecting server status
- [x] Online state: `checkmark.circle.fill` (green tint)
- [x] Offline state: `xmark.circle.fill` (red tint)
- [x] Optional: Show status text alongside icon (configurable)

### F2: Heartbeat Monitor

**Priority:** High

- [x] Periodic HTTP GET to `/global/health`
- [x] Configurable interval: 5s, 10s, 30s (default: 10s)
- [x] Non-blocking async/await networking
- [x] Graceful error handling (network errors → offline status)
- [x] Display server version when online

### F3: Quick Actions

**Priority:** High

#### F3.1: Open Portal
- [x] Opens `http://127.0.0.1:4096` in default browser
- [x] Uses `NSWorkspace.shared.open(url)`

#### F3.2: Copy Session ID
- [x] Fetches current session from `/session`
- [x] Copies session ID to system clipboard
- [x] Shows brief confirmation feedback

#### F3.3: Restart Server
- [x] Executes shell command in background
- [x] Command: `opencode restart` (configurable)
- [x] Non-blocking execution via `Process`

### F4: Settings Window

**Priority:** Medium

- [ ] Native macOS window with `.hiddenTitleBar` style
- [ ] Keyboard shortcut: `⌘,`

#### F4.1: Server Configuration
- [x] Text field for server URL/port
- [x] Default: `http://127.0.0.1:4096`
- [x] URL validation before saving

#### F4.2: General Options
- [x] "Launch at Login" toggle (via `SMAppService`)
- [x] "Heartbeat Interval" dropdown (5s / 10s / 30s)

#### F4.3: Appearance
- [x] "Show status text in menu bar" toggle

### F5: Design Language

**Priority:** Medium

- [x] "Liquid Glass" effect using `.ultraThinMaterial` / `.thinMaterial`
- [x] San Francisco system font throughout
- [x] SF Symbols exclusively for icons
- [x] High-breathing room spacing (16pt padding, 12pt gaps)
- [x] Linear/Raycast-inspired minimal aesthetic

---

## Extended Features (v2.0)

### F6: Project Awareness

**Priority:** High

#### F6.1: Current Project Display
- [ ] Display current project name/path in menu bar
- [ ] Show project icon/badge
- [ ] Click to expand project details

#### F6.2: VCS Status
- [ ] Display current git branch
- [ ] Show modified files count (via `/vcs`)
- [ ] Indicate uncommitted changes with icon
- [ ] Show ahead/behind status for remote

### F7: Enhanced Session Management

**Priority:** High

#### F7.1: Create New Session
- [ ] Button to create new session via `POST /session`
- [ ] Optional: Set parent session or title
- [ ] Confirmation feedback on creation

#### F7.2: Delete Session
- [ ] Delete session via `DELETE /session/:id`
- [ ] Confirmation dialog before deletion
- [ ] Update session list immediately

#### F7.3: Fork Session
- [ ] Fork existing session at current point via `POST /session/:id/fork`
- [ ] Option to fork at specific message
- [ ] Quick fork from session context menu

#### F7.4: Abort Running Session
- [ ] Abort active session via `POST /session/:id/abort`
- [ ] Show running indicator on active sessions
- [ ] One-click abort button

#### F7.5: Rename Session
- [ ] Update session title via `PATCH /session/:id`
- [ ] Inline rename in session list

#### F7.6: Share/Unshare Session
- [ ] Share session via `POST /session/:id/share`
- [ ] Copy shareable link to clipboard
- [ ] Unshare via `DELETE /session/:id/share`

### F8: Provider & Model Status

**Priority:** Medium

#### F8.1: Provider List
- [ ] Fetch available providers via `GET /provider`
- [ ] Display connected providers
- [ ] Show provider icons and status

#### F8.2: Model Display
- [ ] Show currently selected model
- [ ] Display model for each provider
- [ ] Quick model switcher dropdown

#### F8.3: Provider Health
- [ ] Check provider authentication status
- [ ] Show auth required indicators
- [ ] Quick link to provider docs

### F9: Session Status Dashboard

**Priority:** Medium

#### F9.1: All Sessions Overview
- [ ] Fetch all session statuses via `GET /session/status`
- [ ] Visual indicator for each session state:
  - `running` - Active processing
  - `idle` - Waiting for input
  - `paused` - Paused session
- [ ] Message count per session
- [ ] Last activity timestamp

#### F9.2: Session Filtering
- [ ] Filter by status (running/idle)
- [ ] Search sessions by title
- [ ] Sort by recent activity

### F10: Development Tools Status

**Priority:** Medium

#### F10.1: LSP Servers
- [ ] Fetch LSP status via `GET /lsp`
- [ ] Display running language servers
- [ ] Show server language (Python, TypeScript, etc.)
- [ ] Indicate connection status

#### F10.2: Formatters
- [ ] Fetch formatter status via `GET /formatter`
- [ ] Show active formatters
- [ ] Indicate enabled/disabled state

#### F10.3: MCP Servers
- [ ] Fetch MCP status via `GET /mcp`
- [ ] Display running MCP servers
- [ ] Add new MCP server via `POST /mcp`
- [ ] Show server health/status

### F11: Todo List Integration

**Priority:** Low

#### F11.1: View Todos
- [ ] Fetch todo list via `GET /session/:id/todo`
- [ ] Display todos in session detail view
- [ ] Show completion status
- [ ] Progress indicator

#### F11.2: Permission Responses
- [ ] Handle permission requests via `POST /session/:id/permissions/:permissionID`
- [ ] Show permission dialog in menu bar
- [ ] Quick allow/deny actions

### F12: Agent Launcher

**Priority:** Low

#### F12.1: Available Agents List
- [ ] Fetch agents via `GET /agent`
- [ ] Display agent names and descriptions
- [ ] Show agent icons

#### F12.2: Quick Agent Launch
- [ ] Launch agent from menu
- [ ] Select model for agent
- [ ] Auto-create session with agent

### F13: File Quick Actions

**Priority:** Low

#### F13.1: Quick File Search
- [ ] Search files via `GET /find/file?query=<q>`
- [ ] Fuzzy match file names
- [ ] Open files in default editor

#### F13.2: Symbol Search
- [ ] Find symbols via `GET /find/symbol?query=<q>`
- [ ] Display symbol type (function, class, etc.)
- [ ] Navigate to symbol definition

#### F13.3: File Status
- [ ] Get git-tracked files via `GET /file/status`
- [ ] Show modified/staged indicators
- [ ] Quick git actions

### F14: Session Intelligence

**Priority:** Low

#### F14.1: View Session Diff
- [ ] Get diff via `GET /session/:id/diff`
- [ ] Show changed files
- [ ] Display diff summary

#### F14.2: Summarize Session
- [ ] Summarize via `POST /session/:id/summarize`
- [ ] Generate session summary
- [ ] Copy summary to clipboard

#### F14.3: Revert Messages
- [ ] Revert message via `POST /session/:id/revert`
- [ ] Restore via `POST /session/:id/unrevert`
- [ ] Review before revert

### F15: TUI Integration

**Priority:** Low

#### F15.1: TUI Controls
- [ ] Open help dialog via `POST /tui/open-help`
- [ ] Open session selector via `POST /tui/open-sessions`
- [ ] Open theme/model selectors
- [ ] Execute commands via `POST /tui/execute-command`

#### F15.2: Toast Notifications
- [ ] Show toast via `POST /tui/show-toast`
- [ ] Display app notifications in TUI

---

## Implementation Phases

### Phase 1: Project Configuration

| Task | Status |
|------|--------|
| Configure `Info.plist` with `LSUIElement = YES` | ✅ |
| Add `com.apple.security.network.client` entitlement | ✅ |
| Set deployment target to macOS 14.0+ | ✅ |

### Phase 2: Networking & Heartbeat Service

| Task | Status |
|------|--------|
| Create `ServerStatus` model | ✅ |
| Implement `HeartbeatService` with health check | ✅ |
| Add timer-based polling with configurable interval | ✅ |
| Handle network errors gracefully | ✅ |

### Phase 3: Menu Bar UI

| Task | Status |
|------|--------|
| Replace `WindowGroup` with `MenuBarExtra` | ✅ |
| Create dynamic status icon label | ✅ |
| Build `MenuBarView` with status header | ✅ |
| Apply `.menuBarExtraStyle(.window)` | ✅ |
| Implement `.ultraThinMaterial` background | ✅ |

### Phase 4: Quick Actions

| Task | Status |
|------|--------|
| Implement "Open Portal" action | ✅ |
| Implement "Copy Session ID" action | ✅ |
| Implement "Restart Server" action | ✅ |

### Phase 5: Settings Window

| Task | Status |
|------|--------|
| Create `SettingsManager` with `@AppStorage` | ✅ |
| Build `SettingsWindow` UI | ✅ |
| Implement server URL configuration | ✅ |
| Implement heartbeat interval picker | ✅ |
| Implement "Launch at Login" via `SMAppService` | ✅ |
| Implement appearance toggle | ✅ |

### Phase 6: Polish

| Task | Status |
|------|--------|
| Add accessibility labels to all controls | ⚠️ Needs review |
| Validate URL input in settings | ✅ |
| Add keyboard shortcuts | ⬜ Missing ⌘, for Settings |
| Final UI polish and spacing adjustments | ✅ |

### Phase 7: Extended Features (v2.0)

| Task | Priority | Status |
|------|----------|--------|
| Project awareness (path, VCS) | High | ⬜ |
| Create new session | High | ⬜ |
| Delete session | High | ⬜ |
| Fork session | High | ⬜ |
| Abort running session | High | ⬜ |
| Provider/model status | Medium | ⬜ |
| All sessions status dashboard | Medium | ⬜ |
| LSP/Formatter/MCP status | Medium | ⬜ |
| Session rename | Medium | ⬜ |
| Share/unshare session | Medium | ⬜ |
| Todo list integration | Low | ⬜ |
| Agent launcher | Low | ⬜ |
| File quick actions | Low | ⬜ |
| Session diff/summarize | Low | ⬜ |
| TUI integration | Low | ⬜ |

---

## Implementation Status Summary

### Completed Features (v1.0)

| Feature | Status |
|---------|--------|
| Menu Bar Status Icon (F1) | ✅ Complete with status text toggle |
| Heartbeat Monitor (F2) | ✅ Configurable 5s/10s/30s intervals |
| Open Portal (F3.1) | ✅ Working |
| Copy Session ID (F3.2) | ✅ Enhanced - shows active sessions list |
| Restart Server (F3.3) | ✅ Non-blocking Process execution |
| Server Configuration (F4.1) | ✅ With URL validation |
| Launch at Login (F4.2) | ✅ Via SMAppService |
| Heartbeat Interval (F4.2) | ✅ Dropdown implemented |
| Appearance Toggle (F4.3) | ✅ Show status text in menu bar |
| Design Language (F5) | ✅ Ultra-thin material, SF Symbols |

### Additional Features Implemented

| Feature | Description |
|---------|-------------|
| **Active Sessions List** | Displays all active OpenCode sessions with refresh capability |
| **Session Copy** | Click any session to copy its ID with visual feedback |
| **Task Completion Notifications** | Receives SSE events for session.idle and notifies user |
| **Task Completion Monitor** | Subscribes to `/global/event` SSE stream |
| **Notification Service** | Sends macOS notifications when tasks complete |
| **Dynamic Session Loading** | Loads sessions from `/session` endpoint |

### Known Gaps (v1.0)

| Item | Priority | Notes |
|------|----------|-------|
| Keyboard shortcut ⌘, | Medium | Settings window not accessible via keyboard |
| Accessibility labels | Low | Some controls may lack full accessibility support |
| ContentView.swift | Low | Unused file (dead code) can be removed |

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

### NSHostingController for Sheets

```swift
let hostingController = NSHostingController(rootView: MySheetView())
let sheet = NSSheet(contentSize: NSSize(width: 400, height: 300))
sheet.content = hostingController
NSApp.mainWindow?.beginSheet(sheet)
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

- [OpenCode Server API Documentation](https://opencode.ai/docs/server/)
- [SwiftUI MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [SF Symbols](https://developer.apple.com/sf-symbols/)
- [OpenAPI 3.1 Spec](http://127.0.0.1:4096/doc)
