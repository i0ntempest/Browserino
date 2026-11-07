//
//  PromptView.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 06.06.2024.
//

import AppKit
import SwiftUI

struct PromptView: View {
    private static let footerIconSize: CGFloat = 24

    @AppStorage("browsers") private var browsers: [URL] = []
    @AppStorage("hiddenBrowsers") private var hiddenBrowsers: [URL] = []
    @AppStorage("apps") private var apps: [App] = []
    @AppStorage("shortcuts") private var shortcuts: [String: String] = [:]

    @AppStorage("copy_closeAfterCopy") private var closeAfterCopy: Bool = false
    @AppStorage("copy_alternativeShortcut") private var alternativeShortcut: Bool = false
    @AppStorage("apps_atTop") private var appsAtTop: Bool = true

    let urls: [URL]

    @State private var opacityAnimation = 0.0
    @State private var selected = 0
    @State private var spaceKeyMonitor: Any?
    @State private var isShiftPressed = false
    @State private var modifierMonitor: Any?
    @State private var footerExtraHeight: CGFloat = 0
    @FocusState private var focused: Bool

    var appsForUrls: [App] {
        urls.flatMap { url in
            return apps.filter { app in
                url.matchesHost(app.host)
            }
        }
        .filter {
            !browsers.contains($0.app)
        }
    }

    var visibleBrowsers: [URL] {
        browsers.filter { !hiddenBrowsers.contains($0) }
    }

    func openUrlsInApp(app: App) {
        let urls =
            if app.schemeOverride.isEmpty {
                urls
            } else {
                urls.map {
                    let url = NSURLComponents.init(
                        url: $0,
                        resolvingAgainstBaseURL: true
                    )
                    url!.scheme = app.schemeOverride

                    return url!.url!
                }
            }

        BrowserUtil.openURL(
            urls,
            app: app.app,
            isIncognito: false
        )
    }

    var body: some View {
        VStack {
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        if !appsForUrls.isEmpty && appsAtTop {
                            ForEach(Array(appsForUrls.enumerated()), id: \.offset) { index, app in
                                if let bundle = Bundle(url: app.app) {
                                    PromptItem(
                                        browser: app.app,
                                        urls: urls,
                                        bundle: bundle,
                                        shortcut: shortcuts[bundle.bundleIdentifier!]
                                    ) {
                                        openUrlsInApp(app: app)
                                    }
                                    .id(index)
                                    .buttonStyle(
                                        SelectButtonStyle(
                                            selected: selected == index
                                        )
                                    )
                                }
                            }
                            
                            Divider()
                        }
                        
                        ForEach(Array(visibleBrowsers.enumerated()), id: \.offset) {
                            index, browser in
                            if let bundle = Bundle(url: browser) {
                                PromptItem(
                                    browser: browser,
                                    urls: urls,
                                    bundle: bundle,
                                    shortcut: shortcuts[bundle.bundleIdentifier!],
                                    isFirstBrowser: index == 0
                                ) {
                                    BrowserUtil.openURL(
                                        urls,
                                        app: browser,
                                        isIncognito: NSEvent.modifierFlags.contains(.shift)
                                    )
                                }
                                .id(index + (appsAtTop ? appsForUrls.count : 0))
                                .buttonStyle(
                                    SelectButtonStyle(
                                        selected: selected == index + (appsAtTop ? appsForUrls.count : 0)
                                    )
                                )
                            }
                        }

                        if !appsForUrls.isEmpty && !appsAtTop {
                            Divider()

                            ForEach(Array(appsForUrls.enumerated()), id: \.offset) { index, app in
                                if let bundle = Bundle(url: app.app) {
                                    PromptItem(
                                        browser: app.app,
                                        urls: urls,
                                        bundle: bundle,
                                        shortcut: shortcuts[bundle.bundleIdentifier!]
                                    ) {
                                        openUrlsInApp(app: app)
                                    }
                                    .id(visibleBrowsers.count + index)
                                    .buttonStyle(
                                        SelectButtonStyle(
                                            selected: selected == visibleBrowsers.count + index
                                        )
                                    )
                                }
                            }
                        }
                    }
                }
                .focusable()
                .focusEffectDisabledCompat()
                .focused($focused)
                .onMoveCommand { command in
                    if command == .up {
                        selected = max(0, selected - 1)
                        scrollViewProxy.scrollTo(selected, anchor: .center)
                    } else if command == .down {
                        selected = min(visibleBrowsers.count + appsForUrls.count - 1, selected + 1)
                        scrollViewProxy.scrollTo(selected, anchor: .center)
                    }
                }
                .background {
                    Button(action: {
                        if appsAtTop {
                            if selected < appsForUrls.count {
                                openUrlsInApp(app: appsForUrls[selected])
                            } else {
                                BrowserUtil.openURL(
                                    urls,
                                    app: visibleBrowsers[selected - appsForUrls.count],
                                    isIncognito: false
                                )
                            }
                        } else {
                            if selected < visibleBrowsers.count {
                                BrowserUtil.openURL(
                                    urls,
                                    app: visibleBrowsers[selected],
                                    isIncognito: false
                                )
                            } else {
                                openUrlsInApp(app: appsForUrls[selected - visibleBrowsers.count])
                            }
                        }
                    }) {}
                    .opacity(0)
                    .keyboardShortcut(.defaultAction)

                    Button(action: {
                        if appsAtTop {
                            if selected < appsForUrls.count {
                                openUrlsInApp(app: appsForUrls[selected])
                            } else {
                                BrowserUtil.openURL(
                                    urls,
                                    app: visibleBrowsers[selected - appsForUrls.count],
                                    isIncognito: true
                                )
                            }
                        } else {
                            if selected < visibleBrowsers.count {
                                BrowserUtil.openURL(
                                    urls,
                                    app: visibleBrowsers[selected],
                                    isIncognito: true
                                )
                            } else {
                                openUrlsInApp(app: appsForUrls[selected - visibleBrowsers.count])
                            }
                        }
                    }) {}
                    .opacity(0)
                    .keyboardShortcut(.return, modifiers: [.shift])

                    Button(action: {
                        NSApplication.shared.keyWindow?.close()
                    }) {}
                    .opacity(0)
                    .keyboardShortcut(.cancelAction)
                }
                .onAppear {
                    focused.toggle()
                    withAnimation(.interactiveSpring(duration: 0.3)) {
                        opacityAnimation = 1
                    }
                }
                .scrollEdgeEffectDisabledCompat()
            }

            Divider()

            if let host = urls.first?.host() {
                HStack(spacing: 16) {
                    Button(action: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.declareTypes([.string], owner: nil)
                        pasteboard.setString(urls.first?.absoluteString ?? "", forType: .string)

                        if closeAfterCopy {
                            NSApplication.shared.keyWindow?.close()
                        }
                    }) {
                        Text(host)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(
                        KeyEquivalent("c"),
                        modifiers: alternativeShortcut ? [.command] : [.command, .option]
                    )
                    .toolTip(urls.first?.absoluteString ?? "")

                    // Both variants are available since macOS 12; keep their footprint identical.
                    Image(systemName: isShiftPressed ? "theatermasks.circle.fill" : "theatermasks.circle")
                        .font(.system(size: 20))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(isShiftPressed ? Color.primary : Color.secondary)
                        .opacity(isShiftPressed ? 1 : 0.45)
                        .frame(width: Self.footerIconSize, height: Self.footerIconSize)
                        .accessibilityLabel("Private browsing")
                        .accessibilityValue(isShiftPressed ? "On" : "Off")
                        .help(isShiftPressed ? "Private browsing — Shift is held" : "Hold Shift for private browsing")
                }
                .padding(.horizontal, 8)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: FooterHeightPreferenceKey.self,
                            value: geometry.size.height
                        )
                    }
                }

            }
        }
        .padding(12)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .background(BlurredView())
        .background(FooterWindowSizing(extraHeight: footerExtraHeight))
        .onPreferenceChange(FooterHeightPreferenceKey.self) { height in
            footerExtraHeight = max(0, height - Self.footerIconSize)
        }
        .opacity(opacityAnimation)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            if spaceKeyMonitor == nil {
                spaceKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    // Handle Space before the focused control can consume it.
                    guard event.keyCode == 49,
                        event.modifierFlags.intersection([.command, .control, .option]).isEmpty
                    else { return event }

                    if let browser = visibleBrowsers.first {
                        BrowserUtil.openURL(
                            urls,
                            app: browser,
                            isIncognito: event.modifierFlags.contains(.shift)
                        )
                    }
                    return nil
                }
            }
            isShiftPressed = NSEvent.modifierFlags.contains(.shift)
            if modifierMonitor == nil {
                modifierMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                    isShiftPressed = event.modifierFlags.contains(.shift)
                    return event
                }
            }
        }
        .onDisappear {
            if let spaceKeyMonitor {
                NSEvent.removeMonitor(spaceKeyMonitor)
            }
            spaceKeyMonitor = nil
            if let modifierMonitor {
                NSEvent.removeMonitor(modifierMonitor)
            }
            modifierMonitor = nil
        }
    }
}

#Preview {
    PromptView(urls: [])
}

private struct FooterHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct FooterWindowSizing: NSViewRepresentable {
    let extraHeight: CGFloat

    class SizingView: NSView {
        var extraHeight: CGFloat = 0

        func updateWindow() {
            // Resize after SwiftUI has finished measuring the footer.
            DispatchQueue.main.async { [weak self] in
                guard let self, let window = self.window as? BrowserinoWindow, window.isVisible else { return }
                window.setFooterExtraHeight(self.extraHeight)
            }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            updateWindow()
        }
    }

    func makeNSView(context: Context) -> SizingView {
        SizingView()
    }

    func updateNSView(_ view: SizingView, context: Context) {
        view.extraHeight = extraHeight
        view.updateWindow()
    }
}
