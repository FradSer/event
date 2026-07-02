import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export class EventCliError extends Error {
  readonly stderr: string;
  readonly exitCode: number | null;

  constructor(message: string, stderr: string, exitCode: number | null) {
    super(message);
    this.name = "EventCliError";
    this.stderr = stderr;
    this.exitCode = exitCode;
  }
}

export function eventBinPath(): string {
  return process.env.EVENT_BIN ?? "event";
}

async function execEventCli(args: string[]): Promise<string> {
  try {
    const { stdout } = await execFileAsync(eventBinPath(), args, {
      maxBuffer: 10 * 1024 * 1024,
    });
    return stdout.trim();
  } catch (error) {
    const execError = error as { code?: number | null; stderr?: string; message: string };
    throw new EventCliError(
      `event CLI failed: ${execError.message}`,
      execError.stderr ?? "",
      execError.code ?? null,
    );
  }
}

export async function runEventCli(args: string[]): Promise<unknown> {
  const output = await execEventCli(args);
  if (output.length === 0) {
    return null;
  }
  // The event CLI may print a "Note: ..." warning (e.g. missing AdvancedReminderEdit
  // Shortcut) to stdout before its JSON payload. Skip any such preamble and parse
  // starting at the first JSON token.
  const jsonStart = output.search(/[[{]/);
  if (jsonStart === -1) {
    throw new EventCliError(`event CLI produced no JSON output: ${output}`, "", null);
  }
  return JSON.parse(output.slice(jsonStart));
}

export async function runEventCliText(args: string[]): Promise<string> {
  return execEventCli(args);
}

export function valueArgs(
  entries: Array<[string, string | number | undefined]>,
): string[] {
  const args: string[] = [];
  for (const [flag, value] of entries) {
    if (value === undefined) continue;
    args.push(flag, String(value));
  }
  return args;
}

export function flagArgs(entries: Array<[string, boolean | undefined]>): string[] {
  const args: string[] = [];
  for (const [flag, present] of entries) {
    if (present) args.push(flag);
  }
  return args;
}
