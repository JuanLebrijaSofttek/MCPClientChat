//
//  MCPSettingsManager.swift
//  MCPClientChat
//
//  Created by Claude Code on 7/14/25.
//

import Foundation
import SwiftUI

/// Manages MCP configurations and persistence
@MainActor
@Observable
final class MCPSettingsManager {
    
    // MARK: - Properties
    
    /// All configured MCP servers
    var configurations: [MCPConfiguration] = []
    
    /// Currently active configuration
    var activeConfiguration: MCPConfiguration?
    
    /// Settings file URL
    private let settingsURL: URL
    
    // MARK: - Lifecycle
    
    init() {
        // Create settings directory if it doesn't exist
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let settingsDir = appSupport.appendingPathComponent("MCPClientChat")
        try? FileManager.default.createDirectory(at: settingsDir, withIntermediateDirectories: true)
        
        settingsURL = settingsDir.appendingPathComponent("mcp-settings.json")
        
        loadSettings()
    }
    
    // MARK: - Public Methods
    
    /// Add a new MCP configuration
    func addConfiguration(_ config: MCPConfiguration) {
        configurations.append(config)
        saveSettings()
    }
    
    /// Update an existing configuration
    func updateConfiguration(_ config: MCPConfiguration) {
        if let index = configurations.firstIndex(where: { $0.id == config.id }) {
            configurations[index] = config
            
            // Update active configuration if it's the one being updated
            if activeConfiguration?.id == config.id {
                activeConfiguration = config
            }
            
            saveSettings()
        }
    }
    
    /// Remove a configuration
    func removeConfiguration(_ config: MCPConfiguration) {
        configurations.removeAll { $0.id == config.id }
        
        // Clear active configuration if it was removed
        if activeConfiguration?.id == config.id {
            activeConfiguration = nil
        }
        
        saveSettings()
    }
    
    /// Set the active configuration
    func setActiveConfiguration(_ config: MCPConfiguration?) {
        activeConfiguration = config
        saveSettings()
    }
    
    /// Get enabled configurations
    var enabledConfigurations: [MCPConfiguration] {
        configurations.filter { $0.isEnabled && $0.isValid() }
    }
    
    /// Toggle configuration enabled state
    func toggleConfiguration(_ config: MCPConfiguration) {
        var updatedConfig = config
        updatedConfig.isEnabled.toggle()
        updateConfiguration(updatedConfig)
    }
    
    /// Reset to default configurations
    func resetToDefaults() {
        configurations = MCPConfiguration.defaultConfigurations
        activeConfiguration = nil
        saveSettings()
    }
    
    // MARK: - Private Methods
    
    /// Load settings from disk
    private func loadSettings() {
        do {
            let data = try Data(contentsOf: settingsURL)
            let settings = try JSONDecoder().decode(MCPSettings.self, from: data)
            configurations = settings.configurations
            activeConfiguration = settings.configurations.first { $0.id == settings.activeConfigurationID }
        } catch {
            print("📄 No existing settings found, using defaults")
            configurations = MCPConfiguration.defaultConfigurations
            // Set the first enabled configuration as active
            activeConfiguration = configurations.first { $0.isEnabled && $0.isValid() }
            if activeConfiguration != nil {
                print("🚀 Set default active configuration: \(activeConfiguration!.name)")
                saveSettings() // Save the initial settings with active configuration
            }
        }
    }
    
    /// Save settings to disk
    private func saveSettings() {
        do {
            let settings = MCPSettings(
                configurations: configurations,
                activeConfigurationID: activeConfiguration?.id
            )
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsURL)
            print("💾 Settings saved successfully")
        } catch {
            print("❌ Failed to save settings: \(error)")
        }
    }
}

// MARK: - Supporting Types

/// Wrapper for persisting settings
private struct MCPSettings: Codable {
    let configurations: [MCPConfiguration]
    let activeConfigurationID: UUID?
}