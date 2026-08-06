Feature: Preserve calendar event timezones during serialization

  Scenario: Format a timed EventKit event in its own timezone
    Given a timed EventKit event with timezone "America/New_York"
    And its start instant is "2026-03-10 19:00:00" UTC
    When the event is converted to a CalendarEvent without an explicit timezone
    Then its start date is "2026-03-10 15:00:00"
    And its timezone is "America/New_York"
