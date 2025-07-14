//
//  GitHubAuthManager.swift
//  MCPClientChat
//
//  Created by Claude Code on 7/14/25.
//

import Foundation
import SwiftUI
import WebKit

/// GitHub OAuth authentication manager
@MainActor
@Observable
final class GitHubAuthManager: NSObject {
    
    // MARK: - OAuth Configuration
    
    // For now, we'll use Personal Access Token approach
    // In a production app, you would set up proper OAuth with GitHub Apps
    private let scope = "repo,read:org,read:user"
    
    // MARK: - State
    
    private(set) var isAuthenticating = false
    private(set) var currentUser: GitHubUser?
    var accessToken: String?
    private(set) var lastError: String?
    
    // MARK: - Authentication
    
    /// Authenticate with Personal Access Token
    func authenticateWithToken(_ token: String) async -> GitHubAuthResult {
        isAuthenticating = true
        lastError = nil
        
        // Validate token by fetching user info
        let user = await fetchUserInfo(token: token)
        
        if let user = user {
            self.accessToken = token
            self.currentUser = user
            storeTokenInKeychain(token)
            isAuthenticating = false
            return .success(token, user)
        } else {
            isAuthenticating = false
            lastError = "Invalid token or network error"
            return .failure("Invalid token or network error")
        }
    }
    
    /// Open GitHub token creation page
    func openTokenCreationPage() {
        let url = URL(string: "https://github.com/settings/tokens/new?scopes=\(scope)&description=MCPClientChat")!
        NSWorkspace.shared.open(url)
    }
    
    /// Sign out current user
    func signOut() {
        currentUser = nil
        accessToken = nil
        removeTokenFromKeychain()
    }
    
    /// Load existing token from Keychain
    func loadStoredToken() -> String? {
        guard let token = loadTokenFromKeychain() else { return nil }
        
        // Verify token is still valid (you might want to make an API call here)
        accessToken = token
        return token
    }
    
    // MARK: - Private Methods
    
    private func fetchUserInfo(token: String) async -> GitHubUser? {
        guard let url = URL(string: "https://api.github.com/user") else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(GitHubUser.self, from: data)
        } catch {
            print("Failed to fetch user info: \(error)")
            return nil
        }
    }
    
    
    // MARK: - Keychain Storage
    
    private func storeTokenInKeychain(_ token: String) {
        let service = "MCPClientChat"
        let account = "GitHubAccessToken"
        
        let data = token.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func loadTokenFromKeychain() -> String? {
        let service = "MCPClientChat"
        let account = "GitHubAccessToken"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    private func removeTokenFromKeychain() {
        let service = "MCPClientChat"
        let account = "GitHubAccessToken"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
}

// MARK: - Supporting Types

struct GitHubUser: Codable {
    let id: Int
    let login: String
    let name: String?
    let email: String?
    let avatarURL: String?
    
    enum CodingKeys: String, CodingKey {
        case id, login, name, email
        case avatarURL = "avatar_url"
    }
}

enum GitHubAuthResult {
    case success(String, GitHubUser?)  // token, user
    case failure(String)              // error message
}