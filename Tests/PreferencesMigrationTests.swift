// Compile together with Browserino/Models/PreferencesMigration.swift.
// All domains are held in memory; no real preferences are read or written.
import Foundation

private final class MemoryDefaults: UserDefaults {
    var domains: [String: [String: Any]] = [:]
    var reads: [String] = []
    var writes = 0

    override func persistentDomain(forName domainName: String) -> [String: Any]? {
        reads.append(domainName)
        return domains[domainName]
    }

    override func setPersistentDomain(_ domain: [String: Any], forName domainName: String) {
        writes += 1
        domains[domainName] = domain
    }
}

@main
struct PreferencesMigrationTests {
    static func main() {
        let old = "test.legacy"
        let new = "test.fork"
        let marker = PreferencesMigration.completionKey
        let defaults = MemoryDefaults()
        let shortcuts = "{\"com.apple.Safari\":\"s\"}"
        defaults.domains[old] = [
            "browsers": "[\"file:///Applications/Safari.app\"]",
            "shortcuts": shortcuts,
            "rules": "[]",
            "showInMenuBar": false,
            "NSWindow Frame prompt_Size": "0 0 250 200",
            "NSStatusItem Preferred Position Item-0": 42,
        ]
        PreferencesMigration.migrateIfNeeded(defaults: defaults, bundleIdentifier: new, legacyIdentifier: old)
        let first = defaults.domains[new]!
        precondition(first["shortcuts"] as? String == shortcuts)
        precondition(first["showInMenuBar"] as? Bool == false)
        precondition(first["NSWindow Frame prompt_Size"] as? String == "0 0 250 200")
        precondition(first["NSStatusItem Preferred Position Item-0"] as? Int == 42)
        precondition(first[marker] as? Bool == true)
        precondition(defaults.domains[old]?[marker] == nil)
        precondition(defaults.domains[old]?["shortcuts"] as? String == shortcuts)
        // Later changes under the old ID cannot overwrite the fork's settings.
        defaults.domains[old]?["shortcuts"] = "changed in old app"
        let writes = defaults.writes
        defaults.reads.removeAll()
        PreferencesMigration.migrateIfNeeded(defaults: defaults, bundleIdentifier: new, legacyIdentifier: old)
        precondition(defaults.writes == writes)
        precondition(!defaults.reads.contains(old))
        precondition(defaults.domains[new]?["shortcuts"] as? String == shortcuts)
        // Preserve existing choices, including false and empty values.
        defaults.domains[new] = ["showInMenuBar": true, "rules": "", "copy_closeAfterCopy": false]
        PreferencesMigration.migrateIfNeeded(defaults: defaults, bundleIdentifier: new, legacyIdentifier: old)
        precondition(defaults.domains[new]?["showInMenuBar"] as? Bool == true)
        precondition(defaults.domains[new]?["rules"] as? String == "")
        precondition(defaults.domains[new]?["copy_closeAfterCopy"] as? Bool == false)
        // Reset can clear all settings while preserving the one-time marker.
        defaults.domains[new] = [marker: true]
        PreferencesMigration.migrateIfNeeded(defaults: defaults, bundleIdentifier: new, legacyIdentifier: old)
        precondition(defaults.domains[new]?.count == 1)
        // Clean installs are marked complete too; no later surprise import.
        defaults.domains.removeValue(forKey: old)
        defaults.domains.removeValue(forKey: new)
        PreferencesMigration.migrateIfNeeded(defaults: defaults, bundleIdentifier: new, legacyIdentifier: old)
        precondition(defaults.domains[new]?.count == 1)
        // Never write back into the legacy ID, or migrate an unidentified executable.
        let beforeSkipped = defaults.writes
        PreferencesMigration.migrateIfNeeded(defaults: defaults, bundleIdentifier: old, legacyIdentifier: old)
        PreferencesMigration.migrateIfNeeded(defaults: defaults, bundleIdentifier: nil, legacyIdentifier: old)
        precondition(defaults.writes == beforeSkipped)
        print("PASS: one-time preference import, existing-value preservation, source isolation, clean install and reset behavior (in memory).")
    }
}
