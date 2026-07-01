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
    const { stdout } = await execFileAsync(eventBinPath(), args);
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
  return JSON.parse(output);
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
