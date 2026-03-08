# Task 010: Delete SubtaskTests.swift

## Overview
Delete test file for Subtask model.

## BDD Scenario

```gherkin
Scenario: Delete Subtask tests
  Given SubtaskTests.swift exists
  When I delete the file
  Then tests should pass without it
```

## Files
- Delete: `Tests/eventTests/Models/SubtaskTests.swift`

## Verification
```bash
swift test
# Should pass without SubtaskTests
```
