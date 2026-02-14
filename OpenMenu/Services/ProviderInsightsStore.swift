//
//  ProviderInsightsStore.swift
//  OpenMenu
//
//  Created by Codex on 14/02/26.
//

import Foundation

struct ProviderInsightsStore {
    private static let historyKey = "providerUsageHistoryV1"
    private static let plansKey = "providerPlanConfigsV1"

    static func loadUsageHistory() -> [ProviderUsageSample] {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: historyKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([ProviderUsageSample].self, from: data)
        } catch {
            print("ProviderInsightsStore: failed to decode usage history - \(error.localizedDescription)")
            return []
        }
    }

    static func saveUsageHistory(_ history: [ProviderUsageSample]) {
        // Keep at most 180 days per provider.
        let grouped = Dictionary(grouping: history) { $0.providerID }
        let trimmed = grouped.values.flatMap { samples -> [ProviderUsageSample] in
            let sorted = samples.sorted { $0.dateKey < $1.dateKey }
            return Array(sorted.suffix(180))
        }

        do {
            let data = try JSONEncoder().encode(trimmed)
            UserDefaults.standard.set(data, forKey: historyKey)
        } catch {
            print("ProviderInsightsStore: failed to encode usage history - \(error.localizedDescription)")
        }
    }

    static func loadPlanConfigs() -> [String: ProviderPlanConfig] {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: plansKey) else {
            return [:]
        }

        do {
            return try JSONDecoder().decode([String: ProviderPlanConfig].self, from: data)
        } catch {
            print("ProviderInsightsStore: failed to decode plan configs - \(error.localizedDescription)")
            return [:]
        }
    }

    static func savePlanConfigs(_ configs: [String: ProviderPlanConfig]) {
        do {
            let data = try JSONEncoder().encode(configs)
            UserDefaults.standard.set(data, forKey: plansKey)
        } catch {
            print("ProviderInsightsStore: failed to encode plan configs - \(error.localizedDescription)")
        }
    }
}
