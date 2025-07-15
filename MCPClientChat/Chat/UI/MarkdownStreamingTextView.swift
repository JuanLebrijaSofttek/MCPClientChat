//
//  MarkdownStreamingTextView.swift
//  MCPClientChat
//
//  Created by Claude Code on 15/07/25.
//

import SwiftUI

struct MarkdownStreamingTextView: View {
    let text: String
    @State private var displayedText = ""
    @State private var animationTask: Task<Void, Never>?
    @State private var parsingTask = ResponseParsingTask()
    @State private var parsedResults: [ParserResult] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parsedResults) { result in
                if result.isCodeBlock {
                    CodeBlockView(parserResult: result)
                } else {
                    Text(result.attributedString)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
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
            parseMarkdown(newText, isComplete: true)
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
                    parseMarkdown(substring, isComplete: i == endIndex - 1)
                }
                
                // Small delay for smooth animation
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
    }
    
    private func parseMarkdown(_ text: String, isComplete: Bool) {
        let output = parsingTask.parse(text: text, isComplete: isComplete)
        parsedResults = output.results
    }
}

#Preview {
    MarkdownStreamingTextView(text: """
    Here's some **bold text** and *italic text*.
    
    ```swift
    let message = "Hello, World!"
    print(message)
    ```
    
    And here's a list:
    - Item 1
    - Item 2
    - Item 3
    """)
    .padding()
}