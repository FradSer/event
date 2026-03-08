import XCTest
@testable import event

final class ShortcutPayloadTests: XCTestCase {

    func testShortcutReminderPayloadBasic() throws {
        let payload = ShortcutReminderPayload(
            title: "Test Reminder",
            listName: "Work",
            notes: "Test notes",
            url: "https://example.com",
            tags: "work,urgent",
            parentTitle: nil
        )

        XCTAssertEqual(payload.title, "Test Reminder")
        XCTAssertEqual(payload.listName, "Work")
        XCTAssertEqual(payload.notes, "Test notes")
        XCTAssertEqual(payload.url, "https://example.com")
        XCTAssertEqual(payload.tags, "work,urgent")
        XCTAssertNil(payload.parentTitle)
    }

    func testShortcutReminderPayloadWithParent() throws {
        let payload = ShortcutReminderPayload(
            title: "Subtask",
            listName: nil,
            notes: nil,
            url: nil,
            tags: nil,
            parentTitle: "Parent Task"
        )

        XCTAssertEqual(payload.title, "Subtask")
        XCTAssertEqual(payload.parentTitle, "Parent Task")
        XCTAssertNil(payload.listName)
    }

    func testShortcutReminderPayloadEncodable() throws {
        let payload = ShortcutReminderPayload(
            title: "Test",
            listName: "Personal",
            notes: "Notes",
            url: nil,
            tags: "test",
            parentTitle: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)

        XCTAssertFalse(data.isEmpty)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["title"] as? String, "Test")
        XCTAssertEqual(json?["listName"] as? String, "Personal")
    }

    func testAdvancedReminderEditPayloadBasic() throws {
        let payload = AdvancedReminderEditPayload(
            title: "Edit Test",
            list: "Work",
            tags: "updated,test",
            url: "https://updated.com",
            parentTitle: nil,
            isFlagged: nil
        )

        XCTAssertEqual(payload.title, "Edit Test")
        XCTAssertEqual(payload.list, "Work")
        XCTAssertEqual(payload.tags, "updated,test")
        XCTAssertEqual(payload.url, "https://updated.com")
        XCTAssertNil(payload.parentTitle)
    }

    func testAdvancedReminderEditPayloadEncodable() throws {
        let payload = AdvancedReminderEditPayload(
            title: "Test",
            list: nil,
            tags: "tag1,tag2",
            url: nil,
            parentTitle: "Parent",
            isFlagged: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)

        XCTAssertFalse(data.isEmpty)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["title"] as? String, "Test")
        XCTAssertEqual(json?["tags"] as? String, "tag1,tag2")
        XCTAssertEqual(json?["parentTitle"] as? String, "Parent")
    }
}
