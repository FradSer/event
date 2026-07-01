import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  type CallToolResult,
  type Tool,
} from "@modelcontextprotocol/sdk/types.js";
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

export function createServer(): Server {
  const server = new Server(
    { name: "event-mcp-server", version: "0.1.0" },
    { capabilities: { tools: {} } },
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const handler = resolveHandler(request.params.name);
    if (!handler) {
      return {
        content: [{ type: "text", text: `Unknown tool: ${request.params.name}` }],
        isError: true,
      };
    }
    return handler((request.params.arguments as Record<string, unknown>) ?? {});
  });

  return server;
}
