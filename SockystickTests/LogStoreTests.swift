//
//  LogStoreTests.swift
//  SockystickTests
//

import XCTest
@testable import Sockystick

@MainActor
final class LogStoreTests: XCTestCase {
    func testLogEntryInitialization() {
        let entry = LogEntry(
            level: .error,
            category: "CLI",
            message: "Test failure",
            details: "Exit code: 1\nError output"
        )
        XCTAssertEqual(entry.level, .error)
        XCTAssertEqual(entry.category, "CLI")
        XCTAssertEqual(entry.message, "Test failure")
        XCTAssertEqual(entry.details, "Exit code: 1\nError output")
        XCTAssertTrue(entry.fullFormattedString.contains("ERROR"))
        XCTAssertTrue(entry.fullFormattedString.contains("Test failure"))
    }

    func testLogStoreAddAndClear() {
        let store = LogStore(maxEntries: 10)
        store.clear()
        
        store.log(level: .info, category: "TestCategory", message: "Unit test message 1")
        store.log(level: .error, category: "TestCategory", message: "Unit test error message", details: "Diagnostic trace")

        let entries = store.entries
        XCTAssertGreaterThanOrEqual(entries.count, 2)
        
        let errorEntry = entries.first(where: { $0.level == .error })
        XCTAssertNotNil(errorEntry)
        XCTAssertEqual(errorEntry?.message, "Unit test error message")
        XCTAssertEqual(errorEntry?.details, "Diagnostic trace")

        store.clear()
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.message, "Logs cleared.")
    }

    func testLogStoreMaxEntriesLimit() {
        let store = LogStore(maxEntries: 5)
        store.clear()

        for i in 1...10 {
            store.addEntry(LogEntry(level: .info, category: "Test", message: "Msg \(i)"))
        }

        XCTAssertEqual(store.entries.count, 5)
        XCTAssertEqual(store.entries.last?.message, "Msg 10")
    }

    func testExportFormattedText() {
        let store = LogStore(maxEntries: 10)
        store.clear()
        store.addEntry(LogEntry(level: .warning, category: "Network", message: "Network slow"))
        
        let export = store.exportFormattedText
        XCTAssertTrue(export.contains("WARNING"))
        XCTAssertTrue(export.contains("Network slow"))
    }
}
