//
//  MCPConfiguration.swift
//  MCPClientChat
//
//  Created by Claude Code on 7/14/25.
//

import Foundation
import MCPClient

/// Represents an MCP server configuration
struct MCPConfiguration: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var serverType: MCPServerType
    var isEnabled: Bool = true
    
    enum MCPServerType: Codable, Hashable {
        case github(username: String?, token: String?)
        case filesystem(path: String)
        case sqlite(path: String)
        case custom(command: String, args: [String], env: [String: String])
        
        var displayName: String {
            switch self {
            case .github:
                return "GitHub"
            case .filesystem:
                return "Filesystem"
            case .sqlite:
                return "SQLite"
            case .custom:
                return "Custom"
            }
        }
        
        var description: String {
            switch self {
            case .github:
                return "Access GitHub repositories and manage issues"
            case .filesystem:
                return "Read and write files on the local filesystem"
            case .sqlite:
                return "Query and manage SQLite databases"
            case .custom:
                return "Custom MCP server configuration"
            }
        }
    }
    
    /// Get transport configuration details as a tuple
    func getTransportDetails() -> (command: String, args: [String], env: [String: String]) {
        switch serverType {
        case .github(_, let token):
            return (
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-github"],
                env: ["GITHUB_PERSONAL_ACCESS_TOKEN": token ?? ""]
            )
        case .filesystem(let path):
            return (
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-filesystem", path],
                env: [:]
            )
        case .sqlite(let path):
            return (
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-sqlite", "--db-path", path],
                env: [:]
            )
        case .custom(let command, let args, let env):
            return (
                command: command,
                args: args,
                env: env
            )
        }
    }
    
    /// Validate the configuration
    func isValid() -> Bool {
        switch serverType {
        case .github(let username, let token):
            return username != nil && token != nil && !token!.isEmpty
        case .filesystem(let path):
            return !path.isEmpty && FileManager.default.fileExists(atPath: path)
        case .sqlite(let path):
            return !path.isEmpty && path.hasSuffix(".db")
        case .custom(let command, _, _):
            return !command.isEmpty
        }
    }
}

/// Default MCP configurations
extension MCPConfiguration {
    static let defaultConfigurations: [MCPConfiguration] = [
        MCPConfiguration(
            name: "GitHub",
            serverType: .github(username: nil, token: nil),
            isEnabled: false
        ),
        MCPConfiguration(
            name: "Local Filesystem",
            serverType: .filesystem(path: NSHomeDirectory()),
            isEnabled: false
        ),
        MCPConfiguration(
            name: "SQLite Database",
            serverType: .sqlite(path: ""),
            isEnabled: false
        )
    ]
}