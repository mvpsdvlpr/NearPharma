import fetch from 'node-fetch';

const UPSTASH_URL = process.env.UPSTASH_REDIS_REST_URL || process.env.UPSTASH_REDIS_REST_URL_HTTP || '';
const UPSTASH_TOKEN = process.env.UPSTASH_REDIS_REST_TOKEN || process.env.UPSTASH_REDIS_REST_TOKEN_HTTP || '';

function hasUpstash() {
  return !!(UPSTASH_URL && UPSTASH_TOKEN);
}

async function upstashFetch(path: string, opts: any = {}) {
  if (!hasUpstash()) throw new Error('Upstash not configured');
  const url = UPSTASH_URL.replace(/\/+$/, '') + '/' + path.replace(/^\/+/, '');
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${UPSTASH_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(opts.body || {})
  });
  if (!res.ok) throw new Error(`Upstash error ${res.status}`);
  return res.json();
}

export async function redisGet(key: string): Promise<string | null> {
  if (!hasUpstash()) return null;
  const path = `get/${encodeURIComponent(key)}`;
  const r = await upstashFetch(path);
  // Upstash returns {result: <value>} for REST GET
  if (r && 'result' in r) return r.result === null ? null : String(r.result);
  return null;
}

export async function redisSet(key: string, value: string, ttlSec?: number) {
  if (!hasUpstash()) return false;
  const path = `set/${encodeURIComponent(key)}`;
  const body: any = { value };
  if (ttlSec && ttlSec > 0) body['ex'] = ttlSec;
  const r = await upstashFetch(path, { body });
  return !!r;
}

export async function redisDel(key: string) {
  if (!hasUpstash()) return false;
  const path = `del/${encodeURIComponent(key)}`;
  const r = await upstashFetch(path);
  return !!r;
}

export async function redisGetJSON<T = any>(key: string): Promise<T | null> {
  const s = await redisGet(key);
  if (!s) return null;
  try { return JSON.parse(s) as T; } catch { return null; }
}

export async function redisSetJSON(key: string, value: any, ttlSec?: number) {
  const s = JSON.stringify(value);
  return redisSet(key, s, ttlSec);
}

export function isUpstashConfigured() {
  return hasUpstash();
}
