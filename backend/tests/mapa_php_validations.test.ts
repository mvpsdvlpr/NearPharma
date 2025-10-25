import request from 'supertest';
import app from '../src/app';
import axios from 'axios';

jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

beforeEach(() => {
  mockedAxios.get.mockResolvedValue({ data: '', headers: {} as any, status: 200 });
  mockedAxios.post.mockImplementation((url: any, params: any) => {
    const p = params as URLSearchParams;
    const func = p.get('func');
    if (func === 'region') {
      const payload = { correcto: true, respuesta: [] };
      return Promise.resolve({ data: Buffer.from(JSON.stringify(payload), 'utf8'), headers: { 'content-type': 'application/json' }, status: 200 } as any);
    }
    if (func === 'local') {
      const payload = { correcto: true, respuesta: [] };
      return Promise.resolve({ data: Buffer.from(JSON.stringify(payload), 'utf8'), headers: { 'content-type': 'application/json' }, status: 200 } as any);
    }
    const payload = { correcto: false, error: 'Func no soportado' };
    return Promise.resolve({ data: Buffer.from(JSON.stringify(payload), 'utf8'), headers: { 'content-type': 'application/json' }, status: 400 } as any);
  });
});

afterEach(() => jest.clearAllMocks());

describe('POST /mfarmacias/mapa.php validation', () => {
  it('rejects non-whitelisted func', async () => {
    const res = await request(app)
      .post('/mfarmacias/mapa.php')
      .send('func=attack')
      .set('Content-Type', 'application/x-www-form-urlencoded');
    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('correcto', false);
  });

  it('rejects invalid region formats for comunas', async () => {
    const res = await request(app)
      .post('/mfarmacias/mapa.php')
      .send('func=comunas&region=abc')
      .set('Content-Type', 'application/x-www-form-urlencoded');
    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('correcto', false);
  });

  it('accepts valid region for comunas', async () => {
    const res = await request(app)
      .post('/mfarmacias/mapa.php')
      .send('func=comunas&region=7')
      .set('Content-Type', 'application/x-www-form-urlencoded');
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('correcto');
  });

  it('rejects invalid fecha format for region func', async () => {
    const res = await request(app)
      .post('/mfarmacias/mapa.php')
      .send('func=region&region=7&fecha=20-10-2025')
      .set('Content-Type', 'application/x-www-form-urlencoded');
    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('correcto', false);
  });

  it('accepts valid fecha format for region func', async () => {
    const res = await request(app)
      .post('/mfarmacias/mapa.php')
      .send('func=region&region=7&fecha=2025-10-20')
      .set('Content-Type', 'application/x-www-form-urlencoded');
    expect(res.status).toBe(200);
  });

  it('rejects invalid im for local func', async () => {
    const res = await request(app)
      .post('/mfarmacias/mapa.php')
      .send('func=local&im=<script>')
      .set('Content-Type', 'application/x-www-form-urlencoded');
    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('correcto', false);
  });
});
