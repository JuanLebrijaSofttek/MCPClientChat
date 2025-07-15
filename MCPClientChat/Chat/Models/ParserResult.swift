//
//  ParserResult.swift
//  MCPClientChat
//
//  Created by Claude Code on 15/07/25.
//

import Foundation

/// Based on the source code from Alfian Losari
/// https://www.youtube.com/watch?v=DYD6_3JD7jk&t=313s

public struct ParserResult: Identifiable {
    
    public let id = UUID()
    public let attributedString: AttributedString
    public let isCodeBlock: Bool
    public let codeBlockLanguage: String?
    
    public init(attributedString: AttributedString, isCodeBlock: Bool, codeBlockLanguage: String?) {
        self.attributedString = attributedString
        self.isCodeBlock = isCodeBlock
        self.codeBlockLanguage = codeBlockLanguage
    }
}

public struct AttributedOutput {
    public let string: String
    public let results: [ParserResult]
}