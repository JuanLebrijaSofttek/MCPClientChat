//
//  MCPStatusView.swift
//  MCPClientChat
//
//  Created by Claude Code on 7/14/25.
//

import SwiftUI

struct MCPStatusView: View {
    @Bindable var settingsManager: MCPSettingsManager
    
    var body: some View {
        HStack(spacing: 8) {
            // MCP Server Status
            if let active = settingsManager.activeConfiguration {
                HStack(spacing: 4) {
                    Image(systemName: serverIcon(for: active.serverType))
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text(active.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Circle()
                        .fill(statusColor(for: active))
                        .frame(width: 6, height: 6)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "server.rack")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text("No MCP Server")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Tool Count
            if let active = settingsManager.activeConfiguration, active.isEnabled {
                Text("26 tools") // This would ideally come from the MCP client
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
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

#Preview {
    MCPStatusView(settingsManager: MCPSettingsManager())
}