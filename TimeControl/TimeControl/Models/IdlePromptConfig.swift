//
//  IdlePromptConfig.swift
//  TimeControl
//

import Foundation

struct IdlePromptConfig: Codable {
    var enabled: Bool
    var activityThresholdSeconds: Double
    var cooldownSeconds: Double

    static let `default` = IdlePromptConfig(
        enabled: true,
        activityThresholdSeconds: 10,
        cooldownSeconds: 1200
    )

    private static let userDefaultsKey = "idlePromptConfig"

    static func load() -> IdlePromptConfig {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let config = try? JSONDecoder().decode(IdlePromptConfig.self, from: data) else {
            return .default
        }
        return config
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: IdlePromptConfig.userDefaultsKey)
    }
}
