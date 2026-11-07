//
//  PreferencesMigration.swift
//  Browserino
//

import Foundation

enum PreferencesMigration {
    static let completionKey = "_didMigrateLegacyPreferences"

    static func migrateIfNeeded(
        defaults: UserDefaults = .standard,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        legacyIdentifier: String = "xyz.alexstrnik.Browserino"
    ) {
        guard let bundleIdentifier, bundleIdentifier != legacyIdentifier else { return }
        var current = defaults.persistentDomain(forName: bundleIdentifier) ?? [:]
        guard current[completionKey] as? Bool != true else { return }

        // Read only the old app's persistent domain, without registered/global defaults.
        // Keep any settings already chosen under the new ID, and leave the old domain intact.
        let legacy = defaults.persistentDomain(forName: legacyIdentifier) ?? [:]
        for (key, value) in legacy where current[key] == nil && key != completionKey {
            current[key] = value
        }
        current[completionKey] = true
        defaults.setPersistentDomain(current, forName: bundleIdentifier)
    }
}
