import request from 'supertest';
import app from '../src/app';
import axios from 'axios';

jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

beforeEach(() => {
  mockedAxios.get.mockResolvedValue({ data: '', headers: {} as any, status: 200 });
  // default POST handler returns sample responses depending on func param
  mockedAxios.post.mockImplementation((url: any, params: any) => {
    const p = params as URLSearchParams;
    const func = p.get('func');
    if (func === 'fechas') {
      const payload = { correcto: true, respuesta: { '2025-10-20': 'Lunes 20 de Octubre', '2025-10-21': 'Martes 21 de Octubre' } };
      return Promise.resolve({ data: Buffer.from(JSON.stringify(payload), 'utf8'), headers: { 'content-type': 'application/json' }, status: 200 } as any);
    }
    if (func === 'regiones') {
      const payload = { correcto: true, respuesta: [] };
      return Promise.resolve({ data: Buffer.from(JSON.stringify(payload), 'utf8'), headers: { 'content-type': 'application/json' }, status: 200 } as any);
    }
    if (func === 'comunas') {
      const payload = { correcto: true, respuesta: [] };
      return Promise.resolve({ data: Buffer.from(JSON.stringify(payload), 'utf8'), headers: { 'content-type': 'application/json' }, status: 200 } as any);
    }
    if (func === 'iconos') {
      const payload = { correcto: true, respuesta: { correct: true } };
      return Promise.resolve({ data: Buffer.from(JSON.stringify(payload), 'utf8'), headers: { 'content-type': 'application/json' }, status: 200 } as any);
    }
    const payload = { correcto: false, error: 'Func no soportado' };
    return Promise.resolve({ data: Buffer.from(JSON.stringify(payload), 'utf8'), headers: { 'content-type': 'application/json' }, status: 400 } as any);
  });
});

afterEach(() => jest.clearAllMocks());

describe('POST /mfarmacias/mapa.php', () => {
  it('should return fechas for func=fechas', async () => {
    const res = await request(app)
      .post('/mfarmacias/mapa.php')
      .send('func=fechas')
      .set('Content-Type', 'application/x-www-form-urlencoded');
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('correcto', true);
    expect(res.body).toHaveProperty('respuesta');
    expect(typeof res.body.respuesta).toBe('object');
  });

  it('should return regiones for func=regiones', async () => {
    const res = await request(app)
      .post('/mfarmacias/mapa.php')
      .send('func=regiones')
      .set('Content-Type', 'application/x-www-form-urlencoded');
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('correcto', true);
    expect(res.body).toHaveProperty('respuesta');
  });

  it('should return comunas for func=comunas and region', async () => {
    const res = await request(app)
      .post('/mfarmacias/mapa.php')
      .send('func=comunas&region=7')
      .set('Content-Type', 'application/x-www-form-urlencoded');
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('correcto', true);
    expect(res.body).toHaveProperty('respuesta');
  });

  it('should return iconos for func=iconos', async () => {
    const res = await request(app)
      .post('/mfarmacias/mapa.php')
      .send('func=iconos')
      .set('Content-Type', 'application/x-www-form-urlencoded');
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('correcto', true);
    expect(res.body).toHaveProperty('respuesta');
  });

  it('should return error for unsupported func', async () => {
    const res = await request(app)
      .post('/mfarmacias/mapa.php')
      .send('func=unsupported')
      .set('Content-Type', 'application/x-www-form-urlencoded');
    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('correcto', false);
  });
});
