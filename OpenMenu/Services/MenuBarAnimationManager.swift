//
//  MenuBarAnimationManager.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 30/01/26.
//

import Foundation
import SwiftUI
import Combine

/// Manages the animated menu bar icon state for task completion feedback.
@Observable
final class MenuBarAnimationManager {
    /// Whether to show the expanded "Task Complete" banner
    var showCompletionBanner: Bool = false
    
    /// The session ID that completed (for display purposes)
    var completedSessionID: String?
    
    /// Duration to show the banner before auto-dismissing
    var bannerDisplayDuration: TimeInterval = 4.0
    
    /// Duration for the animation
    var animationDuration: TimeInterval = 0.3
    
    private var dismissTask: Task<Void, Never>?
    
    /// Triggers the task completion animation
    /// - Parameter sessionID: Optional session ID that completed
    @MainActor
    func showTaskCompleted(sessionID: String? = nil) {
        // Cancel any pending dismiss
        dismissTask?.cancel()
        
        completedSessionID = sessionID
        
        // Show the banner with animation
        withAnimation(.spring(response: animationDuration, dampingFraction: 0.7)) {
            showCompletionBanner = true
        }
        
        // Schedule auto-dismiss
        dismissTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(bannerDisplayDuration * 1_000_000_000))
                
                guard !Task.isCancelled else { return }
                
                withAnimation(.easeOut(duration: animationDuration)) {
                    showCompletionBanner = false
                }
                
                // Clear session ID after animation completes
                try await Task.sleep(nanoseconds: UInt64(animationDuration * 1_000_000_000))
                if !Task.isCancelled {
                    completedSessionID = nil
                }
            } catch {
                // Task was cancelled, do nothing
            }
        }
    }
    
    /// Manually dismisses the banner
    @MainActor
    func dismissBanner() {
        dismissTask?.cancel()
        
        withAnimation(.easeOut(duration: animationDuration)) {
            showCompletionBanner = false
        }
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(animationDuration * 1_000_000_000))
            completedSessionID = nil
        }
    }
}
