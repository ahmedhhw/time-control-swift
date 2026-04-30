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

    var pat: String {
        get { defaults.string(forKey: "ado.pat") ?? "" }
        set {
            if newValue.isEmpty {
                defaults.removeObject(forKey: "ado.pat")
            } else {
                defaults.set(newValue, forKey: "ado.pat")
            }
        }
    }
}
