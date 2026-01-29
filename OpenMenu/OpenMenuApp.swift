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
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(heartbeatService: heartbeatService, taskCompletionMonitor: taskCompletionMonitor)
        } label: {
            Image(systemName: heartbeatService.status.healthy 
                ? "checkmark.circle.fill" 
                : "xmark.circle.fill")
                .foregroundStyle(heartbeatService.status.healthy ? .green : .red)
        }
        .menuBarExtraStyle(.window)
    }
}
