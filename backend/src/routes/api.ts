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
      const API_BASE = process.env.FARMANET_API_URL || 'https://seremienlinea.minsal.cl/asdigital/mfarmacias/mapa.php';
      // La API oficial usa ?func=locales_regiones
      const response = await axios.get(`${API_BASE}?func=locales_regiones`);
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
    console.log(`[API] GET /api/communes?region=${regionId}`);
    try {
      const API_BASE = process.env.FARMANET_API_URL || 'https://seremienlinea.minsal.cl/asdigital/mfarmacias/mapa.php';
      // La API oficial usa ?func=locales_comunas&region=ID
      const response = await axios.get(`${API_BASE}?func=locales_comunas&region=${regionId}`);
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
        const cacheKey = `pharmacies:${region}:${comuna || ''}:${tipo || ''}`;
        let result;
        const cached = cache.get(cacheKey);
        const API_BASE = process.env.FARMANET_API_URL || 'https://seremienlinea.minsal.cl/asdigital/mfarmacias/mapa.php';
        if (cached) {
          result = cached;
        } else {
          let data;
          try {
            const response = await axios.get(`${API_BASE}?func=locales_farmacias&region=${region}`, { timeout: 5000 });
            data = response.data;
            // Log de la respuesta cruda de la API oficial
            console.log('[API][pharmacies] Respuesta cruda de Farmanet:', JSON.stringify(data));
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

  // Exponer el cache para testing
  (router as any)._cache = cache;
  return router;
}

// Para uso normal (no testing)
const defaultRouter = createApiRouter();
export default defaultRouter;
