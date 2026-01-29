PRD: OpenMenu (macOS Companion for OpenCode)
1. Project Overview
OpenMenu is a native macOS menu bar utility designed for solo developers to monitor and control their local OpenCode development server. The app serves as a "command center" that removes the need to keep a browser tab or terminal window pinned just to check server health.

2. Core Features
Menu Bar Status: A dynamic icon in the macOS menu bar that reflects the server's heartbeat status (Active/Offline).

Heartbeat Monitor: Periodically pings http://127.0.0.1:4096/ to verify connectivity.

Quick Actions: * "Open Portal" (Launches the web UI in the default browser).

"Copy Session ID" (Quick access for CLI pairing).

"Restart Server" (Executes a background shell command).

Settings Window: A dedicated native window to manage user preferences.

3. Design Language & Aesthetic
The app must strictly follow Apple’s native design language with a focus on a modern, minimal, "Linear-style" UI.

Materials: Use "Liquid Glass" effects—specifically SwiftUI’s .thinMaterial and .ultraThinMaterial for the menu and settings window backgrounds to create depth and vibrancy.

Typography: Use San Francisco (System Font) with appropriate weights (Semibold for headers, Regular for status text).

Icons: Use SF Symbols exclusively (e.g., terminal.fill, gearshape, network).

Spacing: Prioritize high-breathing room and clear visual hierarchy, reminiscent of high-end productivity tools like Raycast or Linear.

4. Settings Window Requirements
The settings window should be a standard macOS window (.windowStyle(.hiddenTitleBar)) containing:

Server Configuration: A text field to change the default OpenCode URL/Port (Default: http://127.0.0.1:4096).

General Options: * "Launch at Login" toggle.

"Heartbeat Interval" (Dropdown: 5s, 10s, 30s).

Appearance: Toggle for "Show status text in menu bar" vs "Icon only."

5. Technical Constraints
Framework: SwiftUI (macOS 14+).

App Mode: Must run as a background agent (LSUIElement = YES) to keep the Dock clean.

Networking: Use URLSession for non-blocking heartbeat checks.

Sandboxing: Ensure com.apple.security.network.client is enabled for 127.0.0.1 communication.