//
//  main.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 06.06.2024.
//

import AppKit
import Foundation

// Import before AppDelegate or any @AppStorage-backed state is initialized.
PreferencesMigration.migrateIfNeeded()

let app = BrowserinoApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
app.setActivationPolicy(.accessory)

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
