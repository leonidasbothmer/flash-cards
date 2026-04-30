//
//  learn_greekApp.swift
//  learn-greek
//
//  Created by Leonidas von Bothmer on 30.04.26.
//

import SwiftUI
import CoreData

@main
struct learn_greekApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
