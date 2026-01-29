//
//  NotificationService.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import Foundation
import UserNotifications

/// Sends local macOS notifications when OpenCode tasks complete.
final class NotificationService {
    static let shared = NotificationService()
    
    private let center = UNUserNotificationCenter.current()
    
    private init() {}
    
    private var permissionRequested = false
    
    /// Requests notification permission. Called lazily (e.g. before first notification) to avoid UNUserNotificationCenter bundleID fault at launch.
    func requestPermission() async -> Bool {
        guard !permissionRequested else {
            return await currentAuthorizationStatus() == .authorized
        }
        permissionRequested = true
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            return granted
        } catch {
            return false
        }
    }
    
    private func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
    
    /// Delivers a local notification that an OpenCode task completed.
    /// Requests permission first if needed; only sends when authorized.
    func notifyTaskCompleted(sessionID: String? = nil) {
        Task {
            let granted = await requestPermission()
            guard granted else { return }
            await deliverNotification(sessionID: sessionID)
        }
    }
    
    private func deliverNotification(sessionID: String?) {
        let content = UNMutableNotificationContent()
        content.title = "OpenCode"
        content.body = sessionID.map { "Task completed (session \($0.prefix(8))…)" } ?? "Task completed"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        center.add(request)
    }
}
