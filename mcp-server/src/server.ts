import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  type CallToolResult,
  type Tool,
} from "@modelcontextprotocol/sdk/types.js";
import { EventCliError } from "./eventCli.js";
import { calendarEventsTool, handleCalendarEvents } from "./tools/calendarEvents.js";
import { remindersListsTool, handleRemindersLists } from "./tools/remindersLists.js";
import { remindersTasksTool, handleRemindersTasks } from "./tools/remindersTasks.js";

export const TOOLS: Tool[] = [remindersTasksTool, remindersListsTool, calendarEventsTool];

type ToolHandler = (args: Record<string, unknown>) => Promise<CallToolResult>;

const HANDLERS: Record<string, ToolHandler> = {
  reminders_tasks: handleRemindersTasks,
  reminders_lists: handleRemindersLists,
  calendar_events: handleCalendarEvents,
};

export function resolveHandler(toolName: string): ToolHandler | undefined {
  return HANDLERS[toolName];
}

// The low-level Server API does not auto-catch handler throws, so we dispatch
// through this wrapper to turn thrown errors (in particular EventCliError, whose
// captured stderr would otherwise be lost) into clean isError:true tool results
// instead of raw JSON-RPC protocol errors.
export async function dispatchToolCall(
  name: string,
  args: Record<string, unknown>,
): Promise<CallToolResult> {
  const handler = resolveHandler(name);
  if (!handler) {
    return {
      content: [{ type: "text", text: `Unknown tool: ${name}` }],
      isError: true,
    };
  }
  try {
    return await handler(args);
  } catch (error) {
    const message =
      error instanceof EventCliError
        ? error.stderr || error.message
        : error instanceof Error
          ? error.message
          : String(error);
    return { content: [{ type: "text", text: message }], isError: true };
  }
}

export function createServer(): Server {
  const server = new Server(
    { name: "event-mcp-server", version: "0.1.0" },
    { capabilities: { tools: {} } },
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

  server.setRequestHandler(CallToolRequestSchema, async (request) =>
    dispatchToolCall(request.params.name, (request.params.arguments as Record<string, unknown>) ?? {}),
  );

  return server;
}
