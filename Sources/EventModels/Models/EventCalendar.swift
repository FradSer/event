import Foundation

// MARK: - Event Calendar Model

/// One calendar for the `.event` entity, as reported by
/// `event calendar calendars`.
///
/// `event calendar list` can only surface a calendar that holds an event
/// inside the queried window, so calendars with no event in that window were
/// invisible and a caller could not tell that a calendar existed. This model
/// carries the catalog entry instead: `source` tells two same-named calendars
/// apart, and `allowsContentModifications` tells a caller whether a write can
/// succeed before the write is attempted.
///
/// `source`, `sourceType`, `allowsContentModifications`, `isImmutable`, and
/// `color` are optional because the sync backends store events only. They
/// cannot describe a calendar catalog, so they leave these fields empty.
public struct EventCalendar: Codable, Sendable {
  public let id: String
  public let title: String
  public let source: String?
  public let sourceType: String?
  public let allowsContentModifications: Bool?
  public let isImmutable: Bool?
  public let color: String?

  public init(
    id: String,
    title: String,
    source: String? = nil,
    sourceType: String? = nil,
    allowsContentModifications: Bool? = nil,
    isImmutable: Bool? = nil,
    color: String? = nil
  ) {
    self.id = id
    self.title = title
    self.source = source
    self.sourceType = sourceType
    self.allowsContentModifications = allowsContentModifications
    self.isImmutable = isImmutable
    self.color = color
  }
}
