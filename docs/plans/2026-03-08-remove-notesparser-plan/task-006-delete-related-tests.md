# Task 006: Delete Related Test Files

## Overview
Delete test files related to NotesParser and SubtaskService.

## BDD Scenario

```gherkin
Scenario: Delete NotesParser tests
  Given NotesParserTests.swift exists
  When I delete the file
  Then tests should no longer reference deleted code
```

## Files
- Delete: `Tests/eventTests/Utilities/NotesParserTests.swift`

## Steps
1. Delete NotesParserTests.swift

## Verification
```bash
swift test
# Should pass without NotesParserTests
```
