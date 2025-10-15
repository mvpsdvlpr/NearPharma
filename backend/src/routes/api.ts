import express, { Request, Response, NextFunction, Router } from 'express';
import axios from 'axios';
import { query, validationResult } from 'express-validator';
import Cache from '../cache';

// Configuration and constants
const FARMANET_API_BASE = process.env.FARMANET_API_URL || 'https://seremienlinea.minsal.cl/asdigital/mfarmacias/mapa.php';
const FARMANET_TIMEOUT = Number(process.env.FARMANET_TIMEOUT_MS) || 7000;
const FARMANET_PREVIEW_LENGTH = 2000;

function getCommonHeaders() {
  return {
    'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.7258.66 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'es-CL,es;q=0.9,en;q=0.8',
    'Accept-Encoding': 'gzip, deflate, br',
    'Referer': 'https://seremienlinea.minsal.cl/'
  };
}

async function preflightGetCookies(apiBase: string, timeout = FARMANET_TIMEOUT): Promise<string> {
  try {
    const pre = await axios.get(apiBase, { headers: getCommonHeaders(), timeout });
    const setCookies = pre.headers && (pre.headers as any)['set-cookie'];
    if (Array.isArray(setCookies) && setCookies.length > 0) {
      return setCookies.map((c: string) => c.split(';')[0]).join('; ');
    }
  } catch (e) {
    // Not fatal; caller can try POST without cookies
    console.log('[API][preflight] GET failed:', String(e).slice(0, 200));
  }
  return '';
}

/**
 * Post to Farmanet and return parsed data when possible.
 * Always requests arraybuffer so we can safely detect HTML vs JSON.
 */
async function postToFarmanet(params: URLSearchParams, apiBase = FARMANET_API_BASE, cookieHeader = '', timeout = FARMANET_TIMEOUT) {
  const headers: Record<string, string> = { 'Content-Type': 'application/x-www-form-urlencoded', ...(getCommonHeaders() as any) };
  if (cookieHeader) headers.Cookie = cookieHeader;
  const response = await axios.post(apiBase, params, { headers, timeout, responseType: 'arraybuffer' });
  const buf = Buffer.from(response.data || '');
  const max = Math.min(buf.length, FARMANET_PREVIEW_LENGTH);
  // First try utf8
  let preview = buf.toString('utf8', 0, max);

  // Helper to attempt JSON parsing with some normalization strategies
  const tryParse = (s: string): any | null => {
    try {
      const p = JSON.parse(s);
      // If parsed value is a string that itself contains JSON, try parse inner JSON
      if (typeof p === 'string') {
        try {
          return JSON.parse(p);
        } catch (_) {
          return p;
        }
      }
      return p;
    } catch (e) {
      // try remove BOM and control chars
      try {
        const cleaned = s.replace(/^[\uFEFF\u200B]+/, '').replace(/[\x00-\x1F]+/g, '');
        const p2 = JSON.parse(cleaned);
        if (typeof p2 === 'string') {
          try { return JSON.parse(p2); } catch (_) { return p2; }
        }
        return p2;
      } catch (e2) {
        // attempt to extract a JSON substring (first {...} block)
        const m = s.match(/\{[\s\S]*\}/);
        if (m) {
          try {
            return JSON.parse(m[0]);
          } catch (e3) {
            // attempt to parse nested JSON (string containing JSON)
            const innerMatch = m[0].match(/"(\{[\s\S]*\})"/);
            if (innerMatch) {
              try {
                const inner = innerMatch[1].replace(/\\"/g, '"');
                const innerParsed = JSON.parse(inner);
                if (typeof innerParsed === 'string') {
                  try { return JSON.parse(innerParsed); } catch (_) { return innerParsed; }
                }
                return innerParsed;
              } catch (_) {
                return null;
              }
            }
            return null;
          }
        }
        return null;
      }
    }
  };

  // Try parsing utf8 preview
  // Normalize decimal commas used as decimal separators in some upstream responses
  const normalizeDecimalCommas = (s: string) =>
    s.replace(/"((?:lat|lng|local_lat|local_lng|lt|lg))"\s*:\s*"(-?\d+),(\d+)"/gi, (_m, key, a, b) => `"${key}":"${a}.${b}"`);

  // Also get full body as UTF8 string for broader parsing attempts
  const fullStr = buf.toString('utf8', 0, buf.length);

  // Try a set of parsing attempts in order to maximize chances of extracting JSON
  const attempts = [preview, fullStr, normalizeDecimalCommas(preview), normalizeDecimalCommas(fullStr)];
  let parsed: any | null = null;
  for (const attempt of attempts) {
    try {
      parsed = tryParse(attempt);
      if (parsed != null) {
        preview = attempt.slice(0, max);
        break;
      }
    } catch (_) {
      // ignore and continue
    }
  }
  // If not parsed, try latin1 decoding (some upstream responses may use legacy encodings)
  if (parsed == null) {
    try {
      const previewLatin1 = buf.toString('latin1', 0, max);
      parsed = tryParse(previewLatin1);
      if (parsed != null) preview = previewLatin1;
    } catch (_) {
      // ignore
    }
  }

  if (parsed != null) {
    return { status: response.status, headers: response.headers, data: parsed, preview, isJson: true };
  }

  // If we reach here parsing failed — add debug logs to help diagnose upstream content
  try {
    console.error('[API][postToFarmanet] failed to parse upstream response as JSON');
    console.error('[API][postToFarmanet] status=' + response.status + ' content-type=' + (response.headers && (response.headers as any)['content-type']));
    // print a longer preview (first 4000 chars) to help debugging
    const longPreview = fullStr.slice(0, Math.min(fullStr.length, 4000));
    console.error('[API][postToFarmanet] preview=' + longPreview);
  } catch (_) {}

  // As a last attempt, if the response body is itself a JSON string containing JSON
  // (e.g. "{\"correcto\":true,...}"), try to extract that.
  try {
    const asString = buf.toString('utf8', 0, buf.length);
    const unquoted = asString.match(/"\{[\s\S]*\}"/);
    if (unquoted) {
      const inner = unquoted[0].slice(1, -1).replace(/\\"/g, '"');
      const maybe = JSON.parse(inner);
      return { status: response.status, headers: response.headers, data: maybe, preview: inner.slice(0, FARMANET_PREVIEW_LENGTH), isJson: true };
    }
  } catch (_) {
    // ignore
  }

  // If it's not JSON, return raw preview and full buffer as fallback
  return { status: response.status, headers: response.headers, data: preview, preview, isJson: false };
}

// Handler para compatibilidad POST /mfarmacias/mapa.php
export async function handleFarmanetCompat(req: Request, res: Response) {
  const func = req.body.func || req.query.func;
  try {
    if (!func) return res.status(400).json({ correcto: false, error: 'Missing func parameter' });
    // Short-circuit for simple funcs that don't need cookie preflight in many cases
    if (func === 'iconos') {
      const params = new URLSearchParams({ func: 'iconos' });
      const resRaw = await axios.post(FARMANET_API_BASE, params, { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, timeout: FARMANET_TIMEOUT });
      const data = resRaw.data;
      if (data && (data as any).correcto === true && (data as any).respuesta) {
        return res.json(data);
      }
      return res.json({ correcto: true, respuesta: data });
    }

    // For other funcs, use preflight + unified post wrapper
    const apiBase = FARMANET_API_BASE;
    const cookieHeader = await preflightGetCookies(apiBase);
    const params = new URLSearchParams({ func: String(func) });
    // append additional params if provided
    const allowed = ['regiones', 'comunas', 'fechas', 'region', 'local', 'sector'];
    if (!allowed.includes(String(func))) return res.status(400).json({ correcto: false, error: 'Func no soportado' });
    // Map extra params
    if (func === 'comunas') {
      const region = req.body.region || req.query.region;
      if (region) params.append('region', String(region));
    }
    if (func === 'region') {
      const region = req.body.region || req.query.region || '';
      const filtro = req.body.filtro || req.query.filtro;
      const fecha = req.body.fecha || req.query.fecha;
      const hora = req.body.hora || req.query.hora;
      params.set('region', String(region));
      if (filtro) params.append('filtro', String(filtro));
      if (fecha) params.append('fecha', String(fecha));
      if (hora) params.append('hora', String(hora));
    }
    if (func === 'local') {
      const im = req.body.im || req.query.im || '';
      const fecha = req.body.fecha || req.query.fecha;
      params.set('im', String(im));
      if (fecha) params.append('fecha', String(fecha));
    }

    const result = await postToFarmanet(params, apiBase, cookieHeader);
    // If Farmanet returned JSON, return it; otherwise return a helpful error with preview
    if (result.isJson) return res.json(result.data);
    return res.status(502).json({ correcto: false, error: 'Upstream returned non-JSON response', preview: String(result.preview).slice(0, 1000) });
  } catch (err) {
    return res.status(500).json({ correcto: false, error: String(err) });
  }
}


// Permite inyectar cache para testing
export function createApiRouter(cacheInstance?: Cache<any>): Router {
  const router = express.Router();
  const cache = cacheInstance || new Cache<any>();
  const CACHE_TTL = 60 * 1000; // 1 minute


  // GET /api/regions
  router.get('/regions', async (req: Request, res: Response) => {
    console.log('[API] GET /api/regions');
    try {
      const apiBase = FARMANET_API_BASE;
      const cookieHeader = await preflightGetCookies(apiBase);
  const params = new URLSearchParams({ func: 'regiones' });
      const response = await postToFarmanet(params, apiBase, cookieHeader);
      console.log(`[API][regions] farmanet status=${response.status}`);
      const data = response.data;
      const regiones = Array.isArray(data)
        ? data.map((item: any) => ({ id: item.region_id, nombre: item.region_nombre }))
        : [];
      res.json(regiones);
    } catch (err) {
      console.error('[API][regions] Error general:', err);
      res.status(500).json({ error: 'Error al obtener regiones', details: String(err) });
    }
  });

  // GET /api/communes?region=ID
  router.get('/communes', [
    query('region').isInt({ min: 1, max: 16 }).withMessage('Invalid region')
  ], async (req: Request, res: Response) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    const regionId = req.query.region;
    console.log(`[API] GET /api/communes?region=${regionId}`);
    try {
      const apiBase = FARMANET_API_BASE;
  const params = new URLSearchParams({ func: 'comunas', region: String(regionId) });
      const cookieHeader = await preflightGetCookies(apiBase);
      const response = await postToFarmanet(params, apiBase, cookieHeader);
      console.log(`[API][communes] farmanet status=${response.status} region=${regionId}`);
      const data = response.data;
      const comunas = Array.isArray(data)
        ? data.map((item: any) => ({ id: String(item.comuna_nombre).toLowerCase().replace(/ /g, '-'), nombre: item.comuna_nombre }))
        : [];
      res.json(comunas);
    } catch (err) {
      console.error(`[API][communes] Error para region ${regionId}:`, err);
      res.status(500).json({ error: 'Error al obtener comunas', details: String(err) });
    }
  });

  // Haversine distance in km
  function distance(lat1: number, lng1: number, lat2: number, lng2: number): number {
    if ([lat1, lng1, lat2, lng2].some(v => isNaN(v))) return Number.POSITIVE_INFINITY;
    const R = 6371;
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLng = (lng2 - lng1) * Math.PI / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLng / 2) * Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  // GET /api/pharmacies?region=...&comuna=...&tipo=...
  router.get('/pharmacies',
    [
      query('region').isInt({ min: 1, max: 16 }).withMessage('Invalid region'),
      query('comuna').optional().isString().trim().escape(),
      query('tipo').optional().isString().trim().escape(),
      query('lat').optional().isFloat({ min: -90, max: 90 }).toFloat(),
      query('lng').optional().isFloat({ min: -180, max: 180 }).toFloat(),
    ],
  async (req: Request, res: Response, next: NextFunction) => {
      try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
          return res.status(400).json({ errors: errors.array() });
        }
        const { region, comuna, tipo, lat, lng } = req.query as any;
        const cacheKey = `pharmacies:${region}:${comuna || ''}:${tipo || ''}`;
        let result;
        const cached = await cache.get(cacheKey);
        if (cached) {
          result = cached;
        } else {
          try {
            const apiBase = FARMANET_API_BASE;
            // Use permitted 'region' func (allowed list: regiones, comunas, fechas, region, local, sector)
            // 'locales_farmacias' is not a valid func for Farmanet and will not work.
            const params = new URLSearchParams({ func: 'region', region: String(region) });
            const cookieHeader = await preflightGetCookies(apiBase);
            const response = await postToFarmanet(params, apiBase, cookieHeader);
            let data = response.data;
            // Log a short preview for debugging
            try {
              const preview = typeof data === 'string' ? data.slice(0, 1000) : JSON.stringify(Array.isArray(data) ? data.slice(0, 10) : data).slice(0, 1000);
              console.log('[API][pharmacies] farmanet status=' + response.status + ' preview=' + preview);
            } catch (e) {
              console.log('[API][pharmacies] farmanet status=' + response.status + ' (could not stringify preview)');
            }
            // Farmanet responses vary. Prefer data.respuesta.locales, then data.respuesta if it's an array, then data itself if it's an array.
            try {
              if (data && typeof data === 'object') {
                if ((data as any).respuesta && Array.isArray((data as any).respuesta.locales)) {
                  data = (data as any).respuesta.locales;
                } else if ((data as any).respuesta && Array.isArray((data as any).respuesta)) {
                  console.log('[API][pharmacies] Using data.respuesta as fallback (array)');
                  data = (data as any).respuesta;
                } else if (Array.isArray(data)) {
                  console.log('[API][pharmacies] Using top-level data array');
                  // keep data as-is
                } else if ((data as any).respuesta && (data as any).respuesta.locales && Array.isArray((data as any).respuesta.locales) === false) {
                  // respuesta exists but not locales array — leave data as-is and let downstream handle emptiness
                }
              }
            } catch (e) {
              console.error('[API][pharmacies] error normalizing farmanet response', e);
            }
            if (!Array.isArray(data)) {
              console.error('[API][pharmacies] La respuesta NO es un array:', data);
              return res.status(502).json({ error: 'Invalid data from API', preview: String(response.preview).slice(0, 1000) });
            }
            result = data;
            if (comuna) {
              result = result.filter((item: any) => item.comuna_nombre?.toLowerCase() === String(comuna).toLowerCase());
            }
            if (tipo) {
              result = result.filter((item: any) => item.local_tipo?.toLowerCase() === String(tipo).toLowerCase());
            }
            if (Array.isArray(result) && result.length > 0) {
              await cache.set(cacheKey, result, CACHE_TTL);
            }
          } catch (err) {
            console.error('[API][pharmacies] Error al consultar Farmanet:', err);
            return res.status(500).json({ error: 'External API error' });
          }
        }
        if (lat !== undefined && lng !== undefined && !isNaN(Number(lat)) && !isNaN(Number(lng))) {
          const userLat = Number(lat);
          const userLng = Number(lng);
          // Helper to parse coordinates robustly: accepts strings with comma decimals, extra chars, etc.
          const parseCoord = (v: any): number => {
            if (v === null || v === undefined) return NaN;
            // keep sign, digits, dot/comma; change comma to dot
            const s = String(v).trim().replace(',', '.').match(/-?[0-9]+(?:\.[0-9]+)?/);
            if (!s) return NaN;
            const n = parseFloat(s[0]);
            return isNaN(n) ? NaN : n;
          };

          // Validate coordinates and filter pharmacies within bounds
          const bounds = {
            latMin: userLat - 0.1, // Example bounds, adjust as needed
            latMax: userLat + 0.1,
            lngMin: userLng - 0.1,
            lngMax: userLng + 0.1,
          };

          result = result.filter((item: any) => {
            const lat = parseCoord(item.lt);
            const lng = parseCoord(item.lg);
            return !isNaN(lat) && !isNaN(lng);
          });

          // Debugging: Log distances for pharmacies
          console.log('[DEBUG] User coordinates:', { userLat, userLng });
          result.forEach((item: any) => {
            const lat = parseCoord(item.lt);
            const lng = parseCoord(item.lg);
            const dist = distance(userLat, userLng, lat, lng);
            console.log('[DEBUG] Pharmacy:', {
              id: item.im,
              name: item.nm,
              lat,
              lng,
              distance: dist,
            });
          });

          // Sort pharmacies by distance
          result = result.slice().sort((a: any, b: any) => {
            const aLat = parseCoord(a.lt);
            const aLng = parseCoord(a.lg);
            const bLat = parseCoord(b.lt);
            const bLng = parseCoord(b.lg);
            const dA = distance(userLat, userLng, aLat, aLng);
            const dB = distance(userLat, userLng, bLat, bLng);
            return dA - dB;
          });
        }
        res.json(Array.isArray(result) ? result : []);
      } catch (err) {
        next(err);
      }
    }
  );

  // DEBUG: GET preflight + POST to Farmanet and return raw preview
  const _allowDebug = (process.env.NODE_ENV || '').toLowerCase() !== 'production' || process.env.ALLOW_DEBUG === 'true';
  if (_allowDebug) {
    router.get('/debug/farmanet', async (req: Request, res: Response) => {
      const func = String(req.query.func || 'regiones');
      const region = req.query.region as string | undefined;
      const apiBase = FARMANET_API_BASE;
      try {
        const cookieHeader = await preflightGetCookies(apiBase, 8000);
        const params = new URLSearchParams({ func });
        if (region) params.append('region', region);
        const response = await postToFarmanet(params, apiBase, cookieHeader, 10000);
        return res.json({ ok: true, status: response.status, headers: response.headers, preview: String(response.preview).slice(0, 2000), isJson: response.isJson });
      } catch (err) {
        return res.status(500).json({ ok: false, error: String(err).slice(0, 1000) });
      }
    });
    // Simple health endpoint for debugging mounting/routing
    router.get('/debug/ping', (req: Request, res: Response) => {
      res.json({ ok: true, now: new Date().toISOString(), env: process.env.NODE_ENV || 'dev' });
    });
  } // end _allowDebug
  // Exponer el cache para testing
  (router as any)._cache = cache;
  return router;
}

// Para uso normal (no testing)
const defaultRouter = createApiRouter();
export default defaultRouter;
