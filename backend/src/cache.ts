// Simple in-memory cache with TTL
export interface CacheEntry<T> {
  value: T;
  expires: number;
}

import { isUpstashConfigured, redisGetJSON, redisSetJSON, redisDel } from './lib/redis';

class Cache<T> {
  private store = new Map<string, CacheEntry<T>>();
  private hits = 0;
  private misses = 0;

  // set supports ttl in milliseconds (for in-memory) and seconds for Redis
  async set(key: string, value: T, ttlMs: number) {
    const expires = Date.now() + ttlMs;
    // local memo
    this.store.set(key, { value, expires });
    // remote cache if configured (Upstash expects seconds)
    if (isUpstashConfigured()) {
      const ttlSec = Math.round(ttlMs / 1000);
      try { await redisSetJSON(key, value, ttlSec); } catch (e) { /* swallow */ }
    }
  }

  async get(key: string): Promise<T | undefined> {
    // check local first
    const entry = this.store.get(key);
    if (entry && Date.now() <= entry.expires) {
      // record a hit for observability
      this.hits++;
      return entry.value;
    }
    // local miss
    this.misses++;
    // if upstash configured, try remote
    if (isUpstashConfigured()) {
      try {
        const remote = await redisGetJSON<T>(key);
        if (remote !== null) return remote;
      } catch (e) { /* swallow */ }
    }
    // fallback undefined
    return undefined;
    // ultimate miss
    return undefined;
  }

  async delete(key: string) {
    this.store.delete(key);
    if (isUpstashConfigured()) {
      try { await redisDel(key); } catch (e) { /* swallow */ }
    }
  }

  getMetrics() {
    return { hits: this.hits, misses: this.misses };
  }

  clear() {
    this.store.clear();
  }
}

export default Cache;
