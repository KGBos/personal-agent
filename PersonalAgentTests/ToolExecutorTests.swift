//
//  ToolExecutorTests.swift
//  PersonalAgentTests
//
//  Created by Leon Kuzmin on 1/7/26.
//

import XCTest
@testable import PersonalAgent

// Mock Tool
struct MockTool: AgentTool {
    var name: String = "mock_tool"
    var description: String = "A mock tool for testing"
    var parameterSchema: ToolParameterSchema = ToolParameterSchema(type: "object", properties: [:])
    var requiresConfirmation: Bool = false
<<<<<<< HEAD

    var executeBlock: (@Sendable ([String: Any]) async throws -> String)?

=======
    
    var executeBlock: (@Sendable ([String: Any]) async throws -> String)?
    
>>>>>>> origin/master
    func execute(arguments: [String : Any]) async throws -> String {
        if let block = executeBlock {
            return try await block(arguments)
        }
        return "Success"
    }
}

final class ToolExecutorTests: XCTestCase {
<<<<<<< HEAD

    var registry: ToolRegistry!
    var permissions: PermissionsManager!
    var executor: ToolExecutor!

=======
    
    var registry: ToolRegistry!
    var permissions: PermissionsManager!
    var executor: ToolExecutor!
    
>>>>>>> origin/master
    @MainActor
    override func setUp() async throws {
        registry = ToolRegistry()
        permissions = PermissionsManager()
        executor = ToolExecutor(registry: registry, permissionsManager: permissions)
    }
<<<<<<< HEAD

    func testExecuteValidTool() async throws {
        let tool = MockTool()
        await MainActor.run { registry.register(tool) }

        let toolCall = ToolCall(id: "1", name: "mock_tool", argumentsDict: ["foo": "bar"])

        let result = await executor.execute(toolCall: toolCall)

=======
    
    func testExecuteValidTool() async throws {
        let tool = MockTool()
        await MainActor.run { registry.register(tool) }
        
        let toolCall = ToolCall(id: "1", name: "mock_tool", argumentsDict: ["foo": "bar"])
        
        let result = await executor.execute(toolCall: toolCall)
        
>>>>>>> origin/master
        XCTAssertEqual(result.toolName, "mock_tool")
        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.result, "Success")
    }
<<<<<<< HEAD

    func testExecuteUnknownTool() async throws {
        let toolCall = ToolCall(id: "1", name: "unknown", argumentsDict: [:])

        let result = await executor.execute(toolCall: toolCall)

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.result.contains("Unknown tool"))
    }

=======
    
    func testExecuteUnknownTool() async throws {
        let toolCall = ToolCall(id: "1", name: "unknown", argumentsDict: [:])
        
        let result = await executor.execute(toolCall: toolCall)
        
        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.result.contains("Unknown tool"))
    }
    
>>>>>>> origin/master
    func testToolFailure() async throws {
        var tool = MockTool()
        tool.executeBlock = { _ in throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed"]) }
        await MainActor.run { registry.register(tool) }
<<<<<<< HEAD

        let toolCall = ToolCall(id: "1", name: "mock_tool", argumentsDict: [:])

        let result = await executor.execute(toolCall: toolCall)

=======
        
        let toolCall = ToolCall(id: "1", name: "mock_tool", argumentsDict: [:])
        
        let result = await executor.execute(toolCall: toolCall)
        
>>>>>>> origin/master
        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.result.contains("Failed"))
    }
}
