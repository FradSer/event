/// <reference types="@cloudflare/vitest-pool-workers/types" />
import type { D1Migration } from "@cloudflare/vitest-pool-workers";

declare global {
  namespace Cloudflare {
    interface Env {
      DB: D1Database;
      API_TOKEN: string;
      TEST_MIGRATIONS: D1Migration[];
    }
  }
}
