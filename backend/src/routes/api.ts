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
  const preview = buf.toString('utf8', 0, Math.min(buf.length, FARMANET_PREVIEW_LENGTH));
  // Try parse JSON safely
  try {
    const parsed = JSON.parse(preview);
    return { status: response.status, headers: response.headers, data: parsed, preview, isJson: true };
  } catch (_) {
    // If it's not JSON, return raw preview and full buffer as fallback
    return { status: response.status, headers: response.headers, data: preview, preview, isJson: false };
  }
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
      const params = new URLSearchParams({ func: 'locales_regiones' });
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
      const params = new URLSearchParams({ func: 'locales_comunas', region: String(regionId) });
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
        const cached = cache.get(cacheKey);
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
            // Farmanet may return an envelope like { correcto: true, respuesta: { locales: [...] } }
            if (data && typeof data === 'object' && (data as any).respuesta && Array.isArray((data as any).respuesta.locales)) {
              data = (data as any).respuesta.locales;
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
              cache.set(cacheKey, result, CACHE_TTL);
            }
          } catch (err) {
            console.error('[API][pharmacies] Error al consultar Farmanet:', err);
            return res.status(500).json({ error: 'External API error' });
          }
        }
        if (lat !== undefined && lng !== undefined && !isNaN(Number(lat)) && !isNaN(Number(lng))) {
          const userLat = Number(lat);
          const userLng = Number(lng);
          result = result.slice().sort((a: any, b: any) => {
            const dA = distance(userLat, userLng, parseFloat(a.local_lat || a.lat || a.lt), parseFloat(a.local_lng || a.lng || a.lg));
            const dB = distance(userLat, userLng, parseFloat(b.local_lat || b.lat || b.lt), parseFloat(b.local_lng || b.lng || b.lg));
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
      const func = String(req.query.func || 'locales_regiones');
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
