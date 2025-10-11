import request from 'supertest';
import app from '../src/app';

describe('GET /api/regions', () => {
  it('should return 200 and an array of regions', async () => {
    const res = await request(app).get('/api/regions');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    // Should have at least one region
    expect(res.body.length).toBeGreaterThan(0);
    // Should have id and nombre fields
    expect(res.body[0]).toHaveProperty('id');
    expect(res.body[0]).toHaveProperty('nombre');
  });
});

describe('GET /api/communes', () => {
  it('should return 400 if region is missing', async () => {
    const res = await request(app).get('/api/communes');
    expect(res.status).toBe(400);
  });

  it('should return 400 if region is invalid', async () => {
    const res = await request(app).get('/api/communes?region=0');
    expect(res.status).toBe(400);
  });

  it('should return 200 and an array of communes for valid region', async () => {
    const res = await request(app).get('/api/communes?region=7');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    // Should have id and nombre fields if any commune exists
    if (res.body.length > 0) {
      expect(res.body[0]).toHaveProperty('id');
      expect(res.body[0]).toHaveProperty('nombre');
    }
  });
});
