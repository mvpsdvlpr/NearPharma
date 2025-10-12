import request from 'supertest';
import app from '../src/app';

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
