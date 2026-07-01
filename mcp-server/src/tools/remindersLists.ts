import type { CallToolResult, Tool } from "@modelcontextprotocol/sdk/types.js";
import { runEventCli, runEventCliText } from "../eventCli.js";

export const remindersListsTool: Tool = {
  name: "reminders_lists",
  description: "Manage Apple Reminders lists. Actions: list, create, update, delete.",
  inputSchema: {
    type: "object",
    properties: {
      action: {
        type: "string",
        enum: ["list", "create", "update", "delete"],
        description: "The operation to perform.",
      },
      id: { type: "string", description: "List ID (required for update, delete)." },
      name: { type: "string", description: "List name (required for create, update)." },
    },
    required: ["action"],
  },
};

export async function handleRemindersLists(args: Record<string, unknown>): Promise<CallToolResult> {
  const action = args.action as string;

  switch (action) {
    case "list": {
      const result = await runEventCli(["reminders", "lists", "list", "--json"]);
      return { content: [{ type: "text", text: JSON.stringify(result) }] };
    }
    case "create": {
      const result = await runEventCli([
        "reminders",
        "lists",
        "create",
        "--name",
        String(args.name),
        "--json",
      ]);
      return { content: [{ type: "text", text: JSON.stringify(result) }] };
    }
    case "update": {
      const result = await runEventCli([
        "reminders",
        "lists",
        "update",
        "--id",
        String(args.id),
        "--name",
        String(args.name),
        "--json",
      ]);
      return { content: [{ type: "text", text: JSON.stringify(result) }] };
    }
    case "delete": {
      const result = await runEventCliText(["reminders", "lists", "delete", "--id", String(args.id)]);
      return { content: [{ type: "text", text: result }] };
    }
    default:
      return {
        content: [{ type: "text", text: `Unknown action for reminders_lists: ${String(action)}` }],
        isError: true,
      };
  }
}
