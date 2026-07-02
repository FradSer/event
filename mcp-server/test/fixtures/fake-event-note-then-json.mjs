#!/usr/bin/env node
process.stdout.write("Note: AdvancedReminderEdit shortcut not found.\n");
process.stdout.write("Install it at: https://example.com\n");
process.stdout.write("Without it, only basic reminder fields are supported.\n");
process.stdout.write(JSON.stringify({ id: "abc-123", title: "Created despite missing shortcut" }));
