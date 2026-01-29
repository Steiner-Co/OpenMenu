//
//  StatusIndicator.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import SwiftUI

struct StatusIndicator: View {
    let status: ServerStatus
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.healthy ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(status.healthy ? .green : .red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(status.healthy ? "Online" : "Offline")
                    .font(.system(size: 14, weight: .semibold))
                
                if status.healthy, let version = status.version {
                    Text("Version \(version)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        StatusIndicator(status: ServerStatus(healthy: true, version: "1.0.0"))
        StatusIndicator(status: ServerStatus.offline)
    }
    .padding()
}
