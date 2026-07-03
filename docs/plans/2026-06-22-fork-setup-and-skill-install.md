# Fork Setup & Skill Install

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to work through this task-by-task.

**Goal:** Bring the mvroeder/apple-events-cli fork to a working local state: binary installed, skill in claude-config, dpa overlap documented.

**Architecture:** Fork + remotes are already in place. Binary is pre-built. Work is: install binary, smoke-test, copy skill into claude-config, write overlap doc.

**Tech Stack:** Swift CLI (EventKit), macOS, claude-config skill convention

## Global Constraints

- No commits or pushes — user handles these
- No D1 sync setup
- No dpa refactoring — document only
- Skill structure must match existing pattern (anwalt-de-exigo)
- Binary target: `/usr/local/bin/event`

---

### Task 1: Confirm fork status

**Files:** none

- [x] **Step 1: Verify fork + remotes**

```bash
gh api repos/mvroeder/apple-events-cli --jq '{name,fork,parent: .parent.full_name}'
git -C /Users/mvroeder/dev/apple-events-cli remote -v
```

Expected: fork=true, parent=FradSer/event, origin → mvroeder, upstream → FradSer

- [x] **Step 2: Confirm binary exists**

```bash
ls -lh /Users/mvroeder/dev/apple-events-cli/.build/release/event
```

Expected: ~23 MB arm64 binary, built recently

---

### Task 2: Install binary

**Files:**
- Read: `/Users/mvroeder/dev/apple-events-cli/.build/release/event`
- Write: `/usr/local/bin/event`

- [ ] **Step 1: Install binary**

```bash
sudo cp /Users/mvroeder/dev/apple-events-cli/.build/release/event /usr/local/bin/event
sudo chmod 755 /usr/local/bin/event
```

- [ ] **Step 2: Verify installation**

```bash
which event
event --version
```

Expected: `/usr/local/bin/event`, version string

---

### Task 3: Smoke test (reminder: grant EventKit permission)

**Note to user:** On first run, macOS shows a Reminders permission dialog. Confirm in System Settings > Privacy & Security > Reminders if needed.

- [ ] **Step 1: Run smoke test**

```bash
event reminders list
```

Expected: list of reminders (or permission dialog prompt)

- [ ] **Step 2: Verify calendar access**

```bash
event calendar list
```

Expected: list of upcoming calendar events

---

### Task 4: Install skill to claude-config

**Files:**
- Source: `/Users/mvroeder/dev/apple-events-cli/skills/apple-events/`
- Dest: `/Users/mvroeder/dev/claude-config/skills/apple-events/`

Pattern reference: `claude-config/skills/anwalt-de-exigo/` (SKILL.md + references/)

- [ ] **Step 1: Copy skill directory**

```bash
cp -r /Users/mvroeder/dev/apple-events-cli/skills/apple-events \
      /Users/mvroeder/dev/claude-config/skills/apple-events
```

- [ ] **Step 2: Verify structure**

```bash
ls /Users/mvroeder/dev/claude-config/skills/apple-events/
```

Expected: SKILL.md, evals/, references/

- [ ] **Step 3: Confirm SKILL.md trigger conditions make sense**

Read SKILL.md — check that `name:` and `description:` frontmatter is set correctly and won't conflict with the existing `reminders` skill.

---

### Task 5: Document dpa overlap

**Files:**
- Create: `docs/dpa-overlap.md`

- [ ] **Step 1: Write overlap analysis**

See content below — write to `docs/dpa-overlap.md` in the repo root.

---
