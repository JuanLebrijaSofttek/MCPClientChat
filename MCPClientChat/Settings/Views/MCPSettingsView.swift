//
//  MCPSettingsView.swift
//  MCPClientChat
//
//  Created by Claude Code on 7/14/25.
//

import SwiftUI

struct MCPSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settingsManager: MCPSettingsManager
    @State private var showingAddSheet = false
    @State private var editingConfiguration: MCPConfiguration?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("MCP Server Settings")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Configure Model Context Protocol servers to extend chat capabilities")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                Divider()
                
                // Quick Actions
                MCPQuickActionsView(settingsManager: settingsManager)
                
                Divider()
                
                // Configurations List
                if settingsManager.configurations.isEmpty {
                    emptyStateView
                } else {
                    configurationsList
                }
                
                Spacer()
                
                // Footer Actions
                HStack {
                    Button("Reset to Defaults") {
                        settingsManager.resetToDefaults()
                    }
                    .buttonStyle(.borderless)
                    
                    Spacer()
                    
                    Button("Add Server") {
                        showingAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                MCPConfigurationEditView(
                    configuration: MCPConfiguration(name: "", serverType: .github(username: nil, token: nil)),
                    isNew: true
                ) { config in
                    settingsManager.addConfiguration(config)
                }
            }
            .sheet(item: $editingConfiguration) { config in
                MCPConfigurationEditView(
                    configuration: config,
                    isNew: false
                ) { updatedConfig in
                    settingsManager.updateConfiguration(updatedConfig)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No MCP Servers Configured")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Add MCP servers to extend chat capabilities with tools like GitHub integration, file system access, and more.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Add Your First Server") {
                showingAddSheet = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var configurationsList: some View {
        List {
            ForEach(settingsManager.configurations) { config in
                MCPConfigurationRow(
                    configuration: config,
                    isActive: settingsManager.activeConfiguration?.id == config.id,
                    onToggle: {
                        settingsManager.toggleConfiguration(config)
                    },
                    onEdit: {
                        editingConfiguration = config
                    },
                    onSetActive: {
                        settingsManager.setActiveConfiguration(config.isEnabled ? config : nil)
                    },
                    onDelete: {
                        settingsManager.removeConfiguration(config)
                    }
                )
            }
        }
        .listStyle(.inset)
    }
}

struct MCPConfigurationRow: View {
    let configuration: MCPConfiguration
    let isActive: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onSetActive: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Server Type Icon
            Image(systemName: serverIcon)
                .font(.title2)
                .foregroundColor(configuration.isEnabled ? .accentColor : .secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(configuration.name)
                        .font(.headline)
                    
                    if isActive {
                        Text("ACTIVE")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    if !configuration.isValid() {
                        Text("INVALID")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                
                Text(configuration.serverType.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(configuration.serverType.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Controls
            HStack(spacing: 8) {
                // Set Active Button
                if configuration.isEnabled && configuration.isValid() && !isActive {
                    Button("Set Active") {
                        onSetActive()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
                
                // Toggle Button
                Toggle("", isOn: .constant(configuration.isEnabled))
                    .onChange(of: configuration.isEnabled) {
                        onToggle()
                    }
                    .controlSize(.small)
                
                // Menu
                Menu {
                    Button("Edit") {
                        onEdit()
                    }
                    
                    Divider()
                    
                    Button("Delete", role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var serverIcon: String {
        switch configuration.serverType {
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

// MARK: - Wrapper View

struct MCPSettingsViewWrapper: View {
    let settingsManager: MCPSettingsManager
    
    var body: some View {
        MCPSettingsView(settingsManager: settingsManager)
    }
}

#Preview {
    MCPSettingsView(settingsManager: MCPSettingsManager())
}