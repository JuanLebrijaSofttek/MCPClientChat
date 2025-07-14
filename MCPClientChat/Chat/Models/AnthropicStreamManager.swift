//
//  AnthropicStreamManager.swift
//  MCPClientChat
//
//  Created by Claude Code on 7/14/25.
//

/*
 COMMENTED OUT - This implementation needs to be fixed for the current SwiftAnthropic API version
 Currently only using OpenAI Azure streaming implementation
 
import Foundation
import MCPSwiftWrapper

@MainActor
@Observable
/// Handle a chat conversation with streaming for Anthropic
final class AnthropicStreamManager: ChatManager {

  // MARK: Lifecycle

  init(service: AnthropicService) {
    print("✅ Anthropic Streaming Service Start")
    self.service = service
  }

  // MARK: Internal

  /// Messages sent from the user or received from Claude
  var messages: [ChatMessage] = []

  /// Error message if something goes wrong
  var errorMessage = ""

  /// Loading state indicator
  var isLoading = false

  /// Returns true if Claude is still processing a response
  var isProcessing: Bool {
    isLoading
  }

  func updateClient(_ client: MCPClient) {
    mcpClient = client
    // Invalidate cache when client changes
    invalidateToolsCache()
  }

  /// Send a new message to Claude and get the streaming response
  func send(message: ChatMessage) {
    print("✅ Send Streaming Message")
    messageStartTime = Date()
    print("⏰ Streaming message processing started at: \(messageStartTime!)")
    messages.append(message)
    processUserMessage(prompt: message.text)
  }

  /// Cancel the current processing task
  func stop() {
    task?.cancel()
    task = nil
    isLoading = false
  }

  /// Clear the conversation
  func clearConversation() {
    messages.removeAll()
    anthropicMessages.removeAll()
    errorMessage = ""
    isLoading = false
    task?.cancel()
    task = nil
  }
  
  /// Invalidate tools cache (useful when client changes)
  private func invalidateToolsCache() {
    print("🟡 Invalidating tools cache")
    cachedTools = nil
    toolsCacheTimestamp = nil
  }

  // MARK: Private

  /// Service to communicate with Anthropic API
  private let service: AnthropicService

  /// Message history for Claude's context
  private var anthropicMessages: [AnthropicMessage] = []

  /// Current task handling Claude API request
  private var task: Task<Void, Never>? = nil

  private var mcpClient: MCPClient?
  
  /// Cached tools to avoid fetching on every message
  private var cachedTools: [AnthropicTool]?
  
  /// Last time tools were fetched
  private var toolsCacheTimestamp: Date?
  
  /// Cache expiry time (5 minutes)
  private let toolsCacheExpiryInterval: TimeInterval = 300
  
  /// Track message processing start time for performance metrics
  private var messageStartTime: Date?
  
  /// Track streaming response timing
  private var firstTokenTime: Date?

  private func processUserMessage(prompt: String) {
    print("🟡 processUserMessage (streaming)")
    
    guard let mcpClient else {
      fatalError("Client not initialized")
    }
    
    // Add a placeholder for Claude's response
    let assistantMessage = ChatMessage(text: "", role: .assistant, isWaitingForFirstText: true)
    messages.append(assistantMessage)

    // Add user message to history
    anthropicMessages.append(AnthropicMessage(
      role: .user,
      content: .text(prompt)))

    task = Task {
      do {
        isLoading = true

        // Get available tools from MCP (with caching)
        let tools = try await getCachedTools()

        // Start streaming conversation
        try await startStreamingConversation(tools: tools)

        // Log completion time
        if let startTime = messageStartTime {
          let duration = Date().timeIntervalSince(startTime)
          print("⚡ Streaming message processing completed in: \(String(format: "%.2f", duration))s")
        }

        isLoading = false
      } catch {
        errorMessage = "\(error)"

        // Update UI to show error
        if var last = messages.popLast() {
          last.isWaitingForFirstText = false
          last.text = "Sorry, there was an error: \(error.localizedDescription)"
          messages.append(last)
        }

        // Log error completion time
        if let startTime = messageStartTime {
          let duration = Date().timeIntervalSince(startTime)
          print("⚡ Streaming message processing failed after: \(String(format: "%.2f", duration))s")
        }

        isLoading = false
      }
    }
  }

  private func startStreamingConversation(tools: [AnthropicTool]) async throws {
    print("🟡 in startStreamingConversation")
    
    let parameters = AnthropicParameters(
      model: .claude37Sonnet,
      messages: anthropicMessages,
      maxTokens: 10000,
      tools: tools,
      stream: true)

    print("🟡 Starting streaming request")

    // Start streaming
    let stream = try await service.streamMessage(parameters)
    
    var currentContent = ""
    var toolUse: SwiftAnthropic.ToolUse?
    var accumulatedToolJson = ""
    var isProcessingToolCall = false
    
    // Track first token timing
    firstTokenTime = nil

    for try await result in stream {
      print("🟡 Received streaming chunk: \(result.streamEvent)")
      
      // Record first token time
      if firstTokenTime == nil {
        firstTokenTime = Date()
        if let startTime = messageStartTime {
          let timeToFirstToken = firstTokenTime!.timeIntervalSince(startTime)
          print("🚀 First token received in: \(String(format: "%.2f", timeToFirstToken))s")
        }
      }

      switch result.streamEvent {
      case .messageStart:
        print("🟡 Message started")
        
      case .contentBlockStart:
        print("🟡 Content block started")
        if let contentBlock = result.contentBlock {
          if let tool = contentBlock.toolUse {
            print("🔧 Tool use detected: \(tool.name)")
            toolUse = tool
            isProcessingToolCall = true
            accumulatedToolJson = ""
            
            // Update UI to show tool use
            if var last = messages.popLast() {
              last.isWaitingForFirstText = false
              last.text = currentContent + "\n🔧 Using tool: \(tool.name)..."
              messages.append(last)
            }
          }
        }
        
      case .contentBlockDelta:
        if let deltaText = result.delta?.text {
          currentContent += deltaText
          
          // Update UI in real-time
          if var last = messages.popLast() {
            last.isWaitingForFirstText = false
            last.text = currentContent
            messages.append(last)
          }
        }
        
        // Accumulate tool use JSON
        if isProcessingToolCall {
          accumulatedToolJson += result.delta?.partialJson ?? ""
        }
        
      case .contentBlockStop:
        print("🟡 Content block stopped")
        if isProcessingToolCall {
          print("🔧 Tool use completed, processing...")
          try await processToolCall(toolUse, json: accumulatedToolJson, tools: tools)
          isProcessingToolCall = false
          return // Exit to restart conversation with tool results
        }
        
      case .messageDelta:
        print("🟡 Message delta")
        
      case .messageStop:
        print("🟡 Message stopped")
        
        // Add assistant response to history
        anthropicMessages.append(AnthropicMessage(
          role: .assistant,
          content: .text(currentContent)))
        
        print("🟡 Streaming conversation completed")
        return
        
      case .error:
        print("❌ Streaming error")
        throw NSError(domain: "AnthropicChat", code: 1, userInfo: [NSLocalizedDescriptionKey: "Stream error"])
      }
    }
  }
  
  private func processToolCall(_ toolUse: SwiftAnthropic.ToolUse?, json: String, tools: [AnthropicTool]) async throws {
    guard let toolUse = toolUse, let mcpClient else {
      return
    }
    
    print("🔧 Processing tool call: \(toolUse.name)")
    
    // Parse accumulated JSON for tool input
    var toolInput: [String: Any] = [:]
    if !json.isEmpty {
      do {
        if let jsonData = json.data(using: .utf8),
           let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
          toolInput = parsed
        }
      } catch {
        print("❌ Error parsing tool JSON: \(error)")
        // Fallback to toolUse.input if JSON parsing fails
        toolInput = toolUse.input
      }
    } else {
      toolInput = toolUse.input
    }
    
    // Add the assistant message with tool use to history
    anthropicMessages.append(AnthropicMessage(
      role: .assistant,
      content: .list([.toolUse(toolUse.id, toolUse.name, toolInput)])))

    // Call tool via MCP
    let toolResponse = await mcpClient.anthropicCallTool(name: toolUse.name, input: toolInput, debug: true)
    print("🔧 Tool response: \(String(describing: toolResponse))")

    // Add tool result to conversation
    if let toolResult = toolResponse {
      // Add the tool result as user message
      anthropicMessages.append(AnthropicMessage(
        role: .user,
        content: .list([.toolResult(toolUse.id, toolResult)])))

      // Continue conversation with tool results
      try await startStreamingConversation(tools: tools)
    } else {
      print("❌ Tool execution failed")
      // Handle tool failure
      if var last = messages.popLast() {
        last.isWaitingForFirstText = false
        last.text = "There was an error using the tool \(toolUse.name)."
        messages.append(last)
      }
    }
  }
  
  /// Get tools with caching mechanism
  private func getCachedTools() async throws -> [AnthropicTool] {
    guard let mcpClient else {
      throw NSError(domain: "AnthropicChat", code: 1, userInfo: [NSLocalizedDescriptionKey: "mcpClient is nil"])
    }
    
    // Check if we have cached tools and they're still valid
    if let cachedTools = cachedTools,
       let cacheTimestamp = toolsCacheTimestamp,
       Date().timeIntervalSince(cacheTimestamp) < toolsCacheExpiryInterval {
      print("🟡 Using cached tools (\(cachedTools.count) tools)")
      return cachedTools
    }
    
    print("🟡 Fetching fresh tools from MCP client")
    let tools = try await mcpClient.anthropicTools()
    
    // Cache the tools
    cachedTools = tools
    toolsCacheTimestamp = Date()
    
    print("🟡 Cached \(tools.count) tools")
    return tools
  }
}
*/