import XCTest

/// Launches Sprig and drives it like a user: through the menu bar item and the controls inside
/// each panel's web page, then relaunches to check the change stuck. Runs against its own
/// settings suite so it never touches the real ones.
final class SprigUITests: XCTestCase {
    private static let suite = "SprigUITests"
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--state-suite", Self.suite, "--reset-state"]
        app.launch()
    }

    override func tearDown() {
        app.terminate()
    }

    // MARK: Helpers

    private func openMenu() {
        let statusItem = app.statusItems["Sprig"]
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "Menu bar item should appear")
        statusItem.click()
        XCTAssertTrue(app.menuItems["Quit Sprig"].waitForExistence(timeout: 5), "Menu should open")
    }

    private func closeMenu() {
        app.typeKey(.escape, modifierFlags: [])
    }

    private func clickMenuItem(_ path: String...) {
        openMenu()
        var item = app.menuBars.menuItems[path[0]]
        for title in path.dropFirst() {
            item.click()
            item = item.menuItems[title]
        }
        XCTAssertTrue(item.waitForExistence(timeout: 5), "No menu item \(path.joined(separator: " > "))")
        item.click()
    }

    /// Each panel is a web view labelled with its page title. Its contents come from WebKit's
    /// own process, which `containing` queries don't reach, so look panels up by label.
    private func panel(_ name: String) -> XCUIElement {
        app.webViews[name]
    }

    private func waitForText(_ value: String, in element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        element.staticTexts.matching(NSPredicate(format: "value == %@", value)).firstMatch.waitForExistence(timeout: timeout)
    }

    /// Web sliders report their value as a number.
    private func number(_ element: XCUIElement) -> Int? {
        (element.value as? NSNumber)?.intValue ?? (element.value as? String).flatMap(Int.init)
    }

    private func waitUntilGone(_ element: XCUIElement) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter.wait(for: [gone], timeout: 5) == .completed
    }

    private func relaunchKeepingState() {
        // controls save half a second after the last change
        Thread.sleep(forTimeInterval: 1)
        app.terminate()
        app.launchArguments = ["--state-suite", Self.suite]
        app.launch()
    }

    // MARK: Flows

    func testKeyboardIsTheOnlyPanelOpenAtFirstLaunch() {
        XCTAssertTrue(panel("Keyboard").waitForExistence(timeout: 5))
        XCTAssertFalse(panel("Knobs").exists)
        XCTAssertFalse(panel("Sliders").exists)

        openMenu()
        for title in ["Keyboard", "Knobs", "Sliders", "MIDI Output", "MIDI Channel", "Theme", "All Notes Off", "Quit Sprig"] {
            XCTAssertTrue(app.menuItems[title].exists, "Menu should list \(title)")
        }
        closeMenu()
    }

    func testOpeningAndClosingPanelsSurvivesRelaunch() {
        clickMenuItem("Knobs")
        XCTAssertTrue(panel("Knobs").waitForExistence(timeout: 5))
        XCTAssertTrue(panel("Knobs").sliders["K1"].waitForExistence(timeout: 5))

        panel("Keyboard").buttons["Close"].click()
        XCTAssertTrue(waitUntilGone(panel("Keyboard")), "Close button should hide the keyboard")

        relaunchKeepingState()
        XCTAssertTrue(panel("Knobs").waitForExistence(timeout: 5))
        XCTAssertFalse(panel("Keyboard").exists, "A closed panel should stay closed after a relaunch")

        clickMenuItem("Keyboard")
        XCTAssertTrue(panel("Keyboard").waitForExistence(timeout: 5), "Menu should reopen the keyboard")
    }

    func testOctaveButtonsShiftTheRangeAndSurviveRelaunch() {
        let keyboard = panel("Keyboard")
        XCTAssertTrue(waitForText("C2 · 25", in: keyboard))

        keyboard.buttons["Up one octave"].click()
        XCTAssertTrue(waitForText("C3 · 25", in: keyboard))
        keyboard.buttons["Down one octave"].click()
        keyboard.buttons["Down one octave"].click()
        XCTAssertTrue(waitForText("C1 · 25", in: keyboard))

        relaunchKeepingState()
        XCTAssertTrue(waitForText("C1 · 25", in: panel("Keyboard")), "Range should survive a relaunch")
    }

    func testChannelChoiceShowsInPanelsAndSurvivesRelaunch() {
        clickMenuItem("Sliders")
        XCTAssertTrue(waitForText("ch 1", in: panel("Sliders")))

        clickMenuItem("MIDI Channel", "Channel 10")
        XCTAssertTrue(waitForText("ch 10", in: panel("Sliders")), "Header should follow the menu")

        relaunchKeepingState()
        XCTAssertTrue(waitForText("ch 10", in: panel("Sliders")), "Channel should survive a relaunch")
    }

    func testChoosingNoOutputShowsInTheHeader() {
        clickMenuItem("MIDI Output", "None")
        XCTAssertTrue(waitForText("· no output", in: panel("Keyboard")))
    }

    func testKnobValueSurvivesRelaunch() throws {
        clickMenuItem("Knobs")
        let knob = panel("Knobs").sliders["K1"]
        XCTAssertTrue(knob.waitForExistence(timeout: 5))
        XCTAssertEqual(number(knob), 0)

        knob.click()
        for _ in 0..<5 {
            app.typeKey(.upArrow, modifierFlags: [])
        }
        let value = try XCTUnwrap(number(knob))
        XCTAssertGreaterThan(value, 0, "Arrow keys should turn the knob up")

        relaunchKeepingState()
        let relaunched = panel("Knobs").sliders["K1"]
        XCTAssertTrue(relaunched.waitForExistence(timeout: 5))
        XCTAssertEqual(number(relaunched), value, "Knob value should survive a relaunch")
    }

    func testRenamingAKnobFromItsContextMenuSurvivesRelaunch() {
        clickMenuItem("Knobs")
        let knob = panel("Knobs").sliders["K2"]
        XCTAssertTrue(knob.waitForExistence(timeout: 5))

        knob.rightClick()
        let rename = app.menuItems["Rename…"]
        XCTAssertTrue(rename.waitForExistence(timeout: 5), "Right-click should open the control menu")
        rename.click()

        let alert = app.dialogs.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let field = alert.textFields.firstMatch
        field.doubleClick()
        field.typeKey("a", modifierFlags: .command)
        field.typeText("Cutoff")
        alert.buttons["Rename"].click()

        XCTAssertTrue(panel("Knobs").sliders["Cutoff"].waitForExistence(timeout: 5), "Knob should take the new name")

        relaunchKeepingState()
        XCTAssertTrue(panel("Knobs").sliders["Cutoff"].waitForExistence(timeout: 5), "Name should survive a relaunch")
    }

    func testPinAndZoomSurviveRelaunch() {
        let keyboard = panel("Keyboard")
        let pin = keyboard.checkBoxes["Keep window on top"]
        XCTAssertTrue(pin.waitForExistence(timeout: 5))
        XCTAssertEqual(number(pin), 0)
        pin.click()
        // the button names the action it will take next
        let unpin = keyboard.checkBoxes["Stop keeping window on top"]
        XCTAssertTrue(unpin.waitForExistence(timeout: 5))
        XCTAssertEqual(number(unpin), 1)

        let width = keyboard.frame.width
        keyboard.buttons["+"].click()
        let grown = NSPredicate { _, _ in keyboard.frame.width > width * 1.05 }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: grown, object: nil)], timeout: 5), .completed,
                       "+ should make the window bigger")
        let zoomedWidth = keyboard.frame.width

        relaunchKeepingState()
        let relaunched = panel("Keyboard")
        XCTAssertTrue(relaunched.waitForExistence(timeout: 5))
        XCTAssertTrue(relaunched.checkBoxes["Stop keeping window on top"].waitForExistence(timeout: 5), "Pin should survive a relaunch")
        XCTAssertEqual(relaunched.frame.width, zoomedWidth, accuracy: 2, "Zoom should survive a relaunch")
    }
}
