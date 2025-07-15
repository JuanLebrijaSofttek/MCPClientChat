//
//  CodeBlockView.swift
//  MCPClientChat
//
//  Created by Claude Code on 15/07/25.
//

import SwiftUI

/// Based on the source code from Alfian Losari
/// https://www.youtube.com/watch?v=DYD6_3JD7jk&t=313s

struct CodeBlockView: View {
    
    let parserResult: ParserResult
    @State var isCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))

            ScrollView(.horizontal, showsIndicators: true) {
                Text(parserResult.attributedString)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .textSelection(.enabled)
            }
        }
        .cornerRadius(8)
        .inputRoundedBackground()
    }
    
    var header: some View {
        HStack {
            if let codeBlockLanguage = parserResult.codeBlockLanguage {
                Text(codeBlockLanguage.capitalized)
                    .fontWeight(.bold)
            }else{
                Text("Code")
                    .fontWeight(.bold)
            }
            Spacer()
            button
                .frame(height: 22)
        }
        .foregroundStyle(.primary)
    }
    
    @ViewBuilder
    var button: some View {
        if isCopied {
            HStack(spacing: 4){
                Image(systemName: "checkmark.circle")
                    .padding(.vertical, 2)
                Text("Copied")
            }
        } else {
            Button {
                let string = NSAttributedString(parserResult.attributedString).string
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(string, forType: .string)
                
                isCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isCopied = false

                }
            } label: {
                HStack(spacing: 4){
                    Image(systemName: "doc.on.doc")
                        .padding(.vertical, 2)
                    Text("Copy code")
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.primary)
        }
    }
}

struct CodeBlockView_Previews: PreviewProvider {
    
    static let parserResult: ParserResult = {
        let codeContent = """
        let message = "Hello, World!"
        print(message)
        """
        return ParserResult(
            attributedString: AttributedString(codeContent),
            isCodeBlock: true,
            codeBlockLanguage: "swift"
        )
    }()
    
    static var previews: some View {
        CodeBlockView(parserResult: parserResult)
    }
}