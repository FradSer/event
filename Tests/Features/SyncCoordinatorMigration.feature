Feature: Event sync uses the shared coordinator
  Scenario: Sync state is stored in one journal
    Given the event sync configuration is loaded
    When a sync operation runs
    Then checkpoints are written to sync-state.json
    And status reads each entity cursor from that journal

  Scenario: A full sync preserves dependency order
    Given reminders, calendar events, and reminder lists are selected
    When a full sync runs
    Then reminder lists are pulled before reminders
    And reminders are pulled before calendar events
    And every pull completes before the first push
    And pushes run in reminders, calendar events, reminder lists order

  Scenario: A one-directional multi-entity sync uses one lock
    Given reminders, calendar events, and reminder lists are selected
    When a push-only or pull-only sync runs
    Then one coordinator lock covers every selected entity
    And pulls run in reminder lists, reminders, calendar events order
    And pushes run in reminders, calendar events, reminder lists order

  Scenario: EventKit records use safe last-write-wins timestamps
    Given an EventKit reminder or calendar event exists locally
    When its modification timestamp is unavailable
    Then its creation timestamp is used for conflict comparison
    And a record without either timestamp is treated as unknown

  Scenario: Reminder lists accept remote values without timestamps
    Given a reminder list exists locally without a modification timestamp
    When a remote list value is pulled
    Then the remote value is applied

  Scenario: Calendar deletion candidates stay within the sync window
    Given a previously synced calendar event is absent from the window snapshot
    When deletion candidates are filtered
    Then only events whose recorded date range overlaps the sync window are considered
    And EventKit confirms each candidate no longer exists before remote deletion

  Scenario: Linux calendar sync retains date-range metadata
    Given a calendar event is pushed or pulled through the Linux SQLite source
    When its sync checkpoint is recorded
    Then the event's canonical date range is stored under its remote ID
    And explicit SQLite deletion flags remain the Linux deletion candidates

  Scenario: Sensitive entities remain encrypted
    Given reminders, calendar events, and reminder lists are synchronized
    When records cross the remote client boundary
    Then reminders and calendar events are encrypted on push and decrypted on pull
    And reminder lists remain plaintext

  Scenario: Direct remote deletion reports a stale conflict
    Given a direct Cloudflare delete loses last-write-wins conflict resolution
    When the backend returns a rejected delete result
    Then the event command reports a sync error instead of claiming success
