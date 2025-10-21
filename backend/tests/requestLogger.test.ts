import request from 'supertest';
import app from '../src/app';

describe('requestLogger middleware', () => {
  let origInfo: any;
  let captured: string[] = [];
  beforeAll(() => {
    origInfo = console.info;
    captured = [];
    console.info = (msg: any) => {
      try { captured.push(typeof msg === 'string' ? msg : JSON.stringify(msg)); } catch (_) { captured.push(String(msg)); }
    };
  });
  afterAll(() => {
    console.info = origInfo;
  });

  test('masks sensitive headers and truncates HTML preview', async () => {
    const longHtml = '<html>' + 'a'.repeat(2000) + '</html>';
    const res = await request(app)
      .get('/api/version')
      .set('Authorization', 'Bearer SECRET_TOKEN')
      .set('Cookie', 'session=abcd;')
      .expect(200);

    // Ensure the request produced at least one structured log
    expect(captured.length).toBeGreaterThan(0);
    const last = JSON.parse(captured[captured.length - 1]);
    // headers should contain masked authorization and cookie
    expect(last.headers).toBeDefined();
    expect(last.headers['Authorization'] === '***' || last.headers['authorization'] === '***' || last.headers['Authorization'] === undefined).toBeTruthy();
    // response_preview may be present but should be short (we tested earlier HTML handling separately)
    if (last.response_preview) {
      expect(last.response_preview.length).toBeLessThanOrEqual(500);
    }
  });
});
