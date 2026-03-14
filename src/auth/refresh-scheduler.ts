/**
 * RefreshScheduler — per-account JWT auto-refresh.
 * Schedules a refresh at `exp - margin` for each account.
 * Uses OAuth refresh_token instead of Codex CLI.
 *
 * Features:
 * - Exponential backoff (5 attempts: 5s → 15s → 45s → 135s → 300s)
 * - Permanent failure detection (invalid_grant / invalid_token)
 * - Recovery scheduling (10 min) for temporary failures
 * - Crash recovery: "refreshing" → immediate retry, "expired" + refreshToken → delayed retry
 */

import { getConfig } from "../config.js";
import { decodeJwtPayload } from "./jwt-utils.js";
import { refreshAccessToken } from "./oauth-pkce.js";
import { jitter, jitterInt } from "../utils/jitter.js";
import type { AccountPool } from "./account-pool.js";

/** Errors that indicate the refresh token itself is invalid (permanent failure). */
const PERMANENT_ERRORS = ["invalid_grant", "invalid_token", "access_denied"];

/** HTTP status codes that indicate permanent refresh failure. */
const PERMANENT_STATUS_CODES = [302, 401, 403];

const MAX_ATTEMPTS = 5;
const BASE_DELAY_MS = 5_000;
const RECOVERY_DELAY_MS = 10 * 60 * 1000; // 10 minutes

export class RefreshScheduler {
  private timers: Map<string, ReturnType<typeof setTimeout>> = new Map();
  private pool: AccountPool;

  constructor(pool: AccountPool) {
    this.pool = pool;
    this.scheduleAll();
  }

  /** Schedule refresh for all accounts in the pool. */
  scheduleAll(): void {
    for (const entry of this.pool.getAllEntries()) {
      if (entry.status === "active") {
        this.scheduleOne(entry.id, entry.token);
      } else if (entry.status === "refreshing") {
        // Crash recovery: was mid-refresh when process died
        console.log(`[RefreshScheduler] Account ${entry.id}: recovering from 'refreshing' state`);
        this.doRefresh(entry.id);
      } else if (entry.status === "expired" && entry.refreshToken) {
        // Attempt recovery for expired accounts that still have a refresh token
        const delay = jitterInt(30_000, 0.3);
        console.log(`[RefreshScheduler] Account ${entry.id}: expired with refresh_token, recovery attempt in ${Math.round(delay / 1000)}s`);
        const timer = setTimeout(() => {
          this.timers.delete(entry.id);
          this.doRefresh(entry.id);
        }, delay);
        if (timer.unref) timer.unref();
        this.timers.set(entry.id, timer);
      } else if (entry.status === "expired" && !entry.refreshToken) {
        const email = entry.email ?? entry.id;
        console.warn(`[RefreshScheduler] Account ${email}: expired with no refresh_token`);
        console.log(`[RefreshScheduler] Auto-removing expired account ${email} (no refresh token available)`);
        this.pool.removeAccount(entry.id);
      }
    }
  }

  /** Schedule refresh for a single account. */
  scheduleOne(entryId: string, token: string): void {
    // Clear existing timer
    this.clearOne(entryId);

    const payload = decodeJwtPayload(token);
    if (!payload || typeof payload.exp !== "number") return;

    const config = getConfig();
    const refreshAt = payload.exp - jitter(config.auth.refresh_margin_seconds, 0.15);
    const delayMs = (refreshAt - Math.floor(Date.now() / 1000)) * 1000;

    if (delayMs <= 0) {
      // Already past refresh time — attempt refresh immediately
      this.doRefresh(entryId);
      return;
    }

    const timer = setTimeout(() => {
      this.timers.delete(entryId);
      this.doRefresh(entryId);
    }, delayMs);

    // Prevent the timer from keeping the process alive
    if (timer.unref) timer.unref();

    this.timers.set(entryId, timer);

    const expiresIn = Math.round(delayMs / 1000);
    console.log(
      `[RefreshScheduler] Account ${entryId}: refresh scheduled in ${expiresIn}s`,
    );
  }

  /** Cancel timer for one account. */
  clearOne(entryId: string): void {
    const timer = this.timers.get(entryId);
    if (timer) {
      clearTimeout(timer);
      this.timers.delete(entryId);
    }
  }

  /** Cancel all timers. */
  destroy(): void {
    for (const timer of this.timers.values()) {
      clearTimeout(timer);
    }
    this.timers.clear();
  }

  // ── Internal ────────────────────────────────────────────────────

  private async doRefresh(entryId: string): Promise<void> {
    const entry = this.pool.getEntry(entryId);
    if (!entry) return;

    if (!entry.refreshToken) {
      const email = entry.email ?? entryId;
      console.warn(
        `[RefreshScheduler] Account ${email} has no refresh_token, cannot auto-refresh`,
      );
      console.log(`[RefreshScheduler] Auto-removing expired account ${email} (no refresh token available)`);
      this.pool.removeAccount(entryId);
      return;
    }

    console.log(`[RefreshScheduler] Refreshing account ${entryId} (${entry.email ?? "?"})`);
    this.pool.markStatus(entryId, "refreshing");

    for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
      try {
        const tokens = await refreshAccessToken(entry.refreshToken);
        // Update token and refresh_token (if a new one was issued)
        this.pool.updateToken(
          entryId,
          tokens.access_token,
          tokens.refresh_token,
        );
        console.log(`[RefreshScheduler] Account ${entryId} refreshed successfully`);
        this.scheduleOne(entryId, tokens.access_token);
        return;
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);

        // Check for permanent failures by error message
        if (PERMANENT_ERRORS.some((e) => msg.toLowerCase().includes(e))) {
          const entry = this.pool.getEntry(entryId);
          const email = entry?.email ?? entryId;
          console.error(`[RefreshScheduler] Permanent failure for ${email}: ${msg}`);
          console.log(`[RefreshScheduler] Auto-removing account ${email} due to permanent refresh failure`);
          this.pool.removeAccount(entryId);
          return;
        }

        // Check for permanent failures by HTTP status code (302, 401, 403)
        // Error format: "Token refresh failed (302): ..."
        const statusMatch = msg.match(/Token refresh failed \((\d+)\)/);
        if (statusMatch) {
          const statusCode = parseInt(statusMatch[1], 10);
          if (PERMANENT_STATUS_CODES.includes(statusCode)) {
            const entry = this.pool.getEntry(entryId);
            const email = entry?.email ?? entryId;
            console.error(`[RefreshScheduler] Permanent failure (HTTP ${statusCode}) for ${email}: ${msg}`);
            console.log(`[RefreshScheduler] Auto-removing account ${email} due to refresh failure`);
            this.pool.removeAccount(entryId);
            return;
          }
        }

        if (attempt < MAX_ATTEMPTS) {
          // Exponential backoff: 5s, 15s, 45s, 135s, 300s (capped)
          const backoff = Math.min(BASE_DELAY_MS * Math.pow(3, attempt - 1), 300_000);
          const retryDelay = jitterInt(backoff, 0.3);
          console.warn(
            `[RefreshScheduler] Attempt ${attempt}/${MAX_ATTEMPTS} failed for ${entryId}: ${msg}, retrying in ${Math.round(retryDelay / 1000)}s...`,
          );
          await new Promise((r) => setTimeout(r, retryDelay));
        } else {
          console.error(
            `[RefreshScheduler] All ${MAX_ATTEMPTS} attempts failed for ${entryId}: ${msg}`,
          );
          // Don't mark expired — schedule recovery attempt in 10 minutes
          this.pool.markStatus(entryId, "active"); // keep active so it can still be used
          this.scheduleRecovery(entryId);
        }
      }
    }
  }

  /**
   * Schedule a recovery refresh attempt after all retries are exhausted.
   * Gives the server time to recover from temporary issues.
   */
  private scheduleRecovery(entryId: string): void {
    const delay = jitterInt(RECOVERY_DELAY_MS, 0.2);
    console.log(
      `[RefreshScheduler] Recovery attempt for ${entryId} in ${Math.round(delay / 60000)}m`,
    );
    const timer = setTimeout(() => {
      this.timers.delete(entryId);
      this.doRefresh(entryId);
    }, delay);
    if (timer.unref) timer.unref();
    this.timers.set(entryId, timer);
  }
}
