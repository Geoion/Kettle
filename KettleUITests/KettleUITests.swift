//
//  KettleUITests.swift
//  KettleUITests
//
//  Created by Eski Yin on 2025/4/27.
//

import XCTest

final class KettleUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        app = nil
    }

    func testMainNavigation() throws {
        // Test navigation to each main section
        XCTAssertTrue(app.buttons["Packages"].exists)
        app.buttons["Packages"].tap()
        
        XCTAssertTrue(app.buttons["Services"].exists)
        app.buttons["Services"].tap()
        
        XCTAssertTrue(app.buttons["Taps"].exists)
        app.buttons["Taps"].tap()
        
        XCTAssertTrue(app.buttons["Settings"].exists)
        app.buttons["Settings"].tap()
    }
    
    func testPackagesList() throws {
        // Navigate to Packages
        app.buttons["Packages"].tap()
        
        // Test search functionality
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.exists)
        searchField.tap()
        searchField.typeText("git")
        
        // Wait for search results
        let predicate = NSPredicate(format: "exists == true")
        let packageList = app.tables.firstMatch
        expectation(for: predicate, evaluatedWith: packageList, handler: nil)
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testServiceControls() throws {
        // Navigate to Services
        app.buttons["Services"].tap()
        
        // Wait for services list to load
        let servicesList = app.tables.firstMatch
        XCTAssertTrue(servicesList.waitForExistence(timeout: 5))
        
        // Select first service if available
        if servicesList.cells.count > 0 {
            servicesList.cells.element(boundBy: 0).tap()
            
            // Check for service control buttons
            XCTAssertTrue(app.buttons["Start Service"].exists || app.buttons["Stop Service"].exists)
        }
    }
    
    func testSettingsInteraction() throws {
        // Navigate to Settings
        app.buttons["Settings"].tap()
        
        // Test language selection
        let languageButton = app.buttons["Language"]
        XCTAssertTrue(languageButton.exists)
        languageButton.tap()
        
        // Test appearance selection
        let appearanceButton = app.buttons["Appearance"]
        XCTAssertTrue(appearanceButton.exists)
        appearanceButton.tap()
        
        // Test about section
        let aboutButton = app.buttons["About"]
        XCTAssertTrue(aboutButton.exists)
        aboutButton.tap()
    }
    
    func testTapManagement() throws {
        // Navigate to Taps
        app.buttons["Taps"].tap()
        
        // Wait for taps list to load
        let tapsList = app.tables.firstMatch
        XCTAssertTrue(tapsList.waitForExistence(timeout: 5))
        
        // Test search functionality
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.exists)
        searchField.tap()
        searchField.typeText("homebrew/core")
        
        // Wait for search results
        let predicate = NSPredicate(format: "exists == true")
        expectation(for: predicate, evaluatedWith: tapsList, handler: nil)
        waitForExpectations(timeout: 5, handler: nil)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
