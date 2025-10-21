import request from 'supertest';
import { createApiRouter } from '../src/routes/api';
import express from 'express';
import Cache from '../src/cache';

describe('GET /api/health', () => {
  it('should return ok and cache metrics', async () => {
    const cache = new Cache<any>();
    const app = express();
    app.use('/api', createApiRouter(cache));
    const res = await request(app).get('/api/health');
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.cache).toBeDefined();
  });
});
