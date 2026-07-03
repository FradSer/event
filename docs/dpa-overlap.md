# dpa vs. `event` CLI: Overlap-Analyse

Stand: 2026-06-22

## Kontext

Das "dpa" (Daten-Pipeline-Automatisierung) ist die bestehende macOS-Infrastruktur für
bidirektionalen Reminders-Sync. Sie läuft als launchd-Job (`com.claude.pos-sync`) alle 15 Min.

Der `event`-CLI ist ein nativer Swift-CLI auf Basis von EventKit, der direkt Reminders und
Kalender liest und schreibt. Beide Systeme greifen auf denselben EventKit-Store zu.

## dpa-Komponenten (aktuell)

| Datei | Rolle |
|-------|-------|
| `~/.claude/tools/export-reminders.swift` | Liest alle Reminders via EventKit, schreibt `reminders-export.json` |
| `~/.claude/tools/sync-reminders.py` | Liest JSON + `TASKS.md`, synct bidirektional, schreibt `TASKS.md` |
| `~/.claude/tools/update-reminder` | Ändert einzelne Reminders via EventKit (complete, due, title, ...) |
| `~/Cowork/productivity/TASKS.md` | Canonical Markdown-Repräsentation aller Reminders |
| `~/Cowork/productivity/reminders-mapping.json` | UUID-Mapping (Apple-ID zu Task-Slug) |

## `event` CLI: was er kann

| Befehl | Entspricht dpa-Komponente |
|--------|--------------------------|
| `event reminders list --json` | `export-reminders.swift` (Export aller Reminders als JSON) |
| `event reminders update --id UUID --completed` | `update-reminder complete <UUID>` |
| `event reminders update --id UUID --due "YYYY-MM-DD HH:mm:ss"` | `update-reminder due <UUID> <date>` |
| `event reminders update --id UUID --title "..."` | `update-reminder title <UUID> <text>` |
| `event reminders create --title "..." --tags "..."` | kein Äquivalent in dpa |
| `event calendar list/create/update/delete` | kein Äquivalent in dpa |

## Was `event` NICHT repliziert

Die **TASKS.md-Synchronisationslogik** in `sync-reminders.py` hat kein Äquivalent:

- Heuristisches Section-Routing (Active, Someday, Calls to Make, ...)
- ID-Anchor-Format (`<!--id:UUID list:... tags:... cluster:... -->`)
- Pull: neue Reminders erscheinen in TASKS.md
- Push: `[x]`-Status und Due-Date-Änderungen aus TASKS.md werden zurückgeschrieben
- Dashboard-Regenerierung nach jedem Sync

`event sync` dagegen synct mit einem Cloudflare-D1-Backend (andere Architektur, anderer Zweck).

## Optionen

### Option A: Parallel betreiben (Status quo)

Beide Systeme laufen nebeneinander. `event` wird als Ad-hoc-CLI genutzt, dpa-Pipeline
bleibt unberührt.

**Pro:** Null Risiko, kein Umbau.
**Con:** Zwei EventKit-Zugriffspfade; `export-reminders.swift` und `event reminders list --json`
liefern dasselbe, ersteres ist redundant.

### Option B: Read-Path migrieren

`sync-reminders.py` ruft statt `export-reminders.swift` das Kommando
`event reminders list --json` auf. `export-reminders.swift` entfällt.

**Pro:** `event` bietet robustere Fehlerbehandlung, mehr Felder (tags, flagged, url),
aktiver gepflegt. Kein eigenes Swift-Script mehr nötig.
**Con:** Kleiner Umbau in `sync-reminders.py` (JSON-Schemaanpassung). Needs testing.

### Option C: Write-Path migrieren

`update-reminder`-Aufrufe in `sync-reminders.py` durch `event reminders update` ersetzen.

**Pro:** `event` kennt mehr Felder, Flag-Support (flagged, tags).
**Con:** Interface-Differenzen müssen gemappt werden, Umbauaufwand moderat.

### Option D: Vollständige Migration

`sync-reminders.py` neu schreiben, um `event`-CLI statt eigener Swift-Scripts zu nutzen.
TASKS.md-Logik bleibt erhalten, nur die EventKit-Zugriffs-Schicht wird ausgetauscht.

**Pro:** Konsolidierter Stack, ein gepflegtes Tool.
**Con:** Signifikanter Umbauaufwand, Risiko für Sync-Stabilität, Testing-Aufwand.

## Empfehlung

Option B ist der natürliche erste Schritt: geringes Risiko, eliminiert `export-reminders.swift`
als redundante Komponente. Option C danach. Option D nur wenn der dpa-Stack sowieso
refaktoriert wird.

## Offene Entscheidung

**Soll Option B (Read-Path) umgesetzt werden?**

Voraussetzungen:
1. JSON-Schema von `event reminders list --json` gegen `reminders-export.json` abgleichen
2. `sync-reminders.py` anpassen (ca. 30-50 Zeilen)
3. Integrationstests (launchd-Job pausieren, manuell testen, dann reaktivieren)

Oder: Status quo (Option A) beibehalten und `event` nur als CLI-Tool verwenden.
