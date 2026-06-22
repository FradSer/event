import XCTest

@testable import AppleSyncKit
@testable import EventModels
@testable import EventSync

#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif

final class EventEncryptorTests: XCTestCase {
  private func makeEncryptor() -> EventEncryptor {
    EventEncryptor(encryption: EncryptionService(key: SymmetricKey(size: .bits256)))
  }

  private func makeReminder(notes: String?, url: String?) -> Reminder {
    Reminder(
      id: "r1", title: "Buy milk", isCompleted: false, isFlagged: false, list: "Errands",
      notes: notes, url: url, location: nil, timeZone: "UTC", dueDate: nil, startDate: nil,
      completionDate: nil, creationDate: "2026-01-01", lastModifiedDate: "2026-01-02",
      externalId: nil, priority: 0, alarms: nil, recurrenceRules: nil, locationTrigger: nil)
  }

  private func makeEvent(notes: String?, location: String?) -> CalendarEvent {
    CalendarEvent(
      id: "e1", title: "Standup", calendar: "Work", startDate: "2026-01-01 09:00:00",
      endDate: "2026-01-01 09:30:00", isAllDay: false, location: location, notes: notes,
      url: nil, timeZone: "UTC", creationDate: "2026-01-01", lastModifiedDate: "2026-01-02",
      status: nil, availability: nil, alarms: nil, recurrenceRules: nil, attendees: nil)
  }

  // MARK: - Reminders

  func testReminderEncryptSealsSensitiveFieldsAndDecryptsBack() async throws {
    let encryptor = makeEncryptor()
    let reminder = makeReminder(notes: "secret note", url: "https://example.com")

    let encrypted = try await encryptor.encryptReminders([reminder])
    XCTAssertEqual(encrypted.count, 1)
    // Sensitive fields move into the carrier; url is cleared.
    XCTAssertNotEqual(encrypted[0].notes, reminder.notes)
    XCTAssertNil(encrypted[0].url)
    XCTAssertNotNil(EncryptedCarrier.fromJSON(encrypted[0].notes ?? ""))
    // Title and list stay plaintext so reminders remain listable.
    XCTAssertEqual(encrypted[0].title, "Buy milk")
    XCTAssertEqual(encrypted[0].list, "Errands")

    let decrypted = try await encryptor.decryptReminders(encrypted)
    XCTAssertEqual(decrypted[0].notes, "secret note")
    XCTAssertEqual(decrypted[0].url, "https://example.com")
  }

  func testReminderWithNothingSensitivePassesThrough() async throws {
    let encryptor = makeEncryptor()
    let reminder = makeReminder(notes: nil, url: nil)
    let encrypted = try await encryptor.encryptReminders([reminder])
    XCTAssertNil(encrypted[0].notes)
  }

  // MARK: - Calendar Events

  func testEventEncryptSealsSensitiveFieldsAndDecryptsBack() async throws {
    let encryptor = makeEncryptor()
    let event = makeEvent(notes: "agenda", location: "Room 4")

    let encrypted = try await encryptor.encryptEvents([event])
    XCTAssertNotEqual(encrypted[0].notes, event.notes)
    XCTAssertNil(encrypted[0].location)
    XCTAssertNotNil(EncryptedCarrier.fromJSON(encrypted[0].notes ?? ""))
    XCTAssertEqual(encrypted[0].title, "Standup")

    let decrypted = try await encryptor.decryptEvents(encrypted)
    XCTAssertEqual(decrypted[0].notes, "agenda")
    XCTAssertEqual(decrypted[0].location, "Room 4")
  }

  // MARK: - Pull response

  func testDecryptResponseLeavesTombstonesUntouched() async throws {
    let encryptor = makeEncryptor()
    let tombstone = PullItem(
      id: "r1", data: makeReminder(notes: nil, url: nil), deleted: true,
      updatedAt: "2026-01-01", lastModified: "2026-01-01")
    let response = PullResponse(items: [tombstone], cursor: "1|r1", hasMore: false)

    let decrypted = try await encryptor.decryptResponse(response)
    XCTAssertEqual(decrypted.items.count, 1)
    XCTAssertTrue(decrypted.items[0].deleted)
  }

  func testPlaintextNotesSurviveDecrypt() async throws {
    let encryptor = makeEncryptor()
    let reminder = makeReminder(notes: "just text", url: nil)
    let decrypted = try await encryptor.decryptReminders([reminder])
    XCTAssertEqual(decrypted[0].notes, "just text")
  }
}
