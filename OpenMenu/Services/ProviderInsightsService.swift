//
//  ProviderInsightsService.swift
//  OpenMenu
//
//  Created by Codex on 14/02/26.
//

import Foundation

@Observable
final class ProviderInsightsService {
    static let preferredProviderIDs: [String] = [
        "openai", "anthropic", "google", "xai", "openrouter", "mistral", "groq", "deepseek", "together"
    ]

    private var planConfigs: [String: ProviderPlanConfig] = ProviderInsightsStore.loadPlanConfigs()

    func loadDashboard(serverURL: String) async -> [ProviderDashboardSummary] {
        let localDetections = detectLocalProviders()
        let serverSnapshots = await fetchServerProviderSnapshots(serverURL: serverURL)

        persistHistory(samples: serverSnapshots)
        let history = ProviderInsightsStore.loadUsageHistory()

        let providerIDs = Set(localDetections.map(\.providerID))
            .union(serverSnapshots.map(\.providerID))
            .union(planConfigs.keys)

        let sortedProviderIDs = providerIDs.sorted { lhs, rhs in
            providerSortRank(lhs) < providerSortRank(rhs)
        }

        return sortedProviderIDs.map { providerID in
            let detections = localDetections.filter { $0.providerID == providerID }
            let snapshot = serverSnapshots.first { $0.providerID == providerID }
            let providerName = snapshot?.providerName ?? detections.first?.providerName ?? prettifyProviderID(providerID)
            let authOnServer = snapshot?.isAuthenticated ?? false
            let plan = plan(for: providerID)

            let monthly = monthStats(for: providerID, history: history)
            let projection = projectionForCurrentMonth(providerID: providerID, monthSpend: monthly.spendUSD, history: history)

            let sourceBadges = Set(detections.map(\.source)).sorted()

            return ProviderDashboardSummary(
                providerID: providerID,
                providerName: providerName,
                detectedAccounts: detections,
                sourceBadges: sourceBadges,
                isAuthenticatedOnServer: authOnServer,
                spendThisMonthUSD: monthly.spendUSD,
                requestsThisMonth: monthly.requests,
                inputTokensThisMonth: monthly.inputTokens,
                outputTokensThisMonth: monthly.outputTokens,
                monthlyBudgetUSD: plan.monthlyBudgetUSD,
                projectedMonthEndSpendUSD: projection.projectedUSD,
                projectionConfidence: projection.confidence,
                sevenDaySpendUSD: sevenDaySpend(providerID: providerID, history: history),
                planProfile: plan.profile
            )
        }
    }

    func knownProviderIDs() -> [String] {
        let merged = Set(Self.preferredProviderIDs).union(planConfigs.keys)
        return merged.sorted { providerSortRank($0) < providerSortRank($1) }
    }

    func loadPlanConfigs() -> [String: ProviderPlanConfig] {
        planConfigs
    }

    func ensureDefaults(for providerIDs: [String]) {
        var changed = false
        for providerID in providerIDs {
            if planConfigs[providerID] == nil {
                planConfigs[providerID] = ProviderPlanConfig.default(providerID: providerID)
                changed = true
            }
        }
        if changed {
            ProviderInsightsStore.savePlanConfigs(planConfigs)
        }
    }

    func upsertPlanConfig(_ config: ProviderPlanConfig) {
        planConfigs[config.providerID] = config
        ProviderInsightsStore.savePlanConfigs(planConfigs)
    }

    func adjustBudget(providerID: String, deltaUSD: Double) {
        var current = plan(for: providerID)
        current.monthlyBudgetUSD = max(0, current.monthlyBudgetUSD + deltaUSD)
        upsertPlanConfig(current)
    }

    func setBudget(providerID: String, valueUSD: Double) {
        var current = plan(for: providerID)
        current.monthlyBudgetUSD = max(0, valueUSD)
        upsertPlanConfig(current)
    }

    func setProfile(providerID: String, profile: ProviderPlanProfile) {
        let current = plan(for: providerID)
        if profile == .custom {
            var updated = current
            updated.profile = .custom
            upsertPlanConfig(updated)
            return
        }
        upsertPlanConfig(ProviderPlanConfig.preset(providerID: providerID, profile: profile))
    }

    func displayName(for providerID: String) -> String {
        prettifyProviderID(providerID)
    }

    private func plan(for providerID: String) -> ProviderPlanConfig {
        if let configured = planConfigs[providerID] {
            return configured
        }
        let fallback = ProviderPlanConfig.default(providerID: providerID)
        planConfigs[providerID] = fallback
        ProviderInsightsStore.savePlanConfigs(planConfigs)
        return fallback
    }

    private func monthStats(for providerID: String, history: [ProviderUsageSample]) -> (spendUSD: Double, requests: Int, inputTokens: Int, outputTokens: Int) {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM"
        let monthKey = formatter.string(from: Date())

        let scoped = history.filter {
            $0.providerID == providerID && $0.dateKey.hasPrefix(monthKey)
        }

        let spend = scoped.reduce(0) { $0 + $1.spendUSD }
        let requests = scoped.reduce(0) { $0 + $1.requests }
        let inputTokens = scoped.reduce(0) { $0 + $1.inputTokens }
        let outputTokens = scoped.reduce(0) { $0 + $1.outputTokens }
        return (spend, requests, inputTokens, outputTokens)
    }

    private func sevenDaySpend(providerID: String, history: [ProviderUsageSample]) -> [Double] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"

        let grouped = Dictionary(grouping: history.filter { $0.providerID == providerID }, by: \.dateKey)
        let today = Date()
        var data: [Double] = []

        for offset in stride(from: 6, through: 0, by: -1) {
            guard let day = Calendar(identifier: .gregorian).date(byAdding: .day, value: -offset, to: today) else {
                data.append(0)
                continue
            }
            let key = formatter.string(from: day)
            let sum = (grouped[key] ?? []).reduce(0) { $0 + $1.spendUSD }
            data.append(sum)
        }

        return data
    }

    private func projectionForCurrentMonth(providerID: String, monthSpend: Double, history: [ProviderUsageSample]) -> (projectedUSD: Double, confidence: ProjectionConfidence) {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let day = max(1, calendar.component(.day, from: now))
        guard let daysRange = calendar.range(of: .day, in: .month, for: now) else {
            return (monthSpend, .low)
        }

        let daysInMonth = daysRange.count
        let projected = day > 0 ? (monthSpend / Double(day)) * Double(daysInMonth) : monthSpend

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM"
        let monthKey = formatter.string(from: now)

        let activeDays = Set(history.filter {
            $0.providerID == providerID &&
            $0.dateKey.hasPrefix(monthKey) &&
            ($0.spendUSD > 0 || $0.requests > 0)
        }.map(\.dateKey)).count

        let confidence: ProjectionConfidence
        if activeDays >= 8 {
            confidence = .high
        } else if activeDays >= 4 {
            confidence = .medium
        } else {
            confidence = .low
        }

        return (projected, confidence)
    }

    private func persistHistory(samples: [ServerProviderSnapshot]) {
        guard !samples.isEmpty else { return }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())

        var history = ProviderInsightsStore.loadUsageHistory()

        for sample in samples {
            guard sample.spendUSD > 0 || sample.requests > 0 || sample.inputTokens > 0 || sample.outputTokens > 0 else {
                continue
            }
            let newSample = ProviderUsageSample(
                providerID: sample.providerID,
                dateKey: todayKey,
                spendUSD: sample.spendUSD,
                requests: sample.requests,
                inputTokens: sample.inputTokens,
                outputTokens: sample.outputTokens
            )

            if let idx = history.firstIndex(where: { $0.providerID == newSample.providerID && $0.dateKey == newSample.dateKey }) {
                history[idx] = newSample
            } else {
                history.append(newSample)
            }
        }

        ProviderInsightsStore.saveUsageHistory(history)
    }

    private func fetchServerProviderSnapshots(serverURL: String) async -> [ServerProviderSnapshot] {
        guard let base = URL(string: serverURL) else { return [] }

        async let providersRaw = fetchJSON(path: "/provider", baseURL: base)
        async let configProvidersRaw = fetchJSON(path: "/config/providers", baseURL: base)

        let rawA = await providersRaw
        let rawB = await configProvidersRaw

        let extracted = extractProviders(from: rawA) + extractProviders(from: rawB)

        // Merge duplicates while preserving the best-known usage/auth fields.
        var merged: [String: ServerProviderSnapshot] = [:]
        for item in extracted {
            if let existing = merged[item.providerID] {
                merged[item.providerID] = existing.merged(with: item)
            } else {
                merged[item.providerID] = item
            }
        }

        return merged.values.sorted {
            providerSortRank($0.providerID) < providerSortRank($1.providerID)
        }
    }

    private func fetchJSON(path: String, baseURL: URL) async -> Any? {
        guard let url = URL(string: path, relativeTo: baseURL) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 4
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            return nil
        }
    }

    private func extractProviders(from raw: Any?) -> [ServerProviderSnapshot] {
        guard let raw else { return [] }

        if let list = raw as? [[String: Any]] {
            return list.compactMap { buildSnapshot(from: $0) }
        }

        if let dict = raw as? [String: Any] {
            if let providers = dict["providers"] as? [[String: Any]] {
                return providers.compactMap { buildSnapshot(from: $0) }
            }

            // Map-like response: { "openai": {...}, "anthropic": {...} }
            var mapped: [ServerProviderSnapshot] = []
            for (key, value) in dict {
                guard let item = value as? [String: Any] else { continue }
                var enriched = item
                if enriched["id"] == nil {
                    enriched["id"] = key
                }
                if let snapshot = buildSnapshot(from: enriched) {
                    mapped.append(snapshot)
                }
            }
            return mapped
        }

        return []
    }

    private func buildSnapshot(from raw: [String: Any]) -> ServerProviderSnapshot? {
        let inferredID = normalizeProviderID(
            (raw["id"] as? String) ??
            (raw["provider"] as? String) ??
            (raw["name"] as? String)
        )

        guard let providerID = inferredID else { return nil }

        let providerName = (raw["name"] as? String) ?? prettifyProviderID(providerID)

        let authSignals: [Bool?] = [
            raw["authenticated"] as? Bool,
            raw["enabled"] as? Bool,
            raw["configured"] as? Bool,
            raw["available"] as? Bool,
            raw["ready"] as? Bool
        ]

        let isAuthenticated = authSignals.compactMap { $0 }.contains(true)

        let spendUSDFromAPI = extractDouble(raw, keys: [
            "spend_usd", "spendUSD", "usage_usd", "cost_usd", "total_cost_usd", "cost"
        ]) ?? extractNestedDouble(raw, nestedKey: "usage", keys: ["usd", "spend", "cost", "total"])
        let requests = extractInt(raw, keys: [
            "request_count", "requests", "calls", "count"
        ]) ?? extractNestedInt(raw, nestedKey: "usage", keys: ["requests", "count", "calls"])

        let inputTokens = extractInt(raw, keys: [
            "input_tokens", "prompt_tokens", "tokens_in"
        ]) ?? extractNestedInt(raw, nestedKey: "usage", keys: ["input_tokens", "prompt_tokens", "tokens_in"])
        let outputTokens = extractInt(raw, keys: [
            "output_tokens", "completion_tokens", "tokens_out"
        ]) ?? extractNestedInt(raw, nestedKey: "usage", keys: ["output_tokens", "completion_tokens", "tokens_out"])

        let plan = plan(for: providerID)
        let estimatedFromTokens = plan.estimatedSpendUSD(inputTokens: inputTokens ?? 0, outputTokens: outputTokens ?? 0)

        return ServerProviderSnapshot(
            providerID: providerID,
            providerName: providerName,
            isAuthenticated: isAuthenticated,
            spendUSD: max(0, spendUSDFromAPI ?? estimatedFromTokens),
            requests: max(0, requests ?? 0),
            inputTokens: max(0, inputTokens ?? 0),
            outputTokens: max(0, outputTokens ?? 0)
        )
    }

    private func extractDouble(_ dict: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            guard let value = dict[key] else { continue }
            if let value = value as? Double { return value }
            if let value = value as? Int { return Double(value) }
            if let value = value as? NSNumber { return value.doubleValue }
            if let value = value as? String, let parsed = Double(value) { return parsed }
        }
        return nil
    }

    private func extractInt(_ dict: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            guard let value = dict[key] else { continue }
            if let value = value as? Int { return value }
            if let value = value as? NSNumber { return value.intValue }
            if let value = value as? String, let parsed = Int(value) { return parsed }
        }
        return nil
    }

    private func extractNestedDouble(_ dict: [String: Any], nestedKey: String, keys: [String]) -> Double? {
        guard let nested = dict[nestedKey] as? [String: Any] else { return nil }
        return extractDouble(nested, keys: keys)
    }

    private func extractNestedInt(_ dict: [String: Any], nestedKey: String, keys: [String]) -> Int? {
        guard let nested = dict[nestedKey] as? [String: Any] else { return nil }
        return extractInt(nested, keys: keys)
    }

    private func detectLocalProviders() -> [ProviderAccountDetection] {
        var results: Set<ProviderAccountDetection> = []
        let now = Date().timeIntervalSince1970

        for hint in ProviderHint.all {
            for envVar in hint.envVars {
                if let value = ProcessInfo.processInfo.environment[envVar], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    results.insert(
                        ProviderAccountDetection(
                            providerID: hint.id,
                            providerName: hint.name,
                            source: "Environment",
                            accountLabel: envVar,
                            detectedAt: now
                        )
                    )
                }
            }
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let files: [(String, URL)] = [
            ("OpenCode auth", home.appending(path: ".config/opencode/auth.json")),
            ("OpenCode config", home.appending(path: ".config/opencode/config.json")),
            ("Claude config", home.appending(path: ".claude/settings.json")),
            ("Anthropic config", home.appending(path: ".anthropic/settings.json")),
            ("OpenAI config", home.appending(path: ".openai/auth.json")),
            ("OpenAI config", home.appending(path: ".config/openai/auth.json")),
            ("Google ADC", home.appending(path: ".config/gcloud/application_default_credentials.json")),
            ("Gemini config", home.appending(path: ".config/gemini/config.json"))
        ]

        for (source, url) in files {
            guard let content = try? String(contentsOf: url, encoding: .utf8).lowercased(), !content.isEmpty else {
                continue
            }

            for hint in ProviderHint.all {
                if content.contains(hint.matchToken) {
                    results.insert(
                        ProviderAccountDetection(
                            providerID: hint.id,
                            providerName: hint.name,
                            source: source,
                            accountLabel: nil,
                            detectedAt: now
                        )
                    )
                }
            }
        }

        return Array(results).sorted {
            if $0.providerID == $1.providerID {
                return $0.source < $1.source
            }
            return providerSortRank($0.providerID) < providerSortRank($1.providerID)
        }
    }

    private func normalizeProviderID(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        if normalized.contains("openai") { return "openai" }
        if normalized.contains("anthropic") || normalized.contains("claude") { return "anthropic" }
        if normalized.contains("google") || normalized.contains("gemini") { return "google" }
        if normalized.contains("openrouter") { return "openrouter" }
        if normalized.contains("xai") || normalized.contains("grok") { return "xai" }
        if normalized.contains("mistral") { return "mistral" }
        if normalized.contains("groq") { return "groq" }
        if normalized.contains("deepseek") { return "deepseek" }
        if normalized.contains("together") { return "together" }

        // Keep unknown provider IDs stable for display/history.
        return normalized
    }

    private func prettifyProviderID(_ providerID: String) -> String {
        switch providerID {
        case "openai": return "OpenAI"
        case "anthropic": return "Anthropic"
        case "google": return "Google"
        case "xai": return "xAI"
        case "openrouter": return "OpenRouter"
        case "mistral": return "Mistral"
        case "groq": return "Groq"
        case "deepseek": return "DeepSeek"
        case "together": return "Together"
        default:
            return providerID.capitalized
        }
    }

    private func providerSortRank(_ providerID: String) -> Int {
        if let idx = Self.preferredProviderIDs.firstIndex(of: providerID) {
            return idx
        }
        return 100
    }
}

private struct ServerProviderSnapshot {
    let providerID: String
    let providerName: String
    let isAuthenticated: Bool
    let spendUSD: Double
    let requests: Int
    let inputTokens: Int
    let outputTokens: Int

    func merged(with rhs: ServerProviderSnapshot) -> ServerProviderSnapshot {
        ServerProviderSnapshot(
            providerID: providerID,
            providerName: providerName,
            isAuthenticated: isAuthenticated || rhs.isAuthenticated,
            spendUSD: max(spendUSD, rhs.spendUSD),
            requests: max(requests, rhs.requests),
            inputTokens: max(inputTokens, rhs.inputTokens),
            outputTokens: max(outputTokens, rhs.outputTokens)
        )
    }
}

private struct ProviderHint {
    let id: String
    let name: String
    let matchToken: String
    let envVars: [String]

    static let all: [ProviderHint] = [
        ProviderHint(id: "openai", name: "OpenAI", matchToken: "openai", envVars: ["OPENAI_API_KEY"]),
        ProviderHint(id: "anthropic", name: "Anthropic", matchToken: "anthropic", envVars: ["ANTHROPIC_API_KEY"]),
        ProviderHint(id: "google", name: "Google", matchToken: "gemini", envVars: ["GOOGLE_API_KEY", "GEMINI_API_KEY"]),
        ProviderHint(id: "openrouter", name: "OpenRouter", matchToken: "openrouter", envVars: ["OPENROUTER_API_KEY"]),
        ProviderHint(id: "xai", name: "xAI", matchToken: "xai", envVars: ["XAI_API_KEY"]),
        ProviderHint(id: "mistral", name: "Mistral", matchToken: "mistral", envVars: ["MISTRAL_API_KEY"]),
        ProviderHint(id: "groq", name: "Groq", matchToken: "groq", envVars: ["GROQ_API_KEY"]),
        ProviderHint(id: "deepseek", name: "DeepSeek", matchToken: "deepseek", envVars: ["DEEPSEEK_API_KEY"]),
        ProviderHint(id: "together", name: "Together", matchToken: "together", envVars: ["TOGETHER_API_KEY"])
    ]
}
