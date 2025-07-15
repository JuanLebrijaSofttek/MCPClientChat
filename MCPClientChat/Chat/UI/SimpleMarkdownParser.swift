//
//  SimpleMarkdownParser.swift
//  MCPClientChat
//
//  Created by Claude Code on 15/07/25.
//

import Foundation
import SwiftUI

/// Simplified markdown parser for basic code block support
struct SimpleMarkdownParser {
    
    func parseText(_ text: String) -> [ParserResult] {
        var results: [ParserResult] = []
        
        // Split text by code blocks (```)
        let codeBlockPattern = "```"
        let components = text.components(separatedBy: codeBlockPattern)
        
        // Check if we have an incomplete code block (odd number of ``` markers)
        let hasIncompleteCodeBlock = components.count % 2 == 0
        
        for (index, component) in components.enumerated() {
            if component.isEmpty { continue }
            
            let isCodeBlock = index % 2 == 1 // Odd indices are code blocks
            
            // For the last component, check if it's an incomplete code block
            let isLastComponent = index == components.count - 1
            let isIncompleteCodeBlock = hasIncompleteCodeBlock && isLastComponent && !isCodeBlock
            
            if isCodeBlock {
                // Extract language from first line if present
                let lines = component.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                let language = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines)
                let code = lines.count > 1 ? String(lines[1]) : (lines.first.map(String.init) ?? "")
                
                let attributedString = AttributedString(code)
                results.append(ParserResult(
                    attributedString: attributedString,
                    isCodeBlock: true,
                    codeBlockLanguage: language?.isEmpty == false ? String(language!) : nil
                ))
            } else if isIncompleteCodeBlock {
                // Handle incomplete code block - treat as code block during streaming
                let lines = component.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                let language = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines)
                let code = lines.count > 1 ? String(lines[1]) : (lines.first.map(String.init) ?? "")
                
                let attributedString = AttributedString(code)
                results.append(ParserResult(
                    attributedString: attributedString,
                    isCodeBlock: true,
                    codeBlockLanguage: language?.isEmpty == false ? String(language!) : nil
                ))
            } else {
                // Regular text
                let attributedString = AttributedString(component)
                results.append(ParserResult(
                    attributedString: attributedString,
                    isCodeBlock: false,
                    codeBlockLanguage: nil
                ))
            }
        }
        
        return results
    }
}