import XCTest
@testable import event

final class ShortcutsServiceTests: XCTestCase {

    func testShortcutsServiceInitialization() async {
        let service = ShortcutsService()
        XCTAssertNotNil(service)
    }

    func testIsShortcutInstalledReturnsFalseForNonexistentShortcut() async throws {
        let service = ShortcutsService()
        let isInstalled = try await service.isShortcutInstalled(name: "NonexistentShortcut_12345_XYZ")

        XCTAssertFalse(isInstalled)
    }

    func testRunShortcutThrowsForNonexistentShortcut() async {
        let service = ShortcutsService()
        let payload = ShortcutReminderPayload(
            title: "Test",
            listName: nil,
            notes: nil,
            url: nil,
            tags: nil,
            parentTitle: nil
        )

        do {
            _ = try await service.runShortcut(name: "NonexistentShortcut_12345_XYZ", input: payload)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is EventCLIError)
        }
    }
}
