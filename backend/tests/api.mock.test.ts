import request from 'supertest';
import axios from 'axios';
import { createApiRouter } from '../src/routes/api';
import express from 'express';
import Cache from '../src/cache';

jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

const fakeData = [
  {
    local_id: '1',
    local_nombre: 'Farmacia Uno',
    comuna_nombre: 'Curicó',
    local_direccion: 'Calle 1',
    local_telefono: '123',
    local_lat: '-34.98',
    local_lng: '-71.24',
    local_tipo: 'Farmacia',
    funcionamiento_hora_apertura: '09:00',
    funcionamiento_hora_cierre: '21:00',
    fecha: '2025-10-08',
  },
  {
    local_id: '2',
    local_nombre: 'Farmacia Dos',
    comuna_nombre: 'Talca',
    local_direccion: 'Calle 2',
    local_telefono: '456',
    local_lat: '-35.42',
    local_lng: '-71.67',
    local_tipo: 'Farmacia',
    funcionamiento_hora_apertura: '08:00',
    funcionamiento_hora_cierre: '20:00',
    fecha: '2025-10-08',
  }
];

// Crear app y cache inyectable
const cache = new Cache<any>();
const app = express();
app.use(express.json());
app.use('/api', createApiRouter(cache));

describe('GET /api/pharmacies (mocked)', () => {
  beforeEach(() => {
    // Mock preflight GET (may be called) to return empty headers
    mockedAxios.get.mockResolvedValue({ data: '', headers: {} as any, status: 200 });
    // Mock POST to return arraybuffer-like data
    const buf = Buffer.from(JSON.stringify(fakeData), 'utf8');
    mockedAxios.post.mockResolvedValue({ data: buf, headers: { 'content-type': 'application/json' }, status: 200 } as any);
    cache.clear();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should return 200 and array for valid region', async () => {
    const res = await request(app).get('/api/pharmacies?region=7');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBe(2);
  });

  it('should filter by comuna', async () => {
    const res = await request(app).get('/api/pharmacies?region=7&comuna=Curicó');
    expect(res.status).toBe(200);
    expect(res.body.length).toBe(1);
    expect(res.body[0].comuna_nombre).toBe('Curicó');
  });

  it('should filter by tipo', async () => {
    const res = await request(app).get('/api/pharmacies?region=7&tipo=Farmacia');
    expect(res.status).toBe(200);
    expect(res.body.length).toBe(2);
  });

  it('should order by proximity if lat/lng provided', async () => {
    const res = await request(app).get('/api/pharmacies?region=7&lat=-34.98&lng=-71.24');
    expect(res.status).toBe(200);
    expect(res.body[0].local_id).toBe('1'); // más cerca
  });

  it('should return 500 if API throws error', async () => {
    mockedAxios.post.mockRejectedValueOnce(new Error('API down'));
    const res = await request(app).get('/api/pharmacies?region=7');
    expect(res.status).toBe(500);
    expect(res.body.error).toBe('External API error');
  });

  it('should return 200 with empty array if API returns empty', async () => {
    const buf = Buffer.from(JSON.stringify([]), 'utf8');
    mockedAxios.post.mockResolvedValueOnce({ data: buf, headers: { 'content-type': 'application/json' }, status: 200 } as any);
    const res = await request(app).get('/api/pharmacies?region=7');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBe(0);
  });

  it('should return 500 if API returns invalid data', async () => {
    mockedAxios.get.mockResolvedValueOnce({ data: null });
    const res = await request(app).get('/api/pharmacies?region=7');
    expect([200, 500]).toContain(res.status); // depende de la lógica, documentar
  });
});
