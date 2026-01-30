//
//  OpenMenuApp.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import SwiftUI

@main
struct OpenMenuApp: App {
    @State private var heartbeatService = HeartbeatService()
    @State private var taskCompletionMonitor = TaskCompletionMonitor()
    @State private var sessionActivityMonitor = SessionActivityMonitor()
    @State private var menuBarAnimationManager = MenuBarAnimationManager()
    @AppStorage(AppSettings.showStatusTextKey) private var showStatusText = false

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                heartbeatService: heartbeatService,
                taskCompletionMonitor: taskCompletionMonitor,
                sessionActivityMonitor: sessionActivityMonitor,
                menuBarAnimationManager: menuBarAnimationManager
            )
        } label: {
            AnimatedMenuBarLabel(
                isHealthy: heartbeatService.status.healthy,
                showStatusText: showStatusText,
                showCompletionBanner: menuBarAnimationManager.showCompletionBanner
            )
        }
        .menuBarExtraStyle(.window)
    }
}
