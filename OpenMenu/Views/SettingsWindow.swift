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

    @State private var providerInsightsService = ProviderInsightsService()
    @State private var providerIDs: [String] = []
    @State private var providerPlanConfigs: [String: ProviderPlanConfig] = [:]

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
                ForEach(providerIDs, id: \.self) { providerID in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(providerInsightsService.displayName(for: providerID))
                                .font(.system(size: 12, weight: .semibold))

                            Spacer()

                            Picker("", selection: profileBinding(for: providerID)) {
                                ForEach(ProviderPlanProfile.allCases) { profile in
                                    Text(profile.label).tag(profile)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 120)
                        }

                        Stepper(value: budgetBinding(for: providerID), in: 0...5_000, step: 10) {
                            Text("Monthly Budget: $\(config(for: providerID).monthlyBudgetUSD, specifier: "%.0f")")
                                .font(.system(size: 11))
                        }

                        HStack(spacing: 12) {
                            Stepper(value: inputRateBinding(for: providerID), in: 0...200, step: 0.5) {
                                Text("Input $/1M: \(config(for: providerID).inputPricePerMillionUSD, specifier: "%.1f")")
                                    .font(.system(size: 11))
                            }

                            Stepper(value: outputRateBinding(for: providerID), in: 0...400, step: 0.5) {
                                Text("Output $/1M: \(config(for: providerID).outputPricePerMillionUSD, specifier: "%.1f")")
                                    .font(.system(size: 11))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Label("Provider Plans", systemImage: "chart.line.uptrend.xyaxis")
            } footer: {
                Text("Pricing is used to estimate costs when provider APIs return token counts but no spend.")
                    .font(.system(size: 10))
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
        .frame(width: 480)
        .onAppear {
            validateURL(serverURL)
            checkLaunchAtLoginStatus()
            loadProviderPlans()
        }
    }

    private func loadProviderPlans() {
        providerInsightsService.ensureDefaults(for: ProviderInsightsService.preferredProviderIDs)
        providerPlanConfigs = providerInsightsService.loadPlanConfigs()
        providerIDs = providerInsightsService.knownProviderIDs()
    }

    private func config(for providerID: String) -> ProviderPlanConfig {
        providerPlanConfigs[providerID] ?? ProviderPlanConfig.default(providerID: providerID)
    }

    private func saveConfig(_ config: ProviderPlanConfig) {
        providerPlanConfigs[config.providerID] = config
        providerInsightsService.upsertPlanConfig(config)
    }

    private func profileBinding(for providerID: String) -> Binding<ProviderPlanProfile> {
        Binding(
            get: { config(for: providerID).profile },
            set: { newProfile in
                providerInsightsService.setProfile(providerID: providerID, profile: newProfile)
                providerPlanConfigs = providerInsightsService.loadPlanConfigs()
            }
        )
    }

    private func budgetBinding(for providerID: String) -> Binding<Double> {
        Binding(
            get: { config(for: providerID).monthlyBudgetUSD },
            set: { newValue in
                var updated = config(for: providerID)
                updated.monthlyBudgetUSD = max(0, newValue)
                saveConfig(updated)
            }
        )
    }

    private func inputRateBinding(for providerID: String) -> Binding<Double> {
        Binding(
            get: { config(for: providerID).inputPricePerMillionUSD },
            set: { newValue in
                var updated = config(for: providerID)
                updated.profile = .custom
                updated.inputPricePerMillionUSD = max(0, newValue)
                saveConfig(updated)
            }
        )
    }

    private func outputRateBinding(for providerID: String) -> Binding<Double> {
        Binding(
            get: { config(for: providerID).outputPricePerMillionUSD },
            set: { newValue in
                var updated = config(for: providerID)
                updated.profile = .custom
                updated.outputPricePerMillionUSD = max(0, newValue)
                saveConfig(updated)
            }
        )
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
