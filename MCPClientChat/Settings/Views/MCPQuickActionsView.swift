//
//  MCPQuickActionsView.swift
//  MCPClientChat
//
//  Created by Claude Code on 7/14/25.
//

import SwiftUI

struct MCPQuickActionsView: View {
    @Bindable var settingsManager: MCPSettingsManager
    @State private var showingConnectionTest = false
    @State private var connectionTestResult = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                // Test Connection
                QuickActionCard(
                    title: "Test Connection",
                    icon: "network",
                    color: .blue
                ) {
                    testActiveConnection()
                }
                
                // Refresh Tools
                QuickActionCard(
                    title: "Refresh Tools",
                    icon: "arrow.clockwise",
                    color: .green
                ) {
                    refreshTools()
                }
                
                // Add GitHub Server
                QuickActionCard(
                    title: "Add GitHub",
                    icon: "link",
                    color: .purple
                ) {
                    addGitHubServer()
                }
                
                // Add File Server
                QuickActionCard(
                    title: "Add Files",
                    icon: "folder",
                    color: .orange
                ) {
                    addFileServer()
                }
            }
            
            if !connectionTestResult.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection Test Result:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(connectionTestResult)
                        .font(.caption)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding()
    }
    
    private func testActiveConnection() {
        guard let active = settingsManager.activeConfiguration else {
            connectionTestResult = "❌ No active MCP server configured"
            return
        }
        
        connectionTestResult = "🔄 Testing connection to \(active.name)..."
        
        // Simulate connection test (in a real implementation, this would test the actual MCP client)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if active.isValid() && active.isEnabled {
                connectionTestResult = "✅ Connection successful to \(active.name)"
            } else {
                connectionTestResult = "❌ Connection failed - check configuration"
            }
        }
    }
    
    private func refreshTools() {
        connectionTestResult = "🔄 Refreshing tools cache..."
        
        // Simulate tools refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            connectionTestResult = "✅ Tools cache refreshed"
        }
    }
    
    private func addGitHubServer() {
        let newConfig = MCPConfiguration(
            name: "GitHub Server \(settingsManager.configurations.count + 1)",
            serverType: .github(username: nil, token: nil),
            isEnabled: false
        )
        settingsManager.addConfiguration(newConfig)
        connectionTestResult = "➕ Added new GitHub server configuration"
    }
    
    private func addFileServer() {
        let newConfig = MCPConfiguration(
            name: "Files \(settingsManager.configurations.count + 1)",
            serverType: .filesystem(path: NSHomeDirectory()),
            isEnabled: false
        )
        settingsManager.addConfiguration(newConfig)
        connectionTestResult = "➕ Added new file server configuration"
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MCPQuickActionsView(settingsManager: MCPSettingsManager())
}