//
//  GithubMCPClient.swift
//  MCPClientChat
//
//  Created by James Rochabrun on 3/3/25.
//

import Foundation
import MCPClient
import SwiftUI

final class GIthubMCPClient {
    
    // MARK: Lifecycle
    
    init(authManager: GitHubAuthManager) {
        self.authManager = authManager
        print("🏃 Runnning GIthubMCPClient")
        initializeClient()
    }
    
    private func initializeClient() {
        initializationTask = Task {
            do {
                // Get token from auth manager
                let currentToken = await authManager.accessToken
                let token: String?
                if let currentToken = currentToken {
                    token = currentToken
                } else {
                    token = await authManager.loadStoredToken()
                }
                
                guard let token = token else {
                    print("❌ No GitHub token available. Please authenticate first.")
                    clientInitialized.continuation.yield(nil)
                    clientInitialized.continuation.finish()
                    return
                }
                
                print("🟡 Starting MCP client initialization...")
                self.client = try await MCPClient(
                    info: .init(name: "GIthubMCPClient", version: "1.0.0"),
                    transport: .stdioProcess(
                        "npx",
                        args: ["-y", "@modelcontextprotocol/server-github"],
                        env: ["GITHUB_PERSONAL_ACCESS_TOKEN" : token],
                        verbose: false),
                    capabilities: .init())
                clientInitialized.continuation.yield(self.client)
                clientInitialized.continuation.finish()
                if let _ = try await self.client?.openAITools(){
                    print("✅ good")
                } else {
                    print("❌ Could not retrieve tools")
                }
                print("☺️ Initialized MCP Client: GIthubMCPClient")
            } catch {
                print("❌ Failed to initialize MCPClient: \(error)")
                clientInitialized.continuation.yield(nil)
                clientInitialized.continuation.finish()
                
                // Retry initialization after a delay
                print("🔄 Retrying MCP client initialization in 3 seconds...")
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled {
                    initializeClient()
                }
            }
        }
    }
    
    // MARK: Internal
    
    /// Modern async/await approach with timeout
    func getClientAsync() async throws -> MCPClient? {
        // First check if we already have a client
        if let client = client {
            print("🟡 Using existing client")
            return client
        }
        
        // Wait for client initialization with timeout
        print("🟡 Waiting for client initialization...")
        for await client in clientInitialized.stream {
            print("🈺 client: \(try await String(describing: client?.openAITools().debugDescription))")
            return client
        }
        return nil // Stream completed without a client
    }
    
    /// Check if client is ready without waiting
    func isClientReady() -> Bool {
        return client != nil
    }
    
    /// Cancel initialization if needed
    func cancelInitialization() {
        print("🟡 Cancelling MCP client initialization")
        initializationTask?.cancel()
    }
    
    // MARK: Private
    private let authManager: GitHubAuthManager
    private var client: MCPClient?
    private let clientInitialized = AsyncStream.makeStream(of: MCPClient?.self)
    private var initializationTask: Task<Void, Never>?
}
