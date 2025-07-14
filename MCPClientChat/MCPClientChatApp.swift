//
//  MCPClientChatApp.swift
//  MCPClientChat
//
//  Created by James Rochabrun on 3/3/25.
//

import MCPSwiftWrapper
import SwiftUI

@main
struct MCPClientChatApp: App {
    
    // MARK: Lifecycle
    init() {
        let OPENAI_API_KEY = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        let OPENAI_RESOURCE_NAME = ProcessInfo.processInfo.environment["OPENAI_RESOURCE_NAME"] ?? ""
        let OPENAI_API_VERSION = ProcessInfo.processInfo.environment["OPENAI_API_VERSION"] ?? ""
        // Azure with Streaming (Recommended)
        let azureConfig = AzureOpenAIConfiguration(resourceName: OPENAI_RESOURCE_NAME, openAIAPIKey: .apiKey(OPENAI_API_KEY), apiVersion: OPENAI_API_VERSION)
        let azureAIService = OpenAIServiceFactory.service(azureConfiguration: azureConfig)
        let azureAIChatStreamManager = OpenAIChatStreamManager(service: azureAIService)
        _chatManager = State(initialValue: azureAIChatStreamManager)
    }
    
    // MARK: Internal
    
    var body: some Scene {
        WindowGroup {
            ChatView(chatManager: chatManager)
                .toolbar(removing: .title)
                .containerBackground(
                    .thinMaterial, for: .window)
                .toolbarBackgroundVisibility(
                    .hidden, for: .windowToolbar)
                .task {
                    if let client = try? await githubClient.getClientAsync() {
                        chatManager.updateClient(client)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
    
    // MARK: Private
    @State private var chatManager: ChatManager
    private let githubClient = GIthubMCPClient()

}
