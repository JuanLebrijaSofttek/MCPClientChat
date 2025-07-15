//
//  ChatMessageView.swift
//  MCPClientChat
//
//  Created by James Rochabrun on 3/3/25.
//

import Foundation
import SwiftUI

struct ChatMessageView: View {
    
    // MARK: Internal
    
    /// The message to display
    let message: ChatMessage
    
    /// Whether to animate in the chat bubble
    let animateIn: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            chatIcon
            VStack(alignment: .leading) {
                chatName
                chatBody
            }
        }
        .opacity(bubbleOpacity)
        .animation(.easeIn(duration: 0.75), value: animationTrigger)
        .onAppear {
            adjustAnimationTriggerIfNecessary()
        }
    }
    
    // MARK: Private
    
    /// State used to animate in the chat bubble if `animateIn` is true
    @State private var animationTrigger = false
    
    private var bubbleOpacity: Double {
        guard animateIn else {
            return 1
        }
        return animationTrigger ? 1 : 0
    }
    
    private var chatIcon: some View {
        Image(systemName: message.role == .user ? "person.circle.fill" : "lightbulb.circle")
            .font(.title2)
            .frame(width: 24, height: 24)
            .foregroundColor(message.role == .user ? .primary : .orange)
    }
    
    private var chatName: some View {
        Text(message.role == .user ? "You" : "Assistant")
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, maxHeight: 24, alignment: .leading)
    }
    
    @ViewBuilder
    private var chatBody: some View {
        if message.role == .user {
            Text(LocalizedStringKey(message.text))
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        } else {
            HStack(alignment: .top, spacing: 0) {
                // Always reserve space for progress indicator to prevent layout shifts
                Group {
                    if message.isWaitingForFirstText {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        // Invisible placeholder to maintain consistent spacing
                        ProgressView()
                            .scaleEffect(0.8)
                            .opacity(0)
                    }
                }
                .frame(width: message.isWaitingForFirstText ? 20 : 0, height: 20) // Fixed dimensions to prevent layout shifts
                
                if !message.text.isEmpty {
                    StreamingTextView(text: message.text)
                        .foregroundColor(.primary)
                } else if !message.isWaitingForFirstText {
                    // Invisible placeholder text to maintain layout consistency
                    Text(" ")
                        .opacity(0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 20) // Ensure consistent minimum height
        }
    }
    
    private func adjustAnimationTriggerIfNecessary() {
        guard animateIn else {
            return
        }
        animationTrigger = true
    }
    
}

#Preview {
    ChatMessageView(message: ChatMessage(text: "hello", role: .assistant), animateIn: false)
        .frame(maxWidth: .infinity)
        .padding()
}

// MARK: - StreamingTextView

private struct StreamingTextView: View {
    let text: String
    @State private var displayedText = ""
    @State private var animationTask: Task<Void, Never>?
    
    var body: some View {
        Text(LocalizedStringKey(displayedText))
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .onChange(of: text) { _, newValue in
                updateDisplayedText(to: newValue)
            }
            .onAppear {
                updateDisplayedText(to: text)
            }
            .onDisappear {
                animationTask?.cancel()
            }
    }
    
    private func updateDisplayedText(to newText: String) {
        // Cancel any existing animation
        animationTask?.cancel()
        
        // If text is getting shorter or significantly different, update immediately
        if newText.count < displayedText.count || !newText.hasPrefix(displayedText) {
            displayedText = newText
            return
        }
        
        // If text is the same, no need to animate
        if displayedText == newText {
            return
        }
        
        // Animate the new characters
        animationTask = Task {
            let startIndex = displayedText.count
            let endIndex = newText.count
            
            for i in startIndex..<endIndex {
                if Task.isCancelled { break }
                
                let index = newText.index(newText.startIndex, offsetBy: i + 1)
                let substring = String(newText[..<index])
                
                await MainActor.run {
                    displayedText = substring
                }
                
                // Small delay for smooth animation (adjust as needed)
                try? await Task.sleep(nanoseconds: 1_000_000) // 20ms
            }
        }
    }
}
