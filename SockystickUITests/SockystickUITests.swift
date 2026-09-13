//
//  SockystickUITests.swift
//  SockystickUITests
//

import XCTest

final class SockystickUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testAppLaunchAndWindowElements() throws {
        app.activate()
        
        let window = app.windows.firstMatch
        let statusItem = app.statusItems.firstMatch

        let foundElement = window.waitForExistence(timeout: 5.0) || statusItem.waitForExistence(timeout: 5.0)
        XCTAssertTrue(foundElement, "Sockystick main window or status bar item should appear")
    }
}
