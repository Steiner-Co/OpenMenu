//
//  AnimatedMenuBarLabel.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 30/01/26.
//

import SwiftUI

/// An animated menu bar label that shows a pill with "Task Complete" when triggered.
struct AnimatedMenuBarLabel: View {
    let isHealthy: Bool
    let showStatusText: Bool
    let showCompletionBanner: Bool
    
    var body: some View {
        Group {
            if showCompletionBanner {
                completionBannerView
            } else if showStatusText {
                statusTextView
            } else {
                iconOnlyView
            }
        }
    }
    
    // MARK: - Completion Banner View
    
    private var completionBannerView: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.hierarchical)
            Text("Task Complete")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.green.opacity(0.5), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Status Text View
    
    private var statusTextView: some View {
        Label(
            isHealthy ? "Online" : "Offline",
            systemImage: isHealthy
                ? "checkmark.circle.fill"
                : "xmark.circle.fill"
        )
        .foregroundStyle(isHealthy ? .green : .red)
    }
    
    // MARK: - Icon Only View
    
    private var iconOnlyView: some View {
        Image(systemName: isHealthy
            ? "checkmark.circle.fill"
            : "xmark.circle.fill")
        .foregroundStyle(isHealthy ? .green : .red)
    }
}

#Preview("Icon Only - Online") {
    AnimatedMenuBarLabel(
        isHealthy: true,
        showStatusText: false,
        showCompletionBanner: false
    )
}

#Preview("Icon Only - Offline") {
    AnimatedMenuBarLabel(
        isHealthy: false,
        showStatusText: false,
        showCompletionBanner: false
    )
}

#Preview("Status Text") {
    AnimatedMenuBarLabel(
        isHealthy: true,
        showStatusText: true,
        showCompletionBanner: false
    )
}

#Preview("Completion Banner") {
    AnimatedMenuBarLabel(
        isHealthy: true,
        showStatusText: false,
        showCompletionBanner: true
    )
}
