//
//  galleryApp.swift
//  gallery
//
//  Created by Subhash Sanjeewa on 2026-05-30.
//

import SwiftUI

@main
struct galleryApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
