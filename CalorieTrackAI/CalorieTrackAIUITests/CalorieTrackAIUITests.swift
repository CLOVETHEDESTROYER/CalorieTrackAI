//
//  CalorieTrackAIUITests.swift
//  CalorieTrackAIUITests
//
//  Created by Xander on 7/21/25.
//

import XCTest

final class CalorieTrackAIUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testManualFoodNameFieldAcceptsTextInTestingMode() throws {
        let app = XCUIApplication()
        app.launchEnvironment["MFT_UNLOCK_FEATURES_FOR_TESTING"] = "1"
        app.launch()

        app.tabBars.buttons["Log"].tap()

        let foodNameField = app.textFields["glass-text-field-Food name"]
        XCTAssertTrue(foodNameField.waitForExistence(timeout: 5), "Food name field should be visible on the Log tab.")

        foodNameField.tap()
        foodNameField.typeText("Greek yogurt")

        XCTAssertEqual(foodNameField.value as? String, "Greek yogurt")
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    @MainActor
    func testMovementChallengeMannequinCards() throws {
        let challenges = [
            ("push_up", "Push-Up Test"),
            ("squat", "Squat Test"),
            ("jumping_jack", "Jumping Jacks"),
            ("plank", "Plank Hold")
        ]

        for (rawValue, title) in challenges {
            let app = XCUIApplication()
            app.launchEnvironment["MFT_UNLOCK_FEATURES_FOR_TESTING"] = "1"
            app.launchEnvironment["MFT_INITIAL_CHALLENGE_FOR_TESTING"] = rawValue
            app.launch()

            let titleLabel = app.staticTexts[title]
            XCTAssertTrue(
                titleLabel.waitForExistence(timeout: 5),
                "\(title) should be visible in the challenge pager."
            )

            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = title.replacingOccurrences(of: " ", with: "-")
            screenshot.lifetime = .keepAlways
            add(screenshot)

            app.terminate()
        }
    }
}
