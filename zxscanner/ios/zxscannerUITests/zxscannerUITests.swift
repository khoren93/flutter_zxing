//
//  zxscannerUITests.swift
//  zxscannerUITests
//
//  Created by Khoren Markosyan on 19.06.22.
//

import XCTest

class zxscannerUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testScreenshots() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let element: XCUIElement
        if UIDevice.current.userInterfaceIdiom == .phone {
            element = app.windows.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element(boundBy: 1).children(matching: .other).element(boundBy: 1).children(matching: .other).element(boundBy: 1)
        } else {
            element = app.windows.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element(boundBy: 1).children(matching: .other).element(boundBy: 1).children(matching: .other).element(boundBy: 1)
        }

        sleep(3)
        snapshot("01_scanner_screen")
        
        element.children(matching: .other).element(boundBy: 2).tap()
        sleep(3)
//        snapshot("02_barcodes_screen")

        element.children(matching: .button).element.tap()
        sleep(3)
        app.buttons["Create"].tap()
        sleep(1)
        app.buttons["Create"].tap()
        sleep(3)
        snapshot("02_creator_screen")

        app.buttons["Back"].tap()
        element.children(matching: .other).element(boundBy: 3).tap()
        sleep(3)
//        snapshot("04_history_screen")

        element.children(matching: .other).element(boundBy: 5).tap()
        app.staticTexts["QR Code"].tap()
        sleep(3)
        snapshot("03_help_screen")
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
