# Task 002: Delete SubtaskService.swift

## Overview
Delete SubtaskService.swift since subtask functionality relied on NotesParser.

## BDD Scenario

```gherkin
Scenario: Delete SubtaskService
  Given SubtaskService.swift exists
  When I delete the file
  Then no code should reference SubtaskService
```

## Files
- Delete: `Sources/event/Services/SubtaskService.swift`

## Steps
1. Delete the SubtaskService.swift file
2. Verify no remaining references in codebase

## Verification
```bash
grep -r "SubtaskService" Sources/
# Should return no matches
```
