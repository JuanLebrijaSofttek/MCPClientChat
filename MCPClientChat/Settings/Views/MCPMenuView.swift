//
//  MCPMenuView.swift
//  MCPClientChat
//
//  Created by Claude Code on 7/14/25.
//

import SwiftUI

struct MCPMenuView: View {
    @Bindable var settingsManager: MCPSettingsManager
    @State private var showingAddSheet = false
    @State private var selectedTemplate: MCPTemplate?
    
    var body: some View {
        Menu {
            // Current Status Section
            Section("Current MCP Server") {
                if let active = settingsManager.activeConfiguration {
                    Label(active.name, systemImage: statusIcon(for: active))
                        .foregroundColor(statusColor(for: active))
                } else {
                    Label("No Active Server", systemImage: "xmark.circle")
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Quick Server Selection
            Section("Switch to Server") {
                ForEach(settingsManager.enabledConfigurations) { config in
                    Button {
                        settingsManager.setActiveConfiguration(config)
                    } label: {
                        HStack {
                            Label(config.name, systemImage: serverIcon(for: config.serverType))
                            if settingsManager.activeConfiguration?.id == config.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(settingsManager.activeConfiguration?.id == config.id)
                }
                
                if settingsManager.enabledConfigurations.isEmpty {
                    Text("No enabled servers")
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Quick Add Templates
            Section("Add New Server") {
                ForEach(MCPTemplate.allTemplates) { template in
                    Button {
                        selectedTemplate = template
                        showingAddSheet = true
                    } label: {
                        Label(template.name, systemImage: template.icon)
                    }
                }
            }
            
            Divider()
            
            // Server Management
            Section("Manage Servers") {
                Button {
                    if let first = settingsManager.configurations.first(where: { !$0.isEnabled }) {
                        var updated = first
                        updated.isEnabled = true
                        settingsManager.updateConfiguration(updated)
                    }
                } label: {
                    Label("Enable Disabled Servers", systemImage: "power")
                }
                .disabled(settingsManager.configurations.allSatisfy { $0.isEnabled })
                
                Button {
                    settingsManager.setActiveConfiguration(nil)
                } label: {
                    Label("Disconnect All", systemImage: "minus.circle")
                }
                .disabled(settingsManager.activeConfiguration == nil)
            }
            
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "server.rack")
                if let active = settingsManager.activeConfiguration {
                    Circle()
                        .fill(statusColor(for: active))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .help("MCP Servers")
        .sheet(isPresented: $showingAddSheet) {
            if let template = selectedTemplate {
                MCPConfigurationEditView(
                    configuration: template.createConfiguration(),
                    isNew: true
                ) { config in
                    settingsManager.addConfiguration(config)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func statusIcon(for config: MCPConfiguration) -> String {
        if config.isEnabled && config.isValid() {
            return "checkmark.circle.fill"
        } else if !config.isValid() {
            return "exclamationmark.triangle.fill"
        } else {
            return "pause.circle.fill"
        }
    }
    
    private func statusColor(for config: MCPConfiguration) -> Color {
        if config.isEnabled && config.isValid() {
            return .green
        } else if !config.isValid() {
            return .red
        } else {
            return .orange
        }
    }
    
    private func serverIcon(for serverType: MCPConfiguration.MCPServerType) -> String {
        switch serverType {
        case .github:
            return "link"
        case .filesystem:
            return "folder"
        case .sqlite:
            return "cylinder"
        case .custom:
            return "terminal"
        }
    }
}

// MARK: - MCP Templates

struct MCPTemplate: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    let serverType: MCPConfiguration.MCPServerType
    
    func createConfiguration() -> MCPConfiguration {
        MCPConfiguration(
            name: name,
            serverType: serverType,
            isEnabled: false
        )
    }
    
    static let allTemplates: [MCPTemplate] = [
        MCPTemplate(
            name: "GitHub Repository",
            icon: "link",
            description: "Access GitHub repositories and issues",
            serverType: .github(username: nil, token: nil)
        ),
        MCPTemplate(
            name: "Local Files",
            icon: "folder",
            description: "Read and write local files",
            serverType: .filesystem(path: NSHomeDirectory())
        ),
        MCPTemplate(
            name: "SQLite Database",
            icon: "cylinder",
            description: "Query SQLite databases",
            serverType: .sqlite(path: "")
        ),
        MCPTemplate(
            name: "Memory Server",
            icon: "brain",
            description: "In-memory knowledge storage",
            serverType: .custom(
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-memory"],
                env: [:]
            )
        ),
        MCPTemplate(
            name: "Web Search",
            icon: "magnifyingglass",
            description: "Search the web via Brave API",
            serverType: .custom(
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-brave-search"],
                env: ["BRAVE_API_KEY": ""]
            )
        ),
        MCPTemplate(
            name: "Postgres Database",
            icon: "cylinder.split.1x2",
            description: "Connect to PostgreSQL databases",
            serverType: .custom(
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-postgres"],
                env: ["POSTGRES_CONNECTION_STRING": ""]
            )
        ),
        MCPTemplate(
            name: "Custom Server",
            icon: "terminal",
            description: "Configure a custom MCP server",
            serverType: .custom(command: "", args: [], env: [:])
        )
    ]
}

#Preview {
    MCPMenuView(settingsManager: MCPSettingsManager())
}