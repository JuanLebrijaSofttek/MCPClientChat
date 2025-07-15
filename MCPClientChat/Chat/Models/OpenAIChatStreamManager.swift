//
//  OpenAIChatStreamManager.swift
//  MCPClientChat
//
//  Created by Claude Code on 7/14/25.
//

import Foundation
import MCPSwiftWrapper
import SwiftUI

@MainActor
@Observable
/// Handle a chat conversation with streaming for OpenAI.
final class OpenAIChatStreamManager: ChatManager {
    let OPENAI_CHAT_MODEL_NAME = "Innovation-gpt4o"

    // MARK: Lifecycle
    
    init(service: OpenAIService) {
        print("✅ OpenAI Streaming Service Start")
        self.service = service
    }
    
    // MARK: Internal
    
    /// Messages sent from the user or received from OpenAI
    var messages: [ChatMessage] = []
    
    /// Error message if something goes wrong
    var errorMessage = ""
    
    /// Loading state indicator
    var isLoading = false
    
    /// Returns true if OpenAI is still processing a response
    var isProcessing: Bool {
        isLoading
    }
    
    func updateClient(_ client: MCPClient) {
        mcpClient = client
        // Invalidate cache when client changes
        invalidateToolsCache()
    }
    
    /// Send a new message to OpenAI and get the streaming response
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
        openAIMessages.removeAll()
        errorMessage = ""
        isLoading = false
        task?.cancel()
        task = nil
    }
    
    /// Invalidate tools cache (useful when client changes)
    func invalidateToolsCache() {
        print("🟡 Invalidating tools cache")
        cachedTools = nil
        toolsCacheTimestamp = nil
    }
    
    // MARK: Private
    
    /// Service to communicate with OpenAI API
    private let service: OpenAIService
    
    /// Message history for OpenAI's context
    private var openAIMessages: [OpenAIMessage] = []
    
    /// Current task handling OpenAI API request
    private var task: Task<Void, Never>? = nil
    
    private var mcpClient: MCPClient?
    
    /// Cached tools to avoid fetching on every message
    private var cachedTools: [OpenAITool]?
    
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
        
        // Add a placeholder for OpenAI's response
        let assistantMessage = ChatMessage(text: "", role: .assistant, isWaitingForFirstText: true)
        messages.append(assistantMessage)
        
        // Add user message to history
        openAIMessages.append(OpenAIMessage(
            role: .user,
            content: .text(prompt)))
        
        task = Task {
            do {
                isLoading = true
                
                print("🟡 get client")
                guard mcpClient != nil else {
                    throw NSError(domain: "OpenAIChat", code: 1, userInfo: [NSLocalizedDescriptionKey: "mcpClient is nil"])
                }
                
                // Start streaming immediately without waiting for tools
                // Tools will be fetched async and used if needed
                try await startStreamingConversation(tools: [])
                
                // Log completion time
                if let startTime = messageStartTime {
                    let duration = Date().timeIntervalSince(startTime)
                    print("⚡ Streaming message processing completed in: \(String(format: "%.2f", duration))s")
                }
                
                isLoading = false
            } catch {
                print("❌- \(error)")
                errorMessage = "\(error)"
                
                // Update UI to show error
                if let lastIndex = messages.indices.last {
                    messages[lastIndex].isWaitingForFirstText = false
                    messages[lastIndex].text = "Sorry, there was an error: \(error.localizedDescription)"
                    print("❌- \(error.localizedDescription)")
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
    
    private func startStreamingConversation(tools: [OpenAITool]) async throws {
        print("🟡 in startStreamingConversation")
        
        guard mcpClient != nil else {
            throw NSError(domain: "OpenAIChat", code: 1, userInfo: [NSLocalizedDescriptionKey: "mcpClient is nil"])
        }
        
        // Get tools asynchronously if not provided
        let finalTools: [OpenAITool]
        if tools.isEmpty {
            print("🟡 Fetching tools async during streaming")
            finalTools = (try? await getCachedTools().filter { $0.function.name != "create_pull_request_review" }) ?? []
            print("🟡 Got \(finalTools.count) tools")
        } else {
            finalTools = tools
        }
        
        let parameters = OpenAIParameters(
            messages: openAIMessages,
            model: .custom(OPENAI_CHAT_MODEL_NAME),
            toolChoice: finalTools.isEmpty ? ToolChoice.none : .auto,
            tools: finalTools.isEmpty ? nil : finalTools)
        
        print("🟡 Starting streaming request")
        
        // Start streaming
        let stream = try await service.startStreamedChat(parameters: parameters)
        
        var currentContent = ""
        var toolCalls: [OpenAIToolCall] = []
        var currentToolCallIndex = 0
        var toolCallsAccumulator: [Int: StreamingToolCall] = [:]
        
        // Track first token timing
        firstTokenTime = nil
        
        for try await chunk in stream {
            print("🟡 Received streaming chunk")
            
            // Record first token time
            if firstTokenTime == nil {
                firstTokenTime = Date()
                if let startTime = messageStartTime {
                    let timeToFirstToken = firstTokenTime!.timeIntervalSince(startTime)
                    print("🚀 First token received in: \(String(format: "%.2f", timeToFirstToken))s")
                }
            }
            
            guard let choice = chunk.choices?.first else { continue }
            
            // Handle streaming content
            if let content = choice.delta?.content {
                currentContent += content
                
                // Update UI in real-time - modify in place instead of pop/append
                if let lastIndex = messages.indices.last {
                    messages[lastIndex].isWaitingForFirstText = false
                    messages[lastIndex].text = currentContent
                }
            }
            
            // Handle tool calls
            if let deltaToolCalls = choice.delta?.toolCalls {
                print("🔧 Received tool calls delta: \(deltaToolCalls.count) tool calls")
                for deltaToolCall in deltaToolCalls {
                    let index = deltaToolCall.index ?? currentToolCallIndex
                    print("🔧 Processing tool call at index \(index): \(deltaToolCall.function.name ?? "unknown") with args: \(deltaToolCall.function.arguments)")
                    
                    // Initialize or update tool call accumulator
                    if var existingToolCall = toolCallsAccumulator[index] {
                        existingToolCall.function.arguments += deltaToolCall.function.arguments
                        toolCallsAccumulator[index] = existingToolCall
                    } else {
                        toolCallsAccumulator[index] = StreamingToolCall(
                            id: deltaToolCall.id ?? "",
                            function: StreamingFunctionCall(
                                name: deltaToolCall.function.name ?? "",
                                arguments: deltaToolCall.function.arguments
                            )
                        )
                    }
                    
                    currentToolCallIndex = max(currentToolCallIndex, index + 1)
                }
            }
            
            // Check for completion
            if let finishReason = choice.finishReason {
                print("🟡 Stream finished with reason: \(finishReason)")
                
                // Handle regular text completion
                if "\(finishReason)" == "stop" {
                    // Add assistant response to history
                    openAIMessages.append(OpenAIMessage(
                        role: .assistant,
                        content: .text(currentContent)))
                    break
                }
                
                print("🔧 Checking finish reason: '\(finishReason)' (type: \(type(of: finishReason)))")
                
                // Handle tool calls completion
                let finishReasonString = "\(finishReason)"
                if finishReasonString.contains("tool_calls") {
                    print("🔧 Stream finished with tool_calls reason. Accumulated tool calls: \(toolCallsAccumulator.count)")
                    print("🔧 Tool calls accumulator: \(toolCallsAccumulator)")
                    
                    // Convert accumulated tool calls to proper format
                    toolCalls = toolCallsAccumulator.values.map { streamingToolCall in
                        OpenAIToolCall(
                            id: streamingToolCall.id,
                            function: SwiftOpenAI.FunctionCall(
                                arguments: streamingToolCall.function.arguments,
                                name: streamingToolCall.function.name
                            )
                        )
                    }
                    
                    // Add assistant message with tool calls to history (like non-streaming)
                    openAIMessages.append(OpenAIMessage(
                        role: .assistant,
                        content: .text(currentContent),
                        toolCalls: toolCalls))
                    
                    // Process tool calls
                    if !toolCalls.isEmpty {
                        print("🔧 Processing \(toolCalls.count) tool calls")
                        try await processToolCalls(toolCalls, tools: finalTools)
                    } else {
                        print("❌ No tool calls to process despite tool_calls finish reason")
                    }
                    break
                }
            }
        }
        
        print("🟡 Streaming conversation completed")
        print("📝 Complete message content: \(currentContent)")
    }
    
    private func processToolCalls(_ toolCalls: [OpenAIToolCall], tools: [OpenAITool]) async throws {
        guard let mcpClient else {
            throw NSError(domain: "OpenAIChat", code: 1, userInfo: [NSLocalizedDescriptionKey: "mcpClient is nil"])
        }
        
        print("🟡 Processing \(toolCalls.count) tool calls")
        
        // Process each tool call (similar to non-streaming)
        for toolCall in toolCalls {
            let function = toolCall.function
            guard
                let id = toolCall.id,
                let name = function.name,
                let argumentsData = function.arguments.data(using: .utf8)
            else {
                continue
            }
            
            // Parse arguments from string to dictionary
            let arguments: [String: Any]
            do {
                guard let parsedArgs = try JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] else {
                    continue
                }
                arguments = parsedArgs
            } catch {
                print("❌ Error parsing tool arguments: \(error)")
                continue
            }
            
            print("🔧 Tool use detected - Name: \(name), ID: \(id)")
            
            // Update UI to show tool use (like non-streaming)
            if let lastIndex = messages.indices.last {
                messages[lastIndex].isWaitingForFirstText = false
                messages[lastIndex].text += "Using tool: \(name)..."
            }
            
            // Call tool via MCP
            let toolResponse = await mcpClient.openAICallTool(name: name, input: arguments, debug: true)
            print("🔧 Tool response: \(String(describing: toolResponse))")
            
            // Add tool result to conversation
            if let toolResult = toolResponse {
                // Add the tool result as a tool message
                openAIMessages.append(OpenAIMessage(
                    role: .tool,
                    content: .text(toolResult),
                    toolCallID: id))
                
                // Continue conversation with tool results (like non-streaming)
                try await startStreamingConversation(tools: tools.isEmpty ? [] : tools)
            } else {
                print("❌ Tool execution failed")
                // Handle tool failure
                if let lastIndex = messages.indices.last {
                    messages[lastIndex].isWaitingForFirstText = false
                    messages[lastIndex].text = "There was an error using the tool \(name)."
                }
                
                // Add error response as tool message
                openAIMessages.append(OpenAIMessage(
                    role: .tool,
                    content: .text("Error: Tool execution failed"),
                    toolCallID: id))
            }
        }
    }
    
    /// Get tools with caching mechanism
    private func getCachedTools() async throws -> [OpenAITool] {
        guard let mcpClient else {
            throw NSError(domain: "OpenAIChat", code: 1, userInfo: [NSLocalizedDescriptionKey: "mcpClient is nil"])
        }
        
        // Check if we have cached tools and they're still valid
        if let cachedTools = cachedTools,
           let cacheTimestamp = toolsCacheTimestamp,
           Date().timeIntervalSince(cacheTimestamp) < toolsCacheExpiryInterval {
            print("🟡 Using cached tools (\(cachedTools.count) tools)")
            return cachedTools
        }
        
        print("🟡 Fetching fresh tools from MCP client")
        let tools = try await mcpClient.openAITools()
        
        // Cache the tools
        cachedTools = tools
        toolsCacheTimestamp = Date()
        
        print("🟡 Cached \(tools.count) tools")
        return tools
    }
}

// MARK: - Streaming Helper Types

private struct StreamingToolCall {
    let id: String
    var function: StreamingFunctionCall
}

private struct StreamingFunctionCall {
    let name: String
    var arguments: String
}
