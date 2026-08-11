Feature: Query reminders by a due-date window

  `event reminders list` supports the same time-range query as
  `event calendar list`: `--start` / `--end` filter reminders by their due
  date, and the default output mode is human-readable markdown (no `--json`
  required). The window is half-open: the start day is inclusive and the end
  day is exclusive, matching calendar semantics.

  Scenario: List reminders due within a date range
    Given reminders due on "2026-08-09", "2026-08-10", and "2026-08-24"
    When I list reminders with --start "2026-08-10" --end "2026-08-24"
    Then only the reminder due on "2026-08-10" is returned

  Scenario: End day is exclusive
    Given a reminder due on "2026-08-24 09:00:00"
    When I list reminders with --start "2026-08-10" --end "2026-08-24"
    Then no reminders are returned

  Scenario: Default listing hides completed reminders and shows all dates
    Given an incomplete reminder and a completed reminder with no due dates
    When I list reminders without --start/--end
    Then only the incomplete reminder is returned

  Scenario: Due dates outside the window are excluded
    Given reminders due on "2026-07-31" and "2026-09-01"
    When I list reminders with --start "2026-08-10" --end "2026-08-24"
    Then no reminders are returned

  Scenario: Invalid start date is rejected
    When I list reminders with --start "2026-13-99" --end "2026-08-24"
    Then the command fails with an invalid-date error

  Scenario: Reversed date window is rejected
    When I list reminders with --start "2026-08-24" --end "2026-08-10"
    Then the command fails with an invalid-date-range error

  Scenario: Invalid ISO due dates are excluded
    Given a reminder due on "2026-02-30T00:00:00Z"
    When I list reminders with --start "2026-03-01" --end "2026-03-03"
    Then no reminders are returned

  Scenario: One-sided backend windows are rejected
    When a backend fetches reminders with only --start "2026-08-10"
    Then the fetch fails with an invalid-input error

  Scenario: Reversed backend windows are rejected
    When a backend fetches reminders with --start "2026-08-24" --end "2026-08-10"
    Then the fetch fails with an invalid-date-range error
