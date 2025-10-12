import express, { Request, Response, NextFunction } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import apiRouter from './routes/api';
import { sanitizeInputs } from './middleware/security';

const app = express();

// Security HTTP headers
app.use(helmet());

// CORS configuration
app.use(cors({
  origin: '*', // Adjust for production
  methods: ['GET'],
}));

// Logging
app.use(morgan('dev'));

// Rate limiting
const limiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 60, // limit each IP to 60 requests per windowMs
});
app.use(limiter);

// JSON parsing (not needed for GET, but future-proof)
app.use(express.json());
// Soporte para application/x-www-form-urlencoded (como Farmanet)
app.use(express.urlencoded({ extended: true }));

// Input sanitization
app.use(sanitizeInputs);


// API routes
app.use('/api', apiRouter);
// Also mount the same router under /mfarmacias so compatibility/debug
// endpoints are reachable from that base (used by the original web paths).
app.use('/mfarmacias', apiRouter);

// Compatibilidad directa: POST /mfarmacias/mapa.php

import { handleMapaPhpCompat } from './routes/api';
// Registrar la ruta de compatibilidad ANTES del 404
app.post('/mfarmacias/mapa.php', handleMapaPhpCompat);

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
