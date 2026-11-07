//
//  View+ScrollClipDisabled.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 03.09.2025.
//

import SwiftUI

extension View {
    @ViewBuilder
    func scrollEdgeEffectDisabledCompat() -> some View {
        // SwiftUI 7 ships with the macOS 26 SDK. Older SDKs have no scroll-edge APIs.
        #if canImport(SwiftUI, _version: 7.0)
        if #available(macOS 26.0, *) {
            self
                .scrollEdgeEffectStyle(.soft, for: .all)
                .scrollEdgeEffectHidden(true, for: .all)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
