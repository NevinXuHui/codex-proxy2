/**
 * Auto-import accounts from token directory on startup.
 */

import { readdirSync, readFileSync, existsSync } from "fs";
import { resolve, join } from "path";
import { getRootDir } from "../paths.js";
import type { AccountPool } from "./account-pool.js";
import type { RefreshScheduler } from "./refresh-scheduler.js";

interface TokenFile {
  type: string;
  email: string;
  expired: string;
  id_token: string;
  account_id: string;
  access_token: string;
  last_refresh: string;
  refresh_token: string;
}

/**
 * Import accounts from token directory.
 * @param pool - AccountPool instance
 * @param scheduler - RefreshScheduler instance
 * @returns Number of accounts imported
 */
export function importTokens(pool: AccountPool, scheduler: RefreshScheduler): number {
  const tokenDir = resolve(getRootDir(), "token");

  if (!existsSync(tokenDir)) {
    console.log("[TokenImporter] Token directory not found, skipping auto-import");
    return 0;
  }

  let imported = 0;
  try {
    const files = readdirSync(tokenDir).filter(f => f.endsWith(".json"));

    for (const file of files) {
      try {
        const filePath = join(tokenDir, file);
        const content = readFileSync(filePath, "utf-8");
        const data = JSON.parse(content) as TokenFile;

        if (!data.access_token) {
          console.warn(`[TokenImporter] Skipping ${file}: missing access_token`);
          continue;
        }

        // Add account with access_token and refresh_token
        const entryId = pool.addAccount(data.access_token, data.refresh_token || null);
        scheduler.scheduleOne(entryId, data.access_token);
        console.log(`[TokenImporter] Imported account from ${file} (entryId: ${entryId})`);
        imported++;
      } catch (err) {
        console.error(`[TokenImporter] Failed to import ${file}:`, err instanceof Error ? err.message : err);
      }
    }

    if (imported > 0) {
      console.log(`[TokenImporter] Successfully imported ${imported} account(s) from token directory`);
    }
  } catch (err) {
    console.error("[TokenImporter] Failed to read token directory:", err instanceof Error ? err.message : err);
  }

  return imported;
}
