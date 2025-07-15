//
//  BackgroundModifier.swift
//  MCPClientChat
//
//  Created by Claude Code on 15/07/25.
//

import SwiftUI

struct InputRoundedBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary, lineWidth: 1)
                    )
                    .opacity(0.6)
            )
    }
}

extension View {
    func inputRoundedBackground() -> some View {
        self.modifier(InputRoundedBackgroundModifier())
    }
}