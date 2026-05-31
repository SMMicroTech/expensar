//
//  galleryApp.swift
//  gallery
//
//  Created by Subhash Sanjeewa on 2026-05-30.
//

import SwiftUI

@main
struct galleryApp: App {
    @StateObject private var store = ExpensesStore()
    @StateObject private var syncSettings = SyncSettingsStore()
    @StateObject private var budgetStore = BudgetStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(syncSettings)
                .environmentObject(budgetStore)
        }
    }
}
