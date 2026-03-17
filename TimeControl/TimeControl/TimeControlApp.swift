//
//  TimeControlApp.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import SwiftUI

@main
struct TimeControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.viewModel)
        }
    }
}
