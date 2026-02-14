//
//  ProviderInsights.swift
//  OpenMenu
//
//  Created by Codex on 14/02/26.
//

import Foundation

struct ProviderAccountDetection: Codable, Identifiable, Hashable {
    let providerID: String
    let providerName: String
    let source: String
    let accountLabel: String?
    let detectedAt: TimeInterval

    var id: String {
        "\(providerID):\(source):\(accountLabel ?? "")"
    }
}

struct ProviderUsageSample: Codable, Hashable {
    let providerID: String
    let dateKey: String
    let spendUSD: Double
    let requests: Int
    let inputTokens: Int
    let outputTokens: Int

    init(providerID: String, dateKey: String, spendUSD: Double, requests: Int, inputTokens: Int = 0, outputTokens: Int = 0) {
        self.providerID = providerID
        self.dateKey = dateKey
        self.spendUSD = spendUSD
        self.requests = requests
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    enum CodingKeys: String, CodingKey {
        case providerID
        case dateKey
        case spendUSD
        case requests
        case inputTokens
        case outputTokens
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerID = try container.decode(String.self, forKey: .providerID)
        dateKey = try container.decode(String.self, forKey: .dateKey)
        spendUSD = try container.decode(Double.self, forKey: .spendUSD)
        requests = (try? container.decode(Int.self, forKey: .requests)) ?? 0
        inputTokens = (try? container.decode(Int.self, forKey: .inputTokens)) ?? 0
        outputTokens = (try? container.decode(Int.self, forKey: .outputTokens)) ?? 0
    }
}

enum ProviderPlanProfile: String, Codable, CaseIterable, Hashable, Identifiable {
    case starter
    case pro
    case enterprise
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .starter: return "Starter"
        case .pro: return "Pro"
        case .enterprise: return "Enterprise"
        case .custom: return "Custom"
        }
    }
}

struct ProviderPlanConfig: Codable, Hashable {
    var providerID: String
    var monthlyBudgetUSD: Double
    var profile: ProviderPlanProfile
    var inputPricePerMillionUSD: Double
    var outputPricePerMillionUSD: Double

    static func `default`(providerID: String) -> ProviderPlanConfig {
        ProviderPlanConfig.preset(providerID: providerID, profile: .pro)
    }

    static func preset(providerID: String, profile: ProviderPlanProfile) -> ProviderPlanConfig {
        switch profile {
        case .starter:
            return ProviderPlanConfig(providerID: providerID, monthlyBudgetUSD: 30, profile: .starter, inputPricePerMillionUSD: 1.0, outputPricePerMillionUSD: 3.0)
        case .pro:
            return ProviderPlanConfig(providerID: providerID, monthlyBudgetUSD: 80, profile: .pro, inputPricePerMillionUSD: 3.0, outputPricePerMillionUSD: 12.0)
        case .enterprise:
            return ProviderPlanConfig(providerID: providerID, monthlyBudgetUSD: 250, profile: .enterprise, inputPricePerMillionUSD: 2.2, outputPricePerMillionUSD: 8.5)
        case .custom:
            return ProviderPlanConfig(providerID: providerID, monthlyBudgetUSD: 80, profile: .custom, inputPricePerMillionUSD: 3.0, outputPricePerMillionUSD: 12.0)
        }
    }

    func estimatedSpendUSD(inputTokens: Int, outputTokens: Int) -> Double {
        let inputCost = (Double(max(0, inputTokens)) / 1_000_000) * max(0, inputPricePerMillionUSD)
        let outputCost = (Double(max(0, outputTokens)) / 1_000_000) * max(0, outputPricePerMillionUSD)
        return inputCost + outputCost
    }

    enum CodingKeys: String, CodingKey {
        case providerID
        case monthlyBudgetUSD
        case profile
        case inputPricePerMillionUSD
        case outputPricePerMillionUSD
    }

    init(providerID: String, monthlyBudgetUSD: Double, profile: ProviderPlanProfile, inputPricePerMillionUSD: Double, outputPricePerMillionUSD: Double) {
        self.providerID = providerID
        self.monthlyBudgetUSD = monthlyBudgetUSD
        self.profile = profile
        self.inputPricePerMillionUSD = inputPricePerMillionUSD
        self.outputPricePerMillionUSD = outputPricePerMillionUSD
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerID = try container.decode(String.self, forKey: .providerID)
        monthlyBudgetUSD = (try? container.decode(Double.self, forKey: .monthlyBudgetUSD)) ?? 50
        profile = (try? container.decode(ProviderPlanProfile.self, forKey: .profile)) ?? .custom
        inputPricePerMillionUSD = (try? container.decode(Double.self, forKey: .inputPricePerMillionUSD)) ?? 3.0
        outputPricePerMillionUSD = (try? container.decode(Double.self, forKey: .outputPricePerMillionUSD)) ?? 12.0
    }
}

struct ProviderDashboardSummary: Identifiable, Hashable {
    let providerID: String
    let providerName: String
    let detectedAccounts: [ProviderAccountDetection]
    let sourceBadges: [String]
    let isAuthenticatedOnServer: Bool
    let spendThisMonthUSD: Double
    let requestsThisMonth: Int
    let inputTokensThisMonth: Int
    let outputTokensThisMonth: Int
    let monthlyBudgetUSD: Double
    let projectedMonthEndSpendUSD: Double
    let projectionConfidence: ProjectionConfidence
    let sevenDaySpendUSD: [Double]
    let planProfile: ProviderPlanProfile

    var id: String { providerID }

    var budgetUsageRatio: Double {
        guard monthlyBudgetUSD > 0 else { return 0 }
        return min(spendThisMonthUSD / monthlyBudgetUSD, 1.5)
    }

    var projectedBudgetRatio: Double {
        guard monthlyBudgetUSD > 0 else { return 0 }
        return min(projectedMonthEndSpendUSD / monthlyBudgetUSD, 1.5)
    }

    var isAtRisk: Bool {
        projectedMonthEndSpendUSD > monthlyBudgetUSD && monthlyBudgetUSD > 0
    }
}

enum ProjectionConfidence: String, Hashable {
    case low
    case medium
    case high

    var label: String {
        switch self {
        case .low:
            return "Low confidence"
        case .medium:
            return "Medium confidence"
        case .high:
            return "High confidence"
        }
    }
}
