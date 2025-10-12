import express, { Request, Response, NextFunction } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import rateLimit, { ipKeyGenerator } from 'express-rate-limit';
import { createApiRouter, handleFarmanetCompat } from './routes/api';
import axios from 'axios';
import { sanitizeInputs } from './middleware/security';

const app = express();

// Trust proxy (required when behind Vercel/Proxies so express-rate-limit can identify IPs)
// Use boolean true to trust the first proxy or a numeric value if you want to
// trust a specific number of proxies. Vercel/Cloud providers typically require
// trusting the proxy so X-Forwarded-For is considered.
app.set('trust proxy', true);

// Security HTTP headers
app.use(helmet());

// CORS configuration
app.use(cors({
  origin: '*', // Adjust for production
  methods: ['GET'],
}));

// Logging
app.use(morgan('dev'));

// Rate limiting — use a robust keyGenerator that tolerates forwarded headers
const limiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 60, // limit each IP to 60 requests per windowMs
  keyGenerator: (req: Request) => {
    try {
      // Prefer X-Forwarded-For if present (comma separated)
      const xff = (req.headers['x-forwarded-for'] || '') as string;
      if (xff) {
        const first = xff.split(',')[0].trim();
        if (first) return ipKeyGenerator(first);
      }
    } catch (e) {
      // ignore
    }
    // Fall back to express's helper which handles IPv6 subnetting
    return ipKeyGenerator(req.ip || '');
  }
});
app.use(limiter);

// JSON parsing (not needed for GET, but future-proof)
app.use(express.json());
// Soporte para application/x-www-form-urlencoded (como Farmanet)
app.use(express.urlencoded({ extended: true }));

// Input sanitization
app.use(sanitizeInputs);
const apiRouter = createApiRouter();

// API routes
app.use('/api', apiRouter);
// Also mount the same router under /mfarmacias so compatibility/debug
// endpoints are reachable from that base (used by the original web paths).
app.use('/mfarmacias', apiRouter);

// Compatibilidad directa: POST /mfarmacias/mapa.php
// Registrar la ruta de compatibilidad ANTES del 404
app.post('/mfarmacias/mapa.php', handleFarmanetCompat);

// Rutas de depuración explícitas bajo /mfarmacias para asegurar disponibilidad en Vercel
const _allowDebug = (process.env.NODE_ENV || '').toLowerCase() !== 'production' || process.env.ALLOW_DEBUG === 'true';
if (_allowDebug) {
  app.get('/mfarmacias/debug/ping', (req: Request, res: Response) => {
    res.json({ ok: true, now: new Date().toISOString(), env: process.env.NODE_ENV || 'dev' });
  });
  app.get('/mfarmacias/debug/cache-metrics', (req: Request, res: Response) => {
    try {
      const router: any = apiRouter as any;
      const cache: any = router._cache;
      if (!cache) return res.status(404).json({ ok: false, error: 'No cache exposed' });
      return res.json({ ok: true, metrics: cache.getMetrics ? cache.getMetrics() : null });
    } catch (e) {
      return res.status(500).json({ ok: false, error: String(e) });
    }
  });
  app.get('/mfarmacias/debug/farmanet', async (req: Request, res: Response) => {
  const func = String(req.query.func || 'locales_regiones');
  const region = req.query.region as string | undefined;
  const API_BASE = process.env.FARMANET_API_URL || 'https://seremienlinea.minsal.cl/asdigital/mfarmacias/mapa.php';
  try {
    const commonHeaders = {
      'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64)',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'es-CL,es;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'Referer': 'https://seremienlinea.minsal.cl/'
    };
    // Preflight GET
    let cookieHeader = '';
    try {
      const pre = await axios.get(API_BASE, { headers: commonHeaders, timeout: 8000 });
      const setCookies = pre.headers && (pre.headers as any)['set-cookie'];
      if (Array.isArray(setCookies) && setCookies.length > 0) {
        cookieHeader = setCookies.map((c: string) => c.split(';')[0]).join('; ');
      }
    } catch (e) {
      // continue and attempt POST anyway
    }

    const params = new URLSearchParams({ func });
    if (region) params.append('region', region);
    const response = await axios.post(API_BASE, params, { headers: { 'Content-Type': 'application/x-www-form-urlencoded', ...(commonHeaders as any), ...(cookieHeader ? { Cookie: cookieHeader } : {}) }, timeout: 10000, responseType: 'arraybuffer' });
    const buf = Buffer.from(response.data || '');
    const preview = buf.toString('utf8', 0, Math.min(buf.length, 5000));
    const isJson = (() => { try { JSON.parse(preview); return true; } catch { return false; } })();
    return res.json({ ok: true, status: response.status, headers: response.headers, preview: preview.slice(0, 2000), isJson });
  } catch (err) {
    return res.status(500).json({ ok: false, error: String(err).slice(0, 1000) });
  }
  });
} // end _allowDebug

// 404 handler
app.use((req: Request, res: Response) => {
  res.status(404).json({ error: 'Not found' });
});

// Error handler
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

export default app;
