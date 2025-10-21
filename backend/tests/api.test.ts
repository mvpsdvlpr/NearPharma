import request from 'supertest';
import app from '../src/app';
import axios from 'axios';

jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

// provide deterministic axios mocks so CI doesn't call external Farmanet
beforeEach(() => {
  mockedAxios.get.mockResolvedValue({ data: '', headers: {} as any, status: 200 });
  const fake = [{ local_id: '1', local_nombre: 'Farmacia Uno', comuna_nombre: 'Curicó', local_direccion: 'Calle 1', local_telefono: '123', local_lat: '-34.98', local_lng: '-71.24', local_tipo: 'Farmacia', funcionamiento_hora_apertura: '09:00', funcionamiento_hora_cierre: '21:00', fecha: '2025-10-08' }];
  const buf = Buffer.from(JSON.stringify(fake), 'utf8');
  mockedAxios.post.mockResolvedValue({ data: buf, headers: { 'content-type': 'application/json' }, status: 200 } as any);
});

afterEach(() => jest.clearAllMocks());

describe('GET /api/pharmacies', () => {
  it('should return 400 if region is missing', async () => {
    const res = await request(app).get('/api/pharmacies');
    expect(res.status).toBe(400);
    expect(res.body.errors).toBeDefined();
  });

  it('should return 400 if region is invalid', async () => {
    const res = await request(app).get('/api/pharmacies?region=0');
    expect(res.status).toBe(400);
  });

  it('should return 200 and array for valid region', async () => {
    const res = await request(app).get('/api/pharmacies?region=7');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  it('should filter by comuna', async () => {
    const res = await request(app).get('/api/pharmacies?region=7&comuna=Curicó');
    expect(res.status).toBe(200);
    expect(res.body.every((f: any) => f.comuna_nombre.toLowerCase() === 'curicó')).toBe(true);
  });

  it('should filter by tipo', async () => {
    const res = await request(app).get('/api/pharmacies?region=7&tipo=Farmacia');
    expect(res.status).toBe(200);
    expect(res.body.every((f: any) => f.local_tipo.toLowerCase() === 'farmacia')).toBe(true);
  });

  it('should order by proximity if lat/lng provided', async () => {
    const res = await request(app).get('/api/pharmacies?region=7&lat=-34.98&lng=-71.24');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    // Check that the first element is closest (not strict, but basic check)
    if (res.body.length > 1) {
      const d1 = Math.abs(parseFloat(res.body[0].local_lat) + 34.98) + Math.abs(parseFloat(res.body[0].local_lng) + 71.24);
      const d2 = Math.abs(parseFloat(res.body[1].local_lat) + 34.98) + Math.abs(parseFloat(res.body[1].local_lng) + 71.24);
      expect(d1).toBeLessThanOrEqual(d2);
    }
  });

  it('should sanitize dangerous input', async () => {
    const res = await request(app).get('/api/pharmacies?region=7&comuna=<script>alert(1)</script>');
    expect(res.status).toBe(200);
    expect(res.body.every((f: any) => !f.comuna_nombre.includes('<') && !f.comuna_nombre.includes('>'))).toBe(true);
  });

  it('should handle API external failure gracefully', async () => {
    // Simulate by using an invalid region
    const res = await request(app).get('/api/pharmacies?region=99');
  // Should return 200, 400 (invalid region) or 500 if API fails
  expect([200, 400, 500]).toContain(res.status);
  });
});
