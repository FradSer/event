import Foundation

// MARK: - Markdown Formatter

struct MarkdownFormatter: OutputFormatter {
    func format<T: Encodable>(_ data: T) -> String {
        // Handle different data types
        if let reminders = data as? [Reminder] {
            return formatReminders(reminders)
        } else if let reminder = data as? Reminder {
            return formatReminder(reminder)
        } else if let events = data as? [CalendarEvent] {
            return formatCalendarEvents(events)
        } else if let event = data as? CalendarEvent {
            return formatCalendarEvent(event)
        } else if let lists = data as? [ReminderList] {
            return formatReminderLists(lists)
        } else if let list = data as? ReminderList {
            return formatReminderList(list)
        } else if let subtasks = data as? [Subtask] {
            return formatSubtasks(subtasks)
        } else {
            // Fallback to JSON for unknown types
            return JSONFormatter().format(data)
        }
    }

    // MARK: - Reminder Formatting

    private func formatReminders(_ reminders: [Reminder]) -> String {
        guard !reminders.isEmpty else {
            return "No reminders found."
        }

        var output = "### Reminders\n\n"

        // Group by list
        let grouped = Dictionary(grouping: reminders, by: { $0.list })

        for (listName, listReminders) in grouped.sorted(by: { $0.key < $1.key }) {
            output += "**\(listName)**\n\n"

            for reminder in listReminders {
                let checkbox = reminder.isCompleted ? "[x]" : "[ ]"
                output += "- \(checkbox) \(reminder.title)\n"

                if let dueDate = reminder.dueDate {
                    output += "  - Due: \(dueDate)\n"
                }

                if reminder.priority > 0 {
                    let priorityLabel = priorityToLabel(reminder.priority)
                    output += "  - Priority: \(priorityLabel)\n"
                }

                if let notes = reminder.notes, !notes.isEmpty {
                    let parsed = NotesParser.parse(notes)
                    if !parsed.userNotes.isEmpty {
                        output += "  - Notes: \(parsed.userNotes)\n"
                    }
                    if !parsed.tags.isEmpty {
                        output += "  - Tags: \(parsed.tags.map { "#\($0)" }.joined(separator: ", "))\n"
                    }
                    if !parsed.subtasks.isEmpty {
                        output +=
                            "  - Subtasks: \(parsed.subtasks.count) (\(parsed.subtasks.filter { $0.isCompleted }.count) completed)\n"
                    }
                }

                output += "  - ID: `\(reminder.id)`\n"
            }

            output += "\n"
        }

        return output
    }

    private func formatReminder(_ reminder: Reminder) -> String {
        var output = "### Reminder: \(reminder.title)\n\n"

        let checkbox = reminder.isCompleted ? "[x]" : "[ ]"
        output += "**Status:** \(checkbox) \(reminder.isCompleted ? "Completed" : "Incomplete")\n\n"

        output += "**List:** \(reminder.list)\n\n"

        if let dueDate = reminder.dueDate {
            output += "**Due Date:** \(dueDate)\n\n"
        }

        if reminder.priority > 0 {
            let priorityLabel = priorityToLabel(reminder.priority)
            output += "**Priority:** \(priorityLabel)\n\n"
        }

        if let notes = reminder.notes, !notes.isEmpty {
            let parsed = NotesParser.parse(notes)
            if !parsed.userNotes.isEmpty {
                output += "**Notes:**\n\(parsed.userNotes)\n\n"
            }
            if !parsed.tags.isEmpty {
                output += "**Tags:** \(parsed.tags.map { "#\($0)" }.joined(separator: ", "))\n\n"
            }
            if !parsed.subtasks.isEmpty {
                output += "**Subtasks:**\n"
                for subtask in parsed.subtasks {
                    let checkbox = subtask.isCompleted ? "[x]" : "[ ]"
                    output += "- \(checkbox) \(subtask.title)\n"
                }
                output += "\n"
            }
        }

        output += "**ID:** `\(reminder.id)`\n"

        return output
    }

    // MARK: - Calendar Event Formatting

    private func formatCalendarEvents(_ events: [CalendarEvent]) -> String {
        guard !events.isEmpty else {
            return "No calendar events found."
        }

        var output = "### Calendar Events\n\n"

        for event in events {
            output += "**\(event.title)**\n"
            output += "- Calendar: \(event.calendar)\n"
            output += "- Start: \(event.startDate)\n"
            output += "- End: \(event.endDate)\n"

            if event.isAllDay {
                output += "- All Day Event\n"
            }

            if let location = event.location {
                output += "- Location: \(location)\n"
            }

            if let notes = event.notes, !notes.isEmpty {
                output += "- Notes: \(notes)\n"
            }

            output += "- ID: `\(event.id)`\n\n"
        }

        return output
    }

    private func formatCalendarEvent(_ event: CalendarEvent) -> String {
        var output = "### Event: \(event.title)\n\n"

        output += "**Calendar:** \(event.calendar)\n\n"
        output += "**Start:** \(event.startDate)\n\n"
        output += "**End:** \(event.endDate)\n\n"

        if event.isAllDay {
            output += "**All Day Event**\n\n"
        }

        if let location = event.location {
            output += "**Location:** \(location)\n\n"
        }

        if let notes = event.notes, !notes.isEmpty {
            output += "**Notes:**\n\(notes)\n\n"
        }

        if let attendees = event.attendees, !attendees.isEmpty {
            output += "**Attendees:**\n"
            for attendee in attendees {
                let name = attendee.name ?? "Unknown"
                let status = attendee.status ?? "unknown"
                output += "- \(name) (\(status))\n"
            }
            output += "\n"
        }

        output += "**ID:** `\(event.id)`\n"

        return output
    }

    // MARK: - List Formatting

    private func formatReminderLists(_ lists: [ReminderList]) -> String {
        guard !lists.isEmpty else {
            return "No reminder lists found."
        }

        var output = "### Reminder Lists\n\n"

        for list in lists {
            output += "- **\(list.title)**"
            if list.isImmutable {
                output += " (System)"
            }
            output += "\n"
            output += "  - ID: `\(list.id)`\n"
        }

        return output
    }

    private func formatReminderList(_ list: ReminderList) -> String {
        var output = "### List: \(list.title)\n\n"
        output += "**ID:** `\(list.id)`\n\n"

        if list.isImmutable {
            output += "**Type:** System List (Immutable)\n"
        }

        return output
    }

    // MARK: - Subtask Formatting

    private func formatSubtasks(_ subtasks: [Subtask]) -> String {
        guard !subtasks.isEmpty else {
            return "No subtasks found."
        }

        var output = "### Subtasks\n\n"

        for subtask in subtasks {
            let checkbox = subtask.isCompleted ? "[x]" : "[ ]"
            output += "- \(checkbox) \(subtask.title)\n"
            output += "  - ID: `\(subtask.id)`\n"
        }

        return output
    }

    // MARK: - Helper Methods

    private func priorityToLabel(_ priority: Int) -> String {
        switch priority {
        case 1: return "High (!!!)"
        case 5: return "Medium (!!)"
        case 9: return "Low (!)"
        default: return "Priority \(priority)"
        }
    }
}
