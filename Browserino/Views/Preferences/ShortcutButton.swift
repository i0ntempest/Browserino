//
//  ShortcutButton.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 10.06.2024.
//

import SwiftUI

struct ShortcutButton: View {
    let browserId: String
    
    @AppStorage("shortcuts") private var shortcuts: [String: String] = [:]
    
    @State private var isRecording: Bool = false
    @FocusState private var focus: Bool
    
    private var recordedKey: String? {
        guard let key = shortcuts[browserId], !key.isEmpty,
            key != String(KeyEquivalent.escape.character)
        else { return nil }
        return key
    }

    var body: some View {
        if isRecording {
            Text("Press any key")
                .padding(5)
                .contentShape(.rect)
                .focusable()
                .focused($focus)
                .onChange(of: focus) { newFocus in
                    isRecording = newFocus
                }
                .onKeyPressCompat { key in
                    isRecording = false
                    if key.isEmpty || key == String(KeyEquivalent.escape.character) {
                        shortcuts[browserId] = nil
                        return true
                    }

                    if let shortcut = shortcuts.first(where: { $0.value == key }) {
                        shortcuts[shortcut.key] = nil
                    }
                    shortcuts[browserId] = key
                    
                    return true
                }
        } else {
            Button(action: {
                isRecording = true
                focus = true
            }, label: {
                Text(recordedKey ?? "Record")
                    .padding(5)
            })
            .opacity(recordedKey == nil ? 0.5 : 1)
            .help("Record a key, or press Escape while recording to clear the shortcut.")
            .onAppear {
                // Repair empty or Escape entries recorded by older versions.
                if shortcuts[browserId] != nil && recordedKey == nil {
                    shortcuts[browserId] = nil
                }
            }
        }
    }
}
