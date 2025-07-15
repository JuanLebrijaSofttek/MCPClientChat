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
            
            ScrollViewReader { proxy in
                ScrollView([.vertical], showsIndicators: false) {
                    HStack{
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .top, spacing: 0) {
                                Text(parserResult.plainString)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id("codeContent")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
//                            .border(.green)
                        }
                        .padding(12)
                        .padding(.bottom, 16)
                        .frame(minHeight: 0)
                        Spacer()
                    }
                }
//                .border(.blue)
                .frame(minHeight: 40, alignment: .leading)
                .onChange(of: parserResult.plainString) { _, _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("codeContent", anchor: .bottom)
                    }
                }
                .scrollDisabled(true)
            }
            .cornerRadius(8)
            .inputRoundedBackground()
        }
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
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(parserResult.plainString, forType: .string)
                
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
