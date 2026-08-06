Feature: Preserve calendar event timezones during serialization

  Scenario: Format a timed EventKit event in its own timezone
    Given a timed EventKit event with timezone "America/New_York"
    And its start instant is "2026-03-10 19:00:00" UTC
    When the event is converted to a CalendarEvent without an explicit timezone
    Then its start date is "2026-03-10 15:00:00"
    And its timezone is "America/New_York"

  Scenario: Change a backend event timezone without moving its instant
    Given a timed event starts at "2026-03-10 14:00:00" in "America/New_York"
    When its timezone changes to "America/Los_Angeles" without new dates
    Then its start date is "2026-03-10 11:00:00"
    And the instant remains unchanged

  Scenario: Clear a timed event timezone during sync
    Given a timed event currently has timezone "America/New_York"
    When a synced timed event has no timezone identifier
    Then the local event timezone is cleared
    And its dates are interpreted in the local timezone

  Scenario: Compare sync ranges using timed event instants
    Given a timed event starts at "2026-03-10 23:30:00" in "America/Los_Angeles"
    When its sync range is compared with the UTC date "2026-03-11"
    Then the event overlaps that sync date

  Scenario: Detect a calendar timezone-only change in snapshots
    Given two calendar events differ only by their timezone identifier
    When their content snapshots are compared
    Then the snapshots are different
