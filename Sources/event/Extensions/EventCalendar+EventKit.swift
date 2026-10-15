#if canImport(EventKit)

  import EventKit
  import EventModels
  import Foundation

  extension EventCalendar {
    init(from ekCalendar: EKCalendar) {
      let color = ekCalendar.cgColor.flatMap { cgColor -> String? in
        guard let components = cgColor.components, components.count >= 3 else { return nil }
        return String(
          format: "#%02X%02X%02X",
          Int(components[0] * 255),
          Int(components[1] * 255),
          Int(components[2] * 255)
        )
      }

      self.init(
        id: ekCalendar.calendarIdentifier,
        title: ekCalendar.title,
        source: ekCalendar.source?.title,
        sourceType: Self.sourceTypeName(ekCalendar.source?.sourceType),
        allowsContentModifications: ekCalendar.allowsContentModifications,
        isImmutable: ekCalendar.isImmutable,
        color: color
      )
    }

    private static func sourceTypeName(_ sourceType: EKSourceType?) -> String? {
      switch sourceType {
      case .local: return "local"
      case .exchange: return "exchange"
      case .calDAV: return "calDAV"
      case .mobileMe: return "mobileMe"
      case .subscribed: return "subscribed"
      case .birthdays: return "birthdays"
      case .none: return nil
      @unknown default: return "unknown"
      }
    }
  }

#endif
