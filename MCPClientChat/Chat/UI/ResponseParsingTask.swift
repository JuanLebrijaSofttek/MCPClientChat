//
//  ResponseParsingTask.swift
//  MCPClientChat
//
//  Created by Claude Code on 15/07/25.
//

import Foundation

/// Optimized streaming parser that minimizes re-parsing
/// Based on the source code from Alfian Losari
/// https://www.youtube.com/watch?v=DYD6_3JD7jk&t=313s

@MainActor
class ResponseParsingTask {
    private var lastParsedLength: Int = 0
    private var cachedResults: [ParserResult] = []
    private var lastText: String = ""
    private var isCompleted: Bool = false
    
    /// Optimized incremental parsing - only re-parses when necessary
    func parse(text: String, isComplete: Bool = false) -> AttributedOutput {
        // If text hasn't changed, return cached results
        if text == lastText && !isComplete {
            return AttributedOutput(string: text, results: cachedResults)
        }
        
        // If we're adding to existing text and it's not complete, use smart parsing
        if text.hasPrefix(lastText) && !isComplete && text.count > lastText.count {
            return incrementalParse(newText: text, isComplete: isComplete)
        }
        
        // Full re-parse (when complete or text structure changed)
        return fullParse(text: text, isComplete: isComplete)
    }
    
    /// Full parsing for complete responses or when text structure changes
    private func fullParse(text: String, isComplete: Bool) -> AttributedOutput {
        let parser = SimpleMarkdownParser()
        let results = parser.parseText(text)
        
        // Cache results
        cachedResults = results
        lastText = text
        lastParsedLength = text.count
        isCompleted = isComplete
        
        return AttributedOutput(string: text, results: results)
    }
    
    /// Incremental parsing for streaming content
    private func incrementalParse(newText: String, isComplete: Bool) -> AttributedOutput {
        let newChunk = String(newText.dropFirst(lastText.count))
        
        // Check if new chunk looks like it might contain markdown
        let needsFullReparse = shouldTriggerFullReparse(newChunk: newChunk, existingText: lastText)
        
        if needsFullReparse || isComplete {
            return fullParse(text: newText, isComplete: isComplete)
        }
        
        // Check if we're currently inside a code block
        let isInsideCodeBlock = isCurrentlyInsideCodeBlock(text: lastText)
        
        if let lastResult = cachedResults.last {
            if lastResult.isCodeBlock || isInsideCodeBlock {
                // Append to the last code block
                var updatedResults = cachedResults
                let combinedString = lastResult.plainString + newChunk
                
                updatedResults[updatedResults.count - 1] = ParserResult(
                    plainString: combinedString,
                    isCodeBlock: true,
                    codeBlockLanguage: lastResult.codeBlockLanguage
                )
                
                cachedResults = updatedResults
                lastText = newText
                
                return AttributedOutput(string: newText, results: updatedResults)
            } else {
                // Append to the last text block
                var updatedResults = cachedResults
                let combinedString = lastResult.plainString + newChunk
                
                updatedResults[updatedResults.count - 1] = ParserResult(
                    plainString: combinedString,
                    isCodeBlock: false,
                    codeBlockLanguage: nil
                )
                
                cachedResults = updatedResults
                lastText = newText
                
                return AttributedOutput(string: newText, results: updatedResults)
            }
        } else {
            // Add new text block
            let newResult = ParserResult(
                plainString: newChunk,
                isCodeBlock: isInsideCodeBlock,
                codeBlockLanguage: isInsideCodeBlock ? detectLanguage(from: lastText) : nil
            )
            
            cachedResults.append(newResult)
            lastText = newText
            
            return AttributedOutput(string: newText, results: cachedResults)
        }
    }
    
    /// Determines if full re-parsing is needed based on new content
    private func shouldTriggerFullReparse(newChunk: String, existingText: String) -> Bool {
        // Triggers that require full re-parsing
        let markdownTriggers = [
            "```",     // Code blocks
            "#",      // Headers
            "*",      // Lists or emphasis
            "-",      // Lists
            "[",      // Links
            "|",      // Tables
            ">",      // Blockquotes
            "\n\n"    // Paragraph breaks
        ]
        
        // Check if new chunk contains markdown syntax
        for trigger in markdownTriggers {
            if newChunk.contains(trigger) {
                return true
            }
        }
        
        // Check if we might be completing a markdown structure
        let lastChars = String(existingText.suffix(10))
        if lastChars.contains("```") || lastChars.contains("#") {
            return true
        }
        
        return false
    }
    
    /// Reset parser state for new stream
    func reset() {
        lastParsedLength = 0
        cachedResults = []
        lastText = ""
        isCompleted = false
    }
    
    /// Check if we're currently inside a code block
    private func isCurrentlyInsideCodeBlock(text: String) -> Bool {
        let codeBlockPattern = "```"
        let components = text.components(separatedBy: codeBlockPattern)
        
        // If we have an odd number of components, we're inside a code block
        return components.count % 2 == 0
    }
    
    /// Detect language from the code block opening
    private func detectLanguage(from text: String) -> String? {
        let codeBlockPattern = "```"
        let components = text.components(separatedBy: codeBlockPattern)
        
        // Find the last code block opening
        if components.count >= 2 {
            let lastCodeBlockStart = components[components.count - 1]
            // Get the first line after the ``` which should contain the language
            if let firstLine = lastCodeBlockStart.split(separator: "\n", maxSplits: 1).first {
                let language = String(firstLine).trimmingCharacters(in: .whitespacesAndNewlines)
                return language.isEmpty ? nil : language
            }
        }
        
        return nil
    }
}