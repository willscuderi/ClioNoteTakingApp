import XCTest

final class ClioUITests: XCTestCase {
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        // Verify main window appears
        XCTAssertTrue(app.windows.firstMatch.exists)
    }
}
