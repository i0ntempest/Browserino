//
//  SafariPrivateBrowser.swift
//  Browserino
//

import AppKit
import ApplicationServices
import Carbon

/// Safari has no private-window launch argument. Use its native Accessibility controls.
final class SafariPrivateBrowser {
    struct Failure: Error {
        let message: String
        let remainingURLs: [URL]
        let needsAccessibility: Bool
    }

    private enum AutomationError: LocalizedError {
        case accessibility
        case unavailable(String)

        var errorDescription: String? {
            switch self {
            case .accessibility:
                return "Enable Browserino in System Settings → Privacy & Security → Accessibility, then choose Try Again."
            case .unavailable(let message):
                return message
            }
        }
    }

    private static let queue = DispatchQueue(label: "Browserino.SafariPrivateBrowser", qos: .userInitiated)
    private static let addressIdentifier = "WEB_BROWSER_ADDRESS_AND_SEARCH_FIELD"

    static func supports(_ bundleIdentifier: String?) -> Bool {
        bundleIdentifier == "com.apple.Safari" || bundleIdentifier == "com.apple.SafariTechnologyPreview"
    }

    /// Completion runs on the main queue. Only this private-mode path asks for Accessibility.
    static func open(_ urls: [URL], applicationURL: URL, completion: @escaping (Result<Void, Failure>) -> Void) {
        guard !urls.isEmpty else { completion(.success(())); return }
        queue.async {
            var remaining = urls[...]
            do {
                guard supports(Bundle(url: applicationURL)?.bundleIdentifier) else {
                    throw AutomationError.unavailable("The selected application is not Safari or Safari Technology Preview.")
                }
                let trusted = DispatchQueue.main.sync { () -> Bool in
                    if AXIsProcessTrusted() { return true }
                    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                    return AXIsProcessTrustedWithOptions(options)
                }
                guard trusted else { throw AutomationError.accessibility }
                let running = try runningApplication(at: applicationURL)
                let application = AXUIElementCreateApplication(running.processIdentifier)
                AXUIElementSetMessagingTimeout(application, 2)
                try waitUntilReady(running, application)
                DispatchQueue.main.sync { _ = running.activate() }

                // Keep each URL associated with its own newly created private window.
                // Successfully submitted URLs are excluded from a later manual retry.
                while let url = remaining.first {
                    try openWindow(url, in: running, application: application)
                    remaining = remaining.dropFirst()
                }
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                let needsAccessibility: Bool
                if case AutomationError.accessibility = error { needsAccessibility = true }
                else { needsAccessibility = false }
                let failure = Failure(message: error.localizedDescription, remainingURLs: Array(remaining), needsAccessibility: needsAccessibility)
                DispatchQueue.main.async { completion(.failure(failure)) }
            }
        }
    }

    private static func runningApplication(at url: URL) throws -> NSRunningApplication {
        guard let identifier = Bundle(url: url)?.bundleIdentifier else {
            throw AutomationError.unavailable("Cannot identify the selected Safari application.")
        }
        let matches = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
        guard matches.count <= 1 else {
            throw AutomationError.unavailable("More than one instance of Safari is running. Quit the extra instance and try again.")
        }
        if let running = matches.first { return running }

        // Launch without the usual open-application event, which creates a normal window.
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<NSRunningApplication, Error>?
        DispatchQueue.main.async {
            let configuration = coldLaunchConfiguration()
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, error in
                if let app { result = .success(app) }
                else { result = .failure(error ?? AutomationError.unavailable("Safari did not launch.")) }
                semaphore.signal()
            }
        }
        guard semaphore.wait(timeout: .now() + 20) == .success, let result else {
            throw AutomationError.unavailable("Safari took too long to launch. It may still be starting; try again when it is ready.")
        }
        return try result.get()
    }

    static func coldLaunchConfiguration() -> NSWorkspace.OpenConfiguration {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        // The launch-only event starts Safari without requesting its normal startup window.
        // NSWorkspace delivers it during launch; no AppleScript engine or URL is involved.
        configuration.appleEvent = NSAppleEventDescriptor(
            eventClass: AEEventClass(kASAppleScriptSuite),
            eventID: AEEventID(kASLaunchEvent),
            targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        return configuration
    }

    private static func waitUntilReady(_ running: NSRunningApplication, _ application: AXUIElement) throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 15
        var previous: [AXUIElement]?
        var stableSince = ProcessInfo.processInfo.systemUptime
        repeat {
            guard !running.isTerminated else { throw AutomationError.unavailable("Safari quit before the private window could open.") }
            if running.isFinishedLaunching,
               let windows = value(application, kAXWindowsAttribute) as? [AXUIElement],
               let _ = value(application, kAXMenuBarAttribute) {
                if let previous, sameWindows(previous, windows) {
                    // Allow startup/restoration to settle before taking a window snapshot.
                    if ProcessInfo.processInfo.systemUptime - stableSince >= 0.6 { return }
                } else {
                    previous = windows
                    stableSince = ProcessInfo.processInfo.systemUptime
                }
            } else {
                previous = nil
                stableSince = ProcessInfo.processInfo.systemUptime
            }
            Thread.sleep(forTimeInterval: 0.1)
        } while ProcessInfo.processInfo.systemUptime < deadline
        throw AutomationError.unavailable("Safari is not ready for Accessibility control. Finish any startup dialogs or unlock its private windows, then try again.")
    }

    private static func openWindow(_ url: URL, in running: NSRunningApplication, application: AXUIElement) throws {
        guard let rawBar = value(application, kAXMenuBarAttribute), CFGetTypeID(rawBar) == AXUIElementGetTypeID() else {
            throw AutomationError.unavailable("Cannot access Safari’s menu bar. Check Browserino’s Accessibility access.")
        }
        let bar = unsafeBitCast(rawBar, to: AXUIElement.self)
        let matches = descendants(bar).filter {
            string($0, kAXRoleAttribute) == kAXMenuItemRole &&
            string($0, kAXMenuItemCmdCharAttribute).lowercased() == "n" &&
            // Command is implicit; bit zero denotes Shift.
            (value($0, kAXMenuItemCmdModifiersAttribute) as? NSNumber)?.intValue == 1
        }
        guard matches.count == 1, let command = matches.first,
              (value(command, kAXEnabledAttribute) as? NSNumber)?.boolValue == true else {
            throw AutomationError.unavailable("Cannot identify an enabled New Private Window command. Check Safari’s default Command-Shift-N shortcut and any open dialogs.")
        }
        let before = try windows(application)
        try perform(command, kAXPressAction)
        let deadline = ProcessInfo.processInfo.systemUptime + 6
        var created: AXUIElement?
        repeat {
            created = try newWindow(previous: before, current: windows(application))
            if created != nil { break }
            Thread.sleep(forTimeInterval: 0.1)
        } while ProcessInfo.processInfo.systemUptime < deadline
        guard let window = created else {
            throw AutomationError.unavailable("The new private window did not appear. Safari may have opened a window or an unlock dialog; check it before trying again.")
        }

        let fieldDeadline = ProcessInfo.processInfo.systemUptime + 4
        var fields: [AXUIElement] = []
        repeat {
            fields = descendants(window).filter { string($0, kAXIdentifierAttribute) == addressIdentifier }
            if fields.count == 1, let field = fields.first,
               isSettable(field, kAXValueAttribute), actions(field).contains(kAXConfirmAction) { break }
            Thread.sleep(forTimeInterval: 0.1)
        } while ProcessInfo.processInfo.systemUptime < fieldDeadline
        guard fields.count == 1, let field = fields.first,
              isSettable(field, kAXValueAttribute), isSettable(field, kAXFocusedAttribute),
              actions(field).contains(kAXConfirmAction) else {
            throw AutomationError.unavailable("The new private window has no accessible address field. Unlock or check Safari’s private window, then try again.")
        }
        guard !running.isTerminated,
              try windows(application).contains(where: { CFEqual($0, window) }) else {
            throw AutomationError.unavailable("The new private window closed before the link could be opened.")
        }
        try set(field, kAXFocusedAttribute, kCFBooleanTrue)
        try set(field, kAXValueAttribute, url.absoluteString as CFString)
        guard string(field, kAXValueAttribute) == url.absoluteString else {
            throw AutomationError.unavailable("Safari did not accept the link in its address field. The link was not submitted.")
        }
        try perform(field, kAXConfirmAction)
    }

    /// Compare opaque UI identities, never titles or whichever window happens to be first.
    static func newWindow(previous: [AXUIElement], current: [AXUIElement]) throws -> AXUIElement? {
        let created = current.filter { candidate in !previous.contains { CFEqual($0, candidate) } }
        guard created.count <= 1 else {
            throw AutomationError.unavailable("Multiple Safari windows appeared. Refusing to guess which one is private; check Safari before trying again.")
        }
        return created.first
    }

    private static func sameWindows(_ lhs: [AXUIElement], _ rhs: [AXUIElement]) -> Bool {
        lhs.count == rhs.count && lhs.allSatisfy { element in rhs.contains { CFEqual($0, element) } }
    }

    private static func windows(_ application: AXUIElement) throws -> [AXUIElement] {
        guard let windows = value(application, kAXWindowsAttribute) as? [AXUIElement] else {
            throw AutomationError.unavailable("Cannot read Safari’s windows. Check its dialogs and Browserino’s Accessibility access.")
        }
        return windows
    }

    private static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
        return result
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String {
        value(element, attribute) as? String ?? ""
    }

    private static func actions(_ element: AXUIElement) -> [String] {
        var result: CFArray?
        guard AXUIElementCopyActionNames(element, &result) == .success else { return [] }
        return result as? [String] ?? []
    }

    private static func isSettable(_ element: AXUIElement, _ attribute: String) -> Bool {
        var result = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute as CFString, &result) == .success && result.boolValue
    }

    private static func set(_ element: AXUIElement, _ attribute: String, _ newValue: CFTypeRef) throws {
        let result = AXUIElementSetAttributeValue(element, attribute as CFString, newValue)
        guard result == .success else {
            throw AutomationError.unavailable("Safari’s address field could not be updated (Accessibility error \(result.rawValue)).")
        }
    }

    private static func perform(_ element: AXUIElement, _ action: String) throws {
        let result = AXUIElementPerformAction(element, action as CFString)
        guard result == .success else {
            // An AX timeout can occur after the action took effect. Never retry automatically.
            throw AutomationError.unavailable("Safari did not confirm the requested action (Accessibility error \(result.rawValue)). A window or link may already have opened; check Safari before trying again.")
        }
    }

    private static func descendants(_ root: AXUIElement) -> [AXUIElement] {
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var visited: [AXUIElement] = []
        var index = 0
        while index < queue.count && visited.count < 600 {
            let (element, depth) = queue[index]
            index += 1
            if visited.contains(where: { CFEqual($0, element) }) { continue }
            visited.append(element)
            // Inspect browser chrome, without walking webpage content.
            if depth < 16 && string(element, kAXRoleAttribute) != "AXWebArea" {
                for child in value(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
                    queue.append((child, depth + 1))
                }
            }
        }
        return visited
    }
}
