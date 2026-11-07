// Compile together with Browserino/Models/SafariPrivateBrowser.swift.
// Uses opaque AX identities only: no permission requests or UI messages.
import ApplicationServices
import Carbon
import Foundation

@main
struct SafariPrivateBrowserTests {
    static func main() throws {
        precondition(SafariPrivateBrowser.supports("com.apple.Safari"))
        precondition(SafariPrivateBrowser.supports("com.apple.SafariTechnologyPreview"))
        for other: String? in [nil, "", "com.google.Chrome", "org.mozilla.firefox", "com.apple.Safari.extra"] {
            precondition(!SafariPrivateBrowser.supports(other))
        }
        let launch = SafariPrivateBrowser.coldLaunchConfiguration()
        precondition(!launch.activates && !launch.createsNewApplicationInstance)
        precondition(launch.arguments.isEmpty)
        precondition(launch.appleEvent?.eventClass == AEEventClass(kASAppleScriptSuite))
        precondition(launch.appleEvent?.eventID == AEEventID(kASLaunchEvent))
        precondition(launch.appleEvent?.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) == nil)
        let old = [AXUIElementCreateApplication(1), AXUIElementCreateApplication(2)]
        let new = AXUIElementCreateApplication(3)
        precondition(tryResult(previous: old, current: Array(old.reversed())) == nil)
        let selected = try SafariPrivateBrowser.newWindow(previous: old, current: [old[1], new, old[0]])
        precondition(selected.map { CFEqual($0, new) } == true)
        // A closed old window must not interfere with identifying the new one.
        let afterClose = try SafariPrivateBrowser.newWindow(previous: old, current: [new, old[1]])
        precondition(afterClose.map { CFEqual($0, new) } == true)
        let sameIdentity = AXUIElementCreateApplication(1)
        precondition(tryResult(previous: old, current: [sameIdentity, old[1]]) == nil)
        do {
            _ = try SafariPrivateBrowser.newWindow(previous: old, current: old + [new, AXUIElementCreateApplication(4)])
            fatalError("Ambiguous new windows were accepted")
        } catch { }
        print("PASS: Safari-only routing, launch-only startup and new-window identity/disambiguation (no UI actions or permission prompts).")
    }

    static func tryResult(previous: [AXUIElement], current: [AXUIElement]) -> AXUIElement? {
        do { return try SafariPrivateBrowser.newWindow(previous: previous, current: current) }
        catch { fatalError("Unexpected error: \(error)") }
    }
}
