import XCTest
@testable import PersonalAgent

final class CalendarCreateCalendarToolTests: XCTestCase {
    
    var tool: CalendarCreateCalendarTool!
    
    override func setUp() {
        super.setUp()
        tool = CalendarCreateCalendarTool()
    }
    
    func testMissingTitleThrowsError() async {
        let args: [String: Any] = ["color": "#FF0000"]
        
        do {
            _ = try await tool.execute(arguments: args)
            XCTFail("Should have thrown error")
        } catch let error as ToolError {
            // Updated to catch the correct error type
            if case .invalidArguments(let msg) = error {
                 XCTAssertTrue(msg.contains("title"))
            } else {
                 XCTFail("Wrong error case: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // We cannot easily test success without mocking CalendarService/EKEventStore,
    // which requires refactoring. For now, valid arguments will attempt to hit EventKit.
}
