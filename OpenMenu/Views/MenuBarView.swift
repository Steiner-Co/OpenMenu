//
//  MenuBarView.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import SwiftUI

struct MenuBarView: View {
    let heartbeatService: HeartbeatService
    
    var body: some View {
        VStack(spacing: 12) {
            StatusIndicator(status: heartbeatService.status)
            
            // Future: Quick actions will go here (Phase 4)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .onAppear {
            heartbeatService.startPolling()
        }
    }
}

#Preview {
    MenuBarView(heartbeatService: HeartbeatService())
}
