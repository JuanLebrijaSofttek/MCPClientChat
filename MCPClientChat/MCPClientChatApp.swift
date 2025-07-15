//
//  MCPClientChatApp.swift
//  MCPClientChat
//
//  Created by James Rochabrun on 3/3/25.
//

import MCPSwiftWrapper
import SwiftUI
// is there a repo called FoundMeWoo? is so, who is the owner?
@main
struct MCPClientChatApp: App {
    
    // MARK: Configuration
    private let USE_STREAMING = true // Toggle between streaming and non-streaming
    
    // MARK: Lifecycle
    init() {
        let OPENAI_API_KEY = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        let OPENAI_RESOURCE_NAME = ProcessInfo.processInfo.environment["OPENAI_RESOURCE_NAME"] ?? ""
        let OPENAI_API_VERSION = ProcessInfo.processInfo.environment["OPENAI_API_VERSION"] ?? ""
        
        // Azure configuration
        let azureConfig = AzureOpenAIConfiguration(resourceName: OPENAI_RESOURCE_NAME, openAIAPIKey: .apiKey(OPENAI_API_KEY), apiVersion: OPENAI_API_VERSION)
        let azureAIService = OpenAIServiceFactory.service(azureConfiguration: azureConfig)
        
        // Choose between streaming and non-streaming based on toggle
        let chatManager: ChatManager
        if USE_STREAMING {
            print("🔄 Using streaming chat manager")
            chatManager = OpenAIChatStreamManager(service: azureAIService)
        } else {
            print("🔄 Using non-streaming chat manager")
            chatManager = OpenAIChatNonStreamManager(service: azureAIService)
        }
        
        _chatManager = State(initialValue: chatManager)
        
        // Initialize settings manager and MCP client
        _settingsManager = State(initialValue: MCPSettingsManager())
        _mcpClient = State(initialValue: DynamicMCPClient())
    }
    
    // MARK: Internal
    
    var body: some Scene {
        WindowGroup {
            ChatView(chatManager: chatManager, settingsManager: settingsManager)
                .toolbar(removing: .title)
                .containerBackground(
                    .thinMaterial, for: .window)
                .toolbarBackgroundVisibility(
                    .hidden, for: .windowToolbar)
                .task {
                    await initializeMCPClient()
                }
                .onChange(of: settingsManager.activeConfiguration) { _, newConfig in
                    Task {
                        await updateMCPClient(with: newConfig)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
    
    // MARK: Private
    @State private var chatManager: ChatManager
    @State private var settingsManager: MCPSettingsManager
    @State private var mcpClient: DynamicMCPClient
    
    /// Initialize MCP client with active configuration
    private func initializeMCPClient() async {
        print("🔍 Available configurations: \(settingsManager.configurations.count)")
        print("🔍 Enabled configurations: \(settingsManager.enabledConfigurations.count)")
        print("🔍 Active configuration: \(settingsManager.activeConfiguration?.name ?? "None")")
        
        // Try to use active configuration, or fall back to first enabled one
        let configToUse = settingsManager.activeConfiguration ?? settingsManager.enabledConfigurations.first
        
        if let config = configToUse {
            print("🚀 Initializing MCP client with: \(config.name)")
            print("🔍 Config valid: \(config.isValid()), enabled: \(config.isEnabled)")
            
            mcpClient.initializeClient(with: config)
            
            // Wait for client to be ready and update chat manager
            if let client = try? await mcpClient.getClientAsync() {
                chatManager.updateClient(client)
                print("✅ Chat manager updated with MCP client")
            } else {
                print("❌ Failed to get MCP client, will retry...")
                // If initialization fails, try to fall back to the old hardcoded client
                await fallbackToLegacyClient()
            }
        } else {
            print("🟡 No enabled MCP configurations found, falling back to legacy client")
            await fallbackToLegacyClient()
        }
    }
    
    /// Fallback to the original hardcoded GitHub client if dynamic client fails
    private func fallbackToLegacyClient() async {
        print("🔄 Attempting fallback to legacy GitHub client...")
        let githubAuthManager = GitHubAuthManager()
        let legacyClient = GIthubMCPClient(authManager: githubAuthManager)
        if let client = try? await legacyClient.getClientAsync() {
            chatManager.updateClient(client)
            print("✅ Fallback successful: Chat manager updated with legacy client")
        } else {
            print("❌ Legacy client also failed to initialize")
        }
    }
    
    /// Update MCP client when configuration changes
    private func updateMCPClient(with config: MCPConfiguration?) async {
        if let config = config {
            print("🔄 Updating MCP client to: \(config.name)")
            mcpClient.initializeClient(with: config)
            
            if let client = try? await mcpClient.getClientAsync() {
                chatManager.updateClient(client)
                print("✅ Chat manager updated with new MCP client")
            }
        } else {
            print("🔌 Disconnecting MCP client")
            mcpClient.disconnect()
        }
    }

}
