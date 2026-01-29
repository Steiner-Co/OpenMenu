//
//  SettingsWindow.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import SwiftUI
import ServiceManagement

struct SettingsWindow: View {
    @AppStorage(AppSettings.serverURLKey) private var serverURL = AppSettings.defaultServerURL
    @AppStorage(AppSettings.heartbeatIntervalKey) private var heartbeatIntervalRaw = AppSettings.defaultInterval.rawValue
    @AppStorage(AppSettings.showStatusTextKey) private var showStatusText = false
    @AppStorage(AppSettings.launchAtLoginKey) private var launchAtLogin = false
    
    @State private var urlValidationError: String?
    @State private var launchAtLoginError: String?
    
    private var heartbeatIntervalBinding: Binding<HeartbeatInterval> {
        Binding(
            get: {
                HeartbeatInterval(rawValue: heartbeatIntervalRaw) ?? .normal
            },
            set: { newValue in
                heartbeatIntervalRaw = newValue.rawValue
            }
        )
    }
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Server URL", text: $serverURL)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: serverURL) { _, newValue in
                            validateURL(newValue)
                        }
                    
                    if let error = urlValidationError {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }
                
                Picker("Heartbeat Interval", selection: heartbeatIntervalBinding) {
                    ForEach(HeartbeatInterval.allCases, id: \.self) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
            } header: {
                Label("Server Configuration", systemImage: "server.rack")
            }
            
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        updateLaunchAtLogin(newValue)
                    }
                
                if let error = launchAtLoginError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            } header: {
                Label("General", systemImage: "gearshape")
            }
            
            Section {
                Toggle("Show status text in menu bar", isOn: $showStatusText)
            } header: {
                Label("Appearance", systemImage: "paintbrush")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .onAppear {
            validateURL(serverURL)
            checkLaunchAtLoginStatus()
        }
    }
    
    private func validateURL(_ urlString: String) {
        if urlString.isEmpty {
            urlValidationError = nil
        } else if AppSettings.isValidURL(urlString) {
            urlValidationError = nil
        } else {
            urlValidationError = "Invalid URL. Must be http:// or https://"
        }
    }
    
    private func updateLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        
        do {
            let service = SMAppService.mainApp
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            launchAtLoginError = "Failed to update Launch at Login: \(error.localizedDescription)"
            // Revert the toggle on failure
            DispatchQueue.main.async {
                launchAtLogin = !enabled
            }
        }
    }
    
    private func checkLaunchAtLoginStatus() {
        let service = SMAppService.mainApp
        let isRegistered = service.status == .enabled
        if launchAtLogin != isRegistered {
            launchAtLogin = isRegistered
        }
    }
}

#Preview {
    SettingsWindow()
}
