//
//  KeychainHelperTests.swift
//  SockystickTests
//

import XCTest
@testable import Sockystick

final class KeychainHelperTests: XCTestCase {
    var keychain: KeychainHelper!
    let testAccount = "test_socks_account"

    override func setUp() {
        super.setUp()
        keychain = KeychainHelper()
        keychain.deletePassword(forAccount: testAccount)
    }

    override func tearDown() {
        keychain.deletePassword(forAccount: testAccount)
        keychain = nil
        super.tearDown()
    }

    func testSaveAndReadPassword() {
        let password = "MySecureSOCKS5Password123!"
        
        let saveResult = keychain.savePassword(password, forAccount: testAccount)
        XCTAssertTrue(saveResult)

        let readValue = keychain.readPassword(forAccount: testAccount)
        XCTAssertEqual(readValue, password)
    }

    func testDeletePassword() {
        let password = "TempPassword"
        keychain.savePassword(password, forAccount: testAccount)
        
        let deleteResult = keychain.deletePassword(forAccount: testAccount)
        XCTAssertTrue(deleteResult)

        let readValue = keychain.readPassword(forAccount: testAccount)
        XCTAssertNil(readValue)
    }
}
