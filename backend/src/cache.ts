// Simple in-memory cache with TTL
export interface CacheEntry<T> {
  value: T;
  expires: number;
}

class Cache<T> {
  private store = new Map<string, CacheEntry<T>>();

  set(key: string, value: T, ttlMs: number) {
    const expires = Date.now() + ttlMs;
    this.store.set(key, { value, expires });
  }

  get(key: string): T | undefined {
    const entry = this.store.get(key);
    if (!entry) return undefined;
    if (Date.now() > entry.expires) {
      this.store.delete(key);
      return undefined;
    }
    return entry.value;
  }

  delete(key: string) {
    this.store.delete(key);
  }

  clear() {
    this.store.clear();
  }
}

export default Cache;
