import { applyD1Migrations, env } from "cloudflare:test";

// Apply D1 migrations once before the test suite runs. Isolated storage
// then gives each test a fresh, already-migrated copy of the database.
await applyD1Migrations(env.DB, env.TEST_MIGRATIONS);
