//
//  ADOSettingsStore.swift
//  TimeControl
//

import Foundation

final class ADOSettingsStore {

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var organization: String {
        get { defaults.string(forKey: "ado.organization") ?? "" }
        set { defaults.set(newValue, forKey: "ado.organization") }
    }

    var project: String {
        get { defaults.string(forKey: "ado.project") ?? "" }
        set { defaults.set(newValue, forKey: "ado.project") }
    }
}
