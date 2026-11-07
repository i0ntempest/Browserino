//
//  BrowserinoWindow.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 06.06.2024.
//

import Foundation
import AppKit

class BrowserinoWindow: NSPanel {
    static let selectorWidth: CGFloat = 250
    static let selectorHeight: CGFloat = 200

    private var footerExtraHeight: CGFloat = 0
    private var requestedFooterExtraHeight: CGFloat = 0
    
    public convenience init() {
        self.init(
            contentRect: .init(x: 0, y: 0, width: Self.selectorWidth, height: Self.selectorHeight),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.minSize = NSSize(width: Self.selectorWidth, height: Self.selectorHeight)
        
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        
        self.setFrameAutosaveName("prompt_Size")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyFooterHeight),
            name: NSWindow.didEndLiveResizeNotification,
            object: self
        )
        
        self.collectionBehavior = [.stationary, .ignoresCycle, .fullScreenAuxiliary, .canJoinAllSpaces]
        self.isOpaque = false
        self.level = NSWindow.Level(Int(CGShieldingWindowLevel()))
        self.isMovable = false
        self.deactivateDelay()
    }
    
    func setFooterExtraHeight(_ height: CGFloat) {
        requestedFooterExtraHeight = ceil(height)
        if !inLiveResize {
            applyFooterHeight()
        }
    }

    @objc private func applyFooterHeight() {
        let visibleFrame = screen?.visibleFrame
        let baseHeight = frame.height - footerExtraHeight
        let extraHeight = min(
            requestedFooterExtraHeight,
            visibleFrame.map { max(0, $0.height - baseHeight) } ?? requestedFooterExtraHeight
        )
        let delta = extraHeight - footerExtraHeight
        guard delta != 0 else { return }

        var expandedFrame = frame
        expandedFrame.size.height += delta
        expandedFrame.origin.y -= delta
        if let visibleFrame {
            // At the screen edge, keep the footer visible instead of growing offscreen.
            expandedFrame.origin.y = max(expandedFrame.origin.y, visibleFrame.minY)
        }
        footerExtraHeight = extraHeight
        minSize.height = Self.selectorHeight + extraHeight
        setFrame(expandedFrame, display: true)
    }

    override func close() {
        // Autosave the user's size without temporary space for a wrapped footer.
        requestedFooterExtraHeight = 0
        applyFooterHeight()
        if !frameAutosaveName.isEmpty {
            saveFrame(usingName: frameAutosaveName)
        }
        super.close()
    }

    func deactivateDelay() {
        self.hidesOnDeactivate = false
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            NSApplication.shared.activate(ignoringOtherApps: true)
            self.makeKeyAndOrderFront(nil)
            self.hidesOnDeactivate = true
        }
    }
}

extension NSPanel {
    open override var canBecomeKey: Bool { true }
}
