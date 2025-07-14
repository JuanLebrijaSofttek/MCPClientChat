//
//  MCPConfigurationEditView.swift
//  MCPClientChat
//
//  Created by Claude Code on 7/14/25.
//

import SwiftUI

struct MCPConfigurationEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var configuration: MCPConfiguration
    @State private var selectedServerType: ServerTypeSelection
    
    let isNew: Bool
    let onSave: (MCPConfiguration) -> Void
    
    // Form fields
    @State private var name: String
    @State private var githubUsername: String = ""
    @State private var githubToken: String = ""
    @State private var filesystemPath: String = ""
    @State private var sqlitePath: String = ""
    @State private var customCommand: String = ""
    @State private var customArgs: String = ""
    @State private var customEnvVars: String = ""
    
    // GitHub OAuth
    @State private var githubAuthManager = GitHubAuthManager()
    @State private var showingGitHubAuth = false
    
    init(configuration: MCPConfiguration, isNew: Bool, onSave: @escaping (MCPConfiguration) -> Void) {
        self.configuration = configuration
        self.isNew = isNew
        self.onSave = onSave
        
        _name = State(initialValue: configuration.name)
        
        // Initialize server type selection and form fields
        switch configuration.serverType {
        case .github(let username, let token):
            _selectedServerType = State(initialValue: .github)
            _githubUsername = State(initialValue: username ?? "")
            _githubToken = State(initialValue: token ?? "")
        case .filesystem(let path):
            _selectedServerType = State(initialValue: .filesystem)
            _filesystemPath = State(initialValue: path)
        case .sqlite(let path):
            _selectedServerType = State(initialValue: .sqlite)
            _sqlitePath = State(initialValue: path)
        case .custom(let command, let args, let env):
            _selectedServerType = State(initialValue: .custom)
            _customCommand = State(initialValue: command)
            _customArgs = State(initialValue: args.joined(separator: " "))
            _customEnvVars = State(initialValue: env.map { "\($0.key)=\($0.value)" }.joined(separator: "\n"))
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Server Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    
                    Picker("Server Type", selection: $selectedServerType) {
                        ForEach(ServerTypeSelection.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Configuration") {
                    serverConfigurationSection
                }
                
                Section("Status") {
                    HStack {
                        Text("Configuration Status:")
                        Spacer()
                        if isConfigurationValid {
                            Label("Valid", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Invalid", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isNew ? "Add MCP Server" : "Edit MCP Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveConfiguration()
                    }
                    .disabled(!isConfigurationValid || name.isEmpty)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    @ViewBuilder
    private var serverConfigurationSection: some View {
        switch selectedServerType {
        case .github:
            githubConfigurationView
        case .filesystem:
            filesystemConfigurationView
        case .sqlite:
            sqliteConfigurationView
        case .custom:
            customConfigurationView
        }
    }
    
    private var githubConfigurationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GitHub Authentication")
                .font(.headline)
            
            if let user = githubAuthManager.currentUser {
                // Authenticated state
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: user.avatarURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Circle()
                            .fill(Color.secondary.opacity(0.3))
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name ?? user.login)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("@\(user.login)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Sign Out") {
                        githubAuthManager.signOut()
                        githubUsername = ""
                        githubToken = ""
                    }
                    .buttonStyle(.borderless)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
            } else {
                // Not authenticated state
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sign in to GitHub to access your repositories")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        Button {
                            githubAuthManager.openTokenCreationPage()
                        } label: {
                            HStack {
                                Image(systemName: "link")
                                Text("Create GitHub Token")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Text("or")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            SecureField("Paste your token here", text: $githubToken)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("Verify") {
                                Task {
                                    let result = await githubAuthManager.authenticateWithToken(githubToken)
                                    switch result {
                                    case .success(let token, let user):
                                        githubToken = token
                                        githubUsername = user?.login ?? ""
                                    case .failure(let error):
                                        print("GitHub auth failed: \(error)")
                                    }
                                }
                            }
                            .disabled(githubToken.isEmpty || githubAuthManager.isAuthenticating)
                        }
                    }
                    
                    if githubAuthManager.isAuthenticating {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Signing in...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let error = githubAuthManager.lastError {
                        Text("Error: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Text("Required permissions: repo, read:org, read:user")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear {
            // Try to load existing token
            if !githubToken.isEmpty {
                githubAuthManager.accessToken = githubToken
            } else if let storedToken = githubAuthManager.loadStoredToken() {
                githubToken = storedToken
            }
        }
    }
    
    private var filesystemConfigurationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Root Directory Path")
                .font(.headline)
            
            HStack {
                TextField("Path", text: $filesystemPath)
                    .textFieldStyle(.roundedBorder)
                
                Button("Browse") {
                    selectDirectory()
                }
                .buttonStyle(.bordered)
            }
            
            Text("The MCP server will have access to files within this directory")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var sqliteConfigurationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SQLite Database Path")
                .font(.headline)
            
            HStack {
                TextField("database.db", text: $sqlitePath)
                    .textFieldStyle(.roundedBorder)
                
                Button("Browse") {
                    selectSQLiteFile()
                }
                .buttonStyle(.bordered)
            }
            
            Text("Path to your SQLite database file")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var customConfigurationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Command")
                    .font(.headline)
                TextField("npx", text: $customCommand)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Arguments")
                    .font(.headline)
                TextField("arg1 arg2 arg3", text: $customArgs)
                    .textFieldStyle(.roundedBorder)
                Text("Space-separated arguments")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Environment Variables")
                    .font(.headline)
                TextEditor(text: $customEnvVars)
                    .frame(minHeight: 60)
                    .border(Color.secondary.opacity(0.3))
                Text("One per line: KEY=value")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var isConfigurationValid: Bool {
        switch selectedServerType {
        case .github:
            return !githubToken.isEmpty && !githubUsername.isEmpty
        case .filesystem:
            return !filesystemPath.isEmpty && FileManager.default.fileExists(atPath: filesystemPath)
        case .sqlite:
            return !sqlitePath.isEmpty && sqlitePath.hasSuffix(".db")
        case .custom:
            return !customCommand.isEmpty
        }
    }
    
    private func saveConfiguration() {
        let serverType: MCPConfiguration.MCPServerType
        
        switch selectedServerType {
        case .github:
            serverType = .github(username: githubUsername.isEmpty ? nil : githubUsername, 
                                token: githubToken.isEmpty ? nil : githubToken)
        case .filesystem:
            serverType = .filesystem(path: filesystemPath)
        case .sqlite:
            serverType = .sqlite(path: sqlitePath)
        case .custom:
            let args = customArgs.split(separator: " ").map(String.init)
            let env: [String: String] = Dictionary(uniqueKeysWithValues: 
                customEnvVars.split(separator: "\n")
                    .compactMap { line in
                        let parts = line.split(separator: "=", maxSplits: 1)
                        guard parts.count == 2 else { return nil }
                        return (String(parts[0]).trimmingCharacters(in: .whitespaces), 
                               String(parts[1]).trimmingCharacters(in: .whitespaces))
                    }
            )
            serverType = .custom(command: customCommand, args: args, env: env)
        }
        
        var updatedConfig = configuration
        updatedConfig.name = name
        updatedConfig.serverType = serverType
        
        onSave(updatedConfig)
        dismiss()
    }
    
    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: filesystemPath.isEmpty ? NSHomeDirectory() : filesystemPath)
        
        if panel.runModal() == .OK {
            filesystemPath = panel.url?.path ?? ""
        }
    }
    
    private func selectSQLiteFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.database]
        
        if panel.runModal() == .OK {
            sqlitePath = panel.url?.path ?? ""
        }
    }
}

enum ServerTypeSelection: CaseIterable {
    case github
    case filesystem
    case sqlite
    case custom
    
    var displayName: String {
        switch self {
        case .github: return "GitHub"
        case .filesystem: return "Filesystem"
        case .sqlite: return "SQLite"
        case .custom: return "Custom"
        }
    }
    
    static var allCases: [ServerTypeSelection] {
        return [.github, .filesystem, .sqlite, .custom]
    }
}

#Preview {
    MCPConfigurationEditView(
        configuration: MCPConfiguration(name: "Test", serverType: .github(username: nil, token: nil)),
        isNew: true
    ) { _ in }
}