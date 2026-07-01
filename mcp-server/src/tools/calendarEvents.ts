import type { CallToolResult, Tool } from "@modelcontextprotocol/sdk/types.js";
import { runEventCli, runEventCliText, valueArgs } from "../eventCli.js";

export const calendarEventsTool: Tool = {
  name: "calendar_events",
  description: "Manage Apple Calendar events. Actions: list, create, update, delete.",
  inputSchema: {
    type: "object",
    properties: {
      action: {
        type: "string",
        enum: ["list", "create", "update", "delete"],
        description: "The operation to perform.",
      },
      id: { type: "string", description: "Event ID (required for update, delete)." },
      title: { type: "string", description: "Event title (required for create)." },
      start: {
        type: "string",
        description: "Start date. yyyy-MM-dd for all-day, yyyy-MM-dd HH:mm:ss for timed.",
      },
      end: {
        type: "string",
        description: "End date. yyyy-MM-dd for all-day, yyyy-MM-dd HH:mm:ss for timed.",
      },
      calendar: { type: "string", description: "Calendar name, to filter (list) or target (create)." },
      location: { type: "string", description: "Event location." },
      notes: { type: "string", description: "Event notes." },
      span: {
        type: "string",
        enum: ["this", "future", "all"],
        description: "Delete span for recurring events, default 'this'.",
      },
    },
    required: ["action"],
  },
};

export async function handleCalendarEvents(args: Record<string, unknown>): Promise<CallToolResult> {
  const action = args.action as string;

  switch (action) {
    case "list": {
      const cliArgs = [
        "calendar",
        "list",
        ...valueArgs([
          ["--start", args.start as string | undefined],
          ["--end", args.end as string | undefined],
          ["--calendar", args.calendar as string | undefined],
        ]),
        "--json",
      ];
      const result = await runEventCli(cliArgs);
      return { content: [{ type: "text", text: JSON.stringify(result) }] };
    }
    case "create": {
      const cliArgs = [
        "calendar",
        "create",
        "--title",
        String(args.title),
        "--start",
        String(args.start),
        "--end",
        String(args.end),
        ...valueArgs([
          ["--calendar", args.calendar as string | undefined],
          ["--location", args.location as string | undefined],
          ["--notes", args.notes as string | undefined],
        ]),
        "--json",
      ];
      const result = await runEventCli(cliArgs);
      return { content: [{ type: "text", text: JSON.stringify(result) }] };
    }
    case "update": {
      const cliArgs = [
        "calendar",
        "update",
        "--id",
        String(args.id),
        ...valueArgs([
          ["--title", args.title as string | undefined],
          ["--start", args.start as string | undefined],
          ["--end", args.end as string | undefined],
          ["--location", args.location as string | undefined],
          ["--notes", args.notes as string | undefined],
        ]),
        "--json",
      ];
      const result = await runEventCli(cliArgs);
      return { content: [{ type: "text", text: JSON.stringify(result) }] };
    }
    case "delete": {
      const cliArgs = [
        "calendar",
        "delete",
        "--id",
        String(args.id),
        ...valueArgs([["--span", args.span as string | undefined]]),
      ];
      const result = await runEventCliText(cliArgs);
      return { content: [{ type: "text", text: result }] };
    }
    default:
      return {
        content: [{ type: "text", text: `Unknown action for calendar_events: ${String(action)}` }],
        isError: true,
      };
  }
}
