//
//  DynamicMCPClient.swift
//  MCPClientChat
//
//  Created by Claude Code on 7/14/25.
//

import Foundation
import MCPClient
import SwiftUI

/// Dynamic MCP client that can be configured with different server types
@MainActor
@Observable
final class DynamicMCPClient {
    
    // MARK: - Properties
    
    /// Current MCP client instance
    private(set) var client: MCPClient?
    
    /// Current configuration
    private(set) var currentConfiguration: MCPConfiguration?
    
    /// Initialization status
    private(set) var isInitializing = false
    private(set) var isReady = false
    private(set) var lastError: String?
    
    /// Client stream for async operations
    private let clientStream = AsyncStream.makeStream(of: MCPClient?.self)
    private var initializationTask: Task<Void, Never>?
    
    // MARK: - Lifecycle
    
    init() {
        print("🏃 Running DynamicMCPClient")
    }
    
    // MARK: - Public Methods
    
    /// Initialize client with a specific configuration
    func initializeClient(with configuration: MCPConfiguration) {
        guard configuration.isValid() && configuration.isEnabled else {
            print("❌ Invalid or disabled configuration: \(configuration.name)")
            lastError = "Invalid or disabled configuration"
            return
        }
        
        // Cancel any existing initialization
        cancelInitialization()
        
        currentConfiguration = configuration
        isInitializing = true
        isReady = false
        lastError = nil
        
        print("🟡 Starting MCP client initialization for: \(configuration.name)")
        
        initializationTask = Task {
            do {
                let transportDetails = configuration.getTransportDetails()
                
                self.client = try await MCPClient(
                    info: .init(name: configuration.name, version: "1.0.0"),
                    transport: .stdioProcess(
                        transportDetails.command,
                        args: transportDetails.args,
                        env: transportDetails.env,
                        verbose: false
                    ),
                    capabilities: .init()
                )
                
                // Test the connection by fetching tools
                if let tools = try await self.client?.openAITools() {
                    print("✅ Successfully initialized MCP client: \(configuration.name) with \(tools.count) tools")
                    self.isReady = true
                } else {
                    print("❌ Could not retrieve tools from: \(configuration.name)")
                    self.lastError = "Could not retrieve tools"
                }
                
                self.clientStream.continuation.yield(self.client)
                
            } catch {
                print("❌ Failed to initialize MCP client for \(configuration.name): \(error)")
                self.lastError = error.localizedDescription
                self.client = nil
                self.clientStream.continuation.yield(nil)
                
                // Retry initialization after a delay for certain errors
                if shouldRetry(error: error) {
                    print("🔄 Retrying MCP client initialization in 3 seconds...")
                    try? await Task.sleep(for: .seconds(3))
                    if !Task.isCancelled && self.currentConfiguration?.id == configuration.id {
                        self.initializeClient(with: configuration)
                        return
                    }
                }
            }
            
            self.isInitializing = false
        }
    }
    
    /// Get client with async/await
    func getClientAsync() async throws -> MCPClient? {
        // Return existing client if ready
        if isReady, let client = client {
            return client
        }
        
        // Wait for initialization to complete
        if isInitializing {
            print("🟡 Waiting for client initialization...")
            for await client in clientStream.stream {
                return client
            }
        }
        
        return nil
    }
    
    /// Check if client is ready
    func isClientReady() -> Bool {
        return isReady && client != nil
    }
    
    /// Cancel current initialization
    func cancelInitialization() {
        print("🟡 Cancelling MCP client initialization")
        initializationTask?.cancel()
        initializationTask = nil
        isInitializing = false
    }
    
    /// Disconnect and cleanup
    func disconnect() {
        cancelInitialization()
        client = nil
        currentConfiguration = nil
        isReady = false
        lastError = nil
        print("🔌 Disconnected MCP client")
    }
    
    // MARK: - Private Methods
    
    private func shouldRetry(error: Error) -> Bool {
        // Retry for network-related errors, but not for configuration errors
        let errorString = error.localizedDescription.lowercased()
        return errorString.contains("network") || 
               errorString.contains("connection") || 
               errorString.contains("timeout")
    }
}

// MARK: - Client Status

extension DynamicMCPClient {
    
    /// Get current status description
    var statusDescription: String {
        if isInitializing {
            return "Initializing..."
        } else if isReady {
            return "Connected"
        } else if let error = lastError {
            return "Error: \(error)"
        } else {
            return "Disconnected"
        }
    }
    
    /// Get status color for UI
    var statusColor: Color {
        if isInitializing {
            return .orange
        } else if isReady {
            return .green
        } else if lastError != nil {
            return .red
        } else {
            return .secondary
        }
    }
}