//
//  PromptItem.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 10.06.2024.
//

import SwiftUI

struct PromptItem: View {
    var browser: URL
    var urls: [URL]
    var bundle: Bundle
    var shortcut: String?
    var isFirstBrowser: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(bundle.infoDictionary!["CFBundleName"] as! String)
                    .font(
                        .system(size: 12, weight: .bold)
                    )
                
                Spacer()
                
                if isFirstBrowser {
                    Image(systemName: "space")
                        .foregroundStyle(.yellow)
                        .modifier(ShortcutBadgeStyle())
                        .accessibilityLabel("Space")
                }

                if let shortcut {
                    Text(shortcut)
                        .modifier(ShortcutBadgeStyle())
                }
                
                Spacer()
                    .frame(width: 8)
                
                Image(
                    nsImage: NSWorkspace.shared.icon(
                        forFile: bundle.bundlePath
                    )
                )
                .resizable()
                .frame(width: 24, height: 24)
            }
            .padding(8)
        }
        .if(shortcut != nil) {
            return $0.keyboardShortcut(
                KeyEquivalent(shortcut!.lowercased().first!),
                modifiers: [.shift]
            ).background {
                Button(action: action) {}
                    .opacity(0)
                    .keyboardShortcut(
                        KeyEquivalent(shortcut!.lowercased().first!),
                        modifiers: []
                    )
            }
        }
    }
}

private struct ShortcutBadgeStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption)
            .frame(minWidth: 4)
            .opacity(0.5)
            .padding(5)
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(4)
    }
}
