//  BrowserUtil.swift
//  Browserino
//
//  Created by byt3m4st3r.
//

import AppKit
import Foundation
import SwiftUI

class BrowserUtil {
    @AppStorage("directories") private static var directories: [Directory] = []
    @AppStorage("privateArgs") private static var privateArgs: [String: String] = [:]

    static func loadBrowsers(
        oldBrowsers: [URL]
    ) -> [URL] {
        if directories.isEmpty {
            let defaultDirectory = Directory(directoryPath: "/Applications")
            directories.append(defaultDirectory)
        }
        
        let validDirectories = directories.map { $0.directoryPath }

        guard let url = URL(string: "https:") else {
            return []
        }

        let urlsForApplications = NSWorkspace.shared.urlsForApplications(toOpen: url)

        var filteredUrlsForApplications = urlsForApplications.filter { urlsForApplication in
            validDirectories.contains { urlsForApplication.path.hasPrefix($0) }
        }
        
        if let browserino = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "xyz.alexstrnik.Browserino") {
            filteredUrlsForApplications.removeAll { $0 == browserino }
        }

        if let safari = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
            if !filteredUrlsForApplications.contains(safari) {
                filteredUrlsForApplications.append(safari)
            }
        }
        
        var oldPositions: [URL: Int] = [:]
        for (index, browser) in oldBrowsers.enumerated() {
            oldPositions[browser] = index
        }
        
        filteredUrlsForApplications.sort { browser1, browser2 in
            if let pos1 = oldPositions[browser1], let pos2 = oldPositions[browser2] {
                return pos1 < pos2
            }
            else if oldPositions[browser1] != nil {
                return true
            }
            else if oldPositions[browser2] != nil {
                return false
            }
            
            return true
        }
        
        return filteredUrlsForApplications
    }
    
    static func openURL(_ urls: [URL], app: URL, isIncognito: Bool) {
        guard let bundle = Bundle(url: app) else {
            return
        }
        
        if isIncognito, SafariPrivateBrowser.supports(bundle.bundleIdentifier) {
            openSafariPrivately(urls, app: app)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        
        if isIncognito, let privateArg = privateArgs[bundle.bundleIdentifier!] {
            configuration.createsNewApplicationInstance = true
            configuration.arguments = [privateArg] + urls.map(\.absoluteString)
        }
        
        NSWorkspace.shared.open(
            isIncognito ? [] : urls,
            withApplicationAt: app,
            configuration: configuration
        )
    }

    private static func openSafariPrivately(_ urls: [URL], app: URL) {
        // Dismiss the picker before the asynchronous permission/launch flow, including on cold start.
        (NSApp.keyWindow as? BrowserinoWindow)?.close()
        SafariPrivateBrowser.open(urls, applicationURL: app) { result in
            guard case .failure(let failure) = result else { return }

            // Keep unsubmitted links available even after the picker has closed.
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = failure.needsAccessibility
                ? "Safari private browsing needs Accessibility access"
                : "Couldn’t open links privately in Safari"
            alert.informativeText = failure.message + "\n\nYour unsubmitted links have been kept."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Try Again")
            alert.addButton(withTitle: "Copy Links")
            alert.addButton(withTitle: "Cancel")
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                openSafariPrivately(failure.remainingURLs, app: app)
            case .alertSecondButtonReturn:
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(
                    failure.remainingURLs.map(\.absoluteString).joined(separator: "\n"),
                    forType: .string
                )
            default:
                break
            }
        }
    }
}
