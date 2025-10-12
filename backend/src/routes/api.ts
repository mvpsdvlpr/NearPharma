// Handler para compatibilidad POST /mfarmacias/mapa.php
export async function handleMapaPhpCompat(req: Request, res: Response) {
  const func = req.body.func || req.query.func;
  const API_BASE = process.env.FARMANET_API_URL || 'https://seremienlinea.minsal.cl/asdigital/mfarmacias/mapa.php';
  try {
    if (func === 'iconos') {
      // Obtener respuesta real desde la API oficial
      const response = await axios.post(API_BASE, new URLSearchParams({ func: 'iconos' }), {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
      });
      // Farmanet responde { correcto: true, respuesta: { ... } }
      if (response.data && response.data.correcto === true && response.data.respuesta) {
        return res.json(response.data);
      }
      // Si la API responde plano, envolver en la estructura correcta
      return res.json({ correcto: true, respuesta: response.data });
    }
    if (func === 'regiones') {
      const response = await axios.post(API_BASE, new URLSearchParams({ func: 'regiones' }), {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
      });
      return res.json(response.data);
    }
    if (func === 'comunas') {
      const region = req.body.region || req.query.region;
      const params = new URLSearchParams({ func: 'comunas' });
      if (region) params.append('region', region);
      const response = await axios.post(API_BASE, params, {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
      });
      return res.json(response.data);
    }
    if (func === 'fechas') {
      const response = await axios.post(API_BASE, new URLSearchParams({ func: 'fechas' }), {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
      });
      return res.json(response.data);
    }
    if (func === 'region') {
      const region = req.body.region || req.query.region;
      const filtro = req.body.filtro || req.query.filtro;
      const fecha = req.body.fecha || req.query.fecha;
      const hora = req.body.hora || req.query.hora;
      const params = new URLSearchParams({ func: 'region', region: region || '' });
      if (filtro) params.append('filtro', filtro);
      if (fecha) params.append('fecha', fecha);
      if (hora) params.append('hora', hora);
      const response = await axios.post(API_BASE, params, {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
      });
      return res.json(response.data);
    }
    if (func === 'local') {
      const im = req.body.im || req.query.im;
      const fecha = req.body.fecha || req.query.fecha;
      const params = new URLSearchParams({ func: 'local', im: im || '' });
      if (fecha) params.append('fecha', fecha);
      const response = await axios.post(API_BASE, params, {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
      });
      return res.json(response.data);
    }
    if (func === 'sector') {
      // Simular sector (no implementado)
      return res.json({ correcto: true, respuesta: { locales: [] } });
    }
    return res.status(400).json({ correcto: false, error: 'Func no soportado' });
  } catch (err) {
    return res.status(500).json({ correcto: false, error: String(err) });
  }
}


import express, { Request, Response, NextFunction, Router } from 'express';
import axios from 'axios';
import { query, validationResult } from 'express-validator';
import Cache from '../cache';

// Permite inyectar cache para testing
export function createApiRouter(cacheInstance?: Cache<any>): Router {
  const router = express.Router();
  const cache = cacheInstance || new Cache<any>();
  const CACHE_TTL = 60 * 1000; // 1 minute


  // GET /api/regions
  router.get('/regions', async (req: Request, res: Response) => {
    console.log('[API] GET /api/regions');
    try {
      const commonHeaders = {
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.7258.66 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'es-CL,es;q=0.9,en;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'Referer': 'https://seremienlinea.minsal.cl/'
      };
      const API_BASE = process.env.FARMANET_API_URL || 'https://seremienlinea.minsal.cl/asdigital/mfarmacias/mapa.php';
      // La API oficial responde mejor a POST form-encoded; usar POST para compatibilidad
      // Cloudflare/remote site may require cookies; do a preflight GET and forward Set-Cookie as Cookie
      let cookieHeader = '';
      try {
        const commonHeaders = {
          'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.7258.66 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'es-CL,es;q=0.9,en;q=0.8',
          'Accept-Encoding': 'gzip, deflate, br',
          'Referer': 'https://seremienlinea.minsal.cl/'
        };
        const pre = await axios.get(API_BASE, { headers: commonHeaders, timeout: 7000 });
        const setCookies = pre.headers && pre.headers['set-cookie'];
        if (Array.isArray(setCookies) && setCookies.length > 0) {
          cookieHeader = setCookies.map((c: string) => c.split(';')[0]).join('; ');
        }
      } catch (e) {
        console.log('[API][regions] preflight GET failed:', String(e).slice(0, 200));
      }
      const params = new URLSearchParams({ func: 'locales_regiones' });
  const response = await axios.post(API_BASE, params, { headers: { 'Content-Type': 'application/x-www-form-urlencoded', ...(commonHeaders as any), ...(cookieHeader ? { Cookie: cookieHeader } : {}) }, timeout: 7000 });
      // Mejor logging para diagnóstico remoto
      console.log(`[API][regions] farmanet status=${response.status}`);
      const data = response.data;
      // Se espera un array de regiones
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
    const commonHeaders = {
      'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.7258.66 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      'Accept-Language': 'es-CL,es;q=0.9,en;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Referer': 'https://seremienlinea.minsal.cl/'
    };
    console.log(`[API] GET /api/communes?region=${regionId}`);
  try {
  const API_BASE = process.env.FARMANET_API_URL || 'https://seremienlinea.minsal.cl/asdigital/mfarmacias/mapa.php';
  // Usar POST form-encoded para locales_comunas
  const params = new URLSearchParams({ func: 'locales_comunas', region: String(regionId) });
      let cookieHeader = '';
      try {
        const commonHeaders = {
          'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.7258.66 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'es-CL,es;q=0.9,en;q=0.8',
          'Accept-Encoding': 'gzip, deflate, br',
          'Referer': 'https://seremienlinea.minsal.cl/'
        };
        const pre = await axios.get(API_BASE, { headers: commonHeaders, timeout: 7000 });
        const setCookies = pre.headers && pre.headers['set-cookie'];
        if (Array.isArray(setCookies) && setCookies.length > 0) {
          cookieHeader = setCookies.map((c: string) => c.split(';')[0]).join('; ');
        }
      } catch (e) {
        console.log('[API][communes] preflight GET failed region=' + regionId + ' ' + String(e).slice(0, 200));
      }
  const response = await axios.post(API_BASE, params, { headers: { 'Content-Type': 'application/x-www-form-urlencoded', ...(commonHeaders as any), ...(cookieHeader ? { Cookie: cookieHeader } : {}) }, timeout: 7000 });
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

// ...existing code...
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

  // Chilean Ministry of Health API base URL
  // const API_BASE = process.env.FARMANET_API_URL || 'https://seremienlinea.minsal.cl/asdigital/mfarmacias/mapa.php';

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
        const { region, comuna, tipo, lat, lng } = req.query;
        const commonHeaders = {
          'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.7258.66 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'es-CL,es;q=0.9,en;q=0.8',
          'Accept-Encoding': 'gzip, deflate, br',
          'Referer': 'https://seremienlinea.minsal.cl/'
        };
        const cacheKey = `pharmacies:${region}:${comuna || ''}:${tipo || ''}`;
        let result;
        const cached = cache.get(cacheKey);
        const API_BASE = process.env.FARMANET_API_URL || 'https://seremienlinea.minsal.cl/asdigital/mfarmacias/mapa.php';
        if (cached) {
          result = cached;
        } else {
          let data;
            try {
            // Usar POST form-encoded para locales_farmacias
            const params = new URLSearchParams({ func: 'locales_farmacias', region: String(region) });
            let cookieHeader = '';
            try {
              const commonHeaders = {
                'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.7258.66 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
                'Accept-Language': 'es-CL,es;q=0.9,en;q=0.8',
                'Accept-Encoding': 'gzip, deflate, br',
                'Referer': 'https://seremienlinea.minsal.cl/'
              };
              const pre = await axios.get(API_BASE, { headers: commonHeaders, timeout: 7000 });
              const setCookies = pre.headers && pre.headers['set-cookie'];
              if (Array.isArray(setCookies) && setCookies.length > 0) {
                cookieHeader = setCookies.map((c: string) => c.split(';')[0]).join('; ');
              }
            } catch (e) {
              console.log('[API][pharmacies] preflight GET failed region=' + region + ' ' + String(e).slice(0, 200));
            }
            const response = await axios.post(API_BASE, params, { headers: { 'Content-Type': 'application/x-www-form-urlencoded', ...(commonHeaders as any), ...(cookieHeader ? { Cookie: cookieHeader } : {}) }, timeout: 7000 });
            data = response.data;
            // Log de la respuesta cruda de la API oficial (parcial, para evitar logs enormes)
            try {
              const preview = typeof data === 'string' ? data.slice(0, 1000) : JSON.stringify(Array.isArray(data) ? data.slice(0, 10) : data).slice(0, 1000);
              console.log('[API][pharmacies] farmanet status=' + response.status + ' preview=' + preview);
            } catch (e) {
              console.log('[API][pharmacies] farmanet status=' + response.status + ' (could not stringify preview)');
            }
          } catch (err) {
            console.error('[API][pharmacies] Error al consultar Farmanet:', err);
            return res.status(500).json({ error: 'External API error' });
          }
          if (!Array.isArray(data)) {
            console.error('[API][pharmacies] La respuesta NO es un array:', data);
            return res.status(500).json({ error: 'Invalid data from API', raw: data });
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
    const commonHeaders = {
      'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64)',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'es-CL,es;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'Referer': 'https://seremienlinea.minsal.cl/'
    };
    const func = String(req.query.func || 'locales_regiones');
    const region = req.query.region as string | undefined;
    const API_BASE = process.env.FARMANET_API_URL || 'https://seremienlinea.minsal.cl/asdigital/mfarmacias/mapa.php';
    try {
      // Preflight GET to obtain cookies/challenges
      let cookieHeader = '';
      try {
        const commonHeaders = {
          'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64)',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'es-CL,es;q=0.9',
          'Accept-Encoding': 'gzip, deflate, br',
          'Referer': 'https://seremienlinea.minsal.cl/'
        };
        const pre = await axios.get(API_BASE, { headers: commonHeaders, timeout: 8000 });
        const setCookies = pre.headers && pre.headers['set-cookie'];
        if (Array.isArray(setCookies) && setCookies.length > 0) {
          cookieHeader = setCookies.map((c: string) => c.split(';')[0]).join('; ');
        }
      } catch (e) {
        // continue, we'll attempt POST anyway
      }

      const params = new URLSearchParams({ func });
      if (region) params.append('region', region);
  const response = await axios.post(API_BASE, params, { headers: { 'Content-Type': 'application/x-www-form-urlencoded', ...(commonHeaders as any), ...(cookieHeader ? { Cookie: cookieHeader } : {}) }, timeout: 10000, responseType: 'arraybuffer' });

      // Build a safe preview string
      const buf = Buffer.from(response.data || '');
      const preview = buf.toString('utf8', 0, Math.min(buf.length, 5000));
      const isJson = (() => {
        try { JSON.parse(preview); return true; } catch { return false; }
      })();

      return res.json({ ok: true, status: response.status, headers: response.headers, preview: preview.slice(0, 2000), isJson });
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
