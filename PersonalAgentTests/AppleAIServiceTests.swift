//
//  AppleAIServiceTests.swift
//  PersonalAgentTests
//
//  Created by Leon Kuzmin on 1/7/26.
//

import XCTest
@testable import PersonalAgent

final class AppleAIServiceTests: XCTestCase {
    
    // We need to access the private parseToolCalls method.
    // Since it's private, we can't call it directly from the test module unless we make it internal
    // or use a testable import AND it's internal.
    // However, the service is an actor and the method is nonisolated private.
    // For the purpose of this task and without modifying the source code visibility too much (though internal is better for testing),
    // I will assume we can modify AppleAIService to make `parseToolCalls` internal OR
    // I will test the public surface area `complete` or `stream` if possible, BUT those require mocking the LanguageModelSession which is hard (Apple framework).
    
    // DECISION: I will reflect on the source code. modifying AppleAIService to make the parser internal and static/nonisolated is the best approach for unit testing pure logic.
    // I will include that small refactor in this step.
    
    func testStandardMarkdownBlock() {
        let input = """
        Here is the tool:
        ```tool
        {
          "tool": "calculator",
          "arguments": { "expression": "2 + 2" }
        }
        ```
        """
        let result = AppleAIService.parseToolCalls(from: input)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "calculator")
    }
    
    func testJSONBlock() {
        let input = """
        ```json
        {
          "tool": "search",
          "arguments": { "query": "swift parsing" }
        }
        ```
        """
        let result = AppleAIService.parseToolCalls(from: input)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "search")
    }
    
    func testLooseJSON() {
        let input = """
        {
          "tool": "reminder",
          "arguments": { "title": "Buy milk" }
        }
        """
        let result = AppleAIService.parseToolCalls(from: input)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "reminder")
    }
    
    func testMixedContent() {
        let input = """
        Sure.
        ```tool
        { "tool": "one", "arguments": {} }
        ```
        Start.
        ```json
        { "tool": "two", "arguments": {} }
        ```
        """
        let result = AppleAIService.parseToolCalls(from: input)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].name, "one")
        XCTAssertEqual(result[1].name, "two")
    }
    
    func testMalformed() {
        let input = """
        ```tool
        { "tool": "broken", "arguments": {
        ```
        """
        let result = AppleAIService.parseToolCalls(from: input)
        XCTAssertTrue(result.isEmpty)
    }
}
