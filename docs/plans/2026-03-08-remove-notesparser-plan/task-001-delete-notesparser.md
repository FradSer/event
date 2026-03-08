# Task 001: Delete NotesParser.swift

## Overview
Delete NotesParser.swift file from the codebase.

## BDD Scenario

```gherkin
Scenario: Delete NotesParser file
  Given NotesParser.swift exists in Sources/event/Utilities/
  When I delete the file
  Then no code should reference NotesParser
```

## Files
- Delete: `Sources/event/Utilities/NotesParser.swift`

## Steps
1. Delete the NotesParser.swift file
2. Verify no remaining references in codebase

## Verification
```bash
grep -r "NotesParser" Sources/
# Should return no matches
```
