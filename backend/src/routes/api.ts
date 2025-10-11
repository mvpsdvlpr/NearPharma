

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
      const API_BASE = process.env.FARMANET_API_URL || 'https://farmanet.minsal.cl/maps/index.php/ws/getLocalesRegion';
      const regionesSet = new Set();
      for (let region = 1; region <= 16; region++) {
        try {
          const response = await axios.get(`${API_BASE}/${region}`);
          const data = response.data;
          if (Array.isArray(data)) {
            data.forEach((item: any) => {
              if (item.region_nombre) regionesSet.add(JSON.stringify({ id: region, nombre: item.region_nombre }));
            });
          }
        } catch (e) {
          console.error(`[API][regions] Error consultando region ${region}:`, e);
        }
      }
      const regiones = Array.from(regionesSet).map((s: any) => JSON.parse(s));
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
      const API_BASE = process.env.FARMANET_API_URL || 'https://farmanet.minsal.cl/maps/index.php/ws/getLocalesRegion';
      const response = await axios.get(`${API_BASE}/${regionId}`);
      const data = response.data;
      const comunasSet = new Set();
      if (Array.isArray(data)) {
        data.forEach((item: any) => {
          if (item.comuna_nombre) comunasSet.add(item.comuna_nombre);
        });
      }
      const comunas = Array.from(comunasSet).map((nombre) => {
        const nombreStr = String(nombre);
        return { id: nombreStr.toLowerCase().replace(/ /g, '-'), nombre: nombreStr };
      });
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
  // const API_BASE = process.env.FARMANET_API_URL || 'https://farmanet.minsal.cl/maps/index.php/ws/getLocalesRegion';

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
        if (cached) {
          result = cached;
        } else {
          // Build API URL
          let data;
          try {
            const response = await axios.get(`${API_BASE}/${region}`, { timeout: 5000 });
            data = response.data;
          } catch (err) {
            return res.status(500).json({ error: 'External API error' });
          }
          // Validate data is array
          if (!Array.isArray(data)) {
            return res.status(500).json({ error: 'Invalid data from API' });
          }
          // Filter by comuna/tipo if provided
          result = data;
          if (comuna) {
            result = result.filter((item: any) => item.comuna_nombre?.toLowerCase() === String(comuna).toLowerCase());
          }
          if (tipo) {
            result = result.filter((item: any) => item.local_tipo?.toLowerCase() === String(tipo).toLowerCase());
          }
          // Only cache if result is non-empty array
          if (Array.isArray(result) && result.length > 0) {
            cache.set(cacheKey, result, CACHE_TTL);
          }
        }
        // Order by proximity if lat/lng provided
        if (lat !== undefined && lng !== undefined && !isNaN(Number(lat)) && !isNaN(Number(lng))) {
          const userLat = Number(lat);
          const userLng = Number(lng);
          result = result.slice().sort((a: any, b: any) => {
            const dA = distance(userLat, userLng, parseFloat(a.local_lat || a.lat || a.lt), parseFloat(a.local_lng || a.lng || a.lg));
            const dB = distance(userLat, userLng, parseFloat(b.local_lat || b.lat || b.lt), parseFloat(b.local_lng || b.lng || b.lg));
            return dA - dB;
          });
        }
        // Always return array (empty or with data)
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
