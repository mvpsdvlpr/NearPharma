import { Request, Response, NextFunction } from 'express';

const SENSITIVE_KEYS = ['password', 'token', 'authorization', 'auth', 'cookie', 'set-cookie', 'set_cookie'];

const SENSITIVE_HEADER_KEYS = ['authorization', 'cookie', 'set-cookie', 'proxy-authorization'];

function maskSensitive(obj: any): any {
  if (obj == null) return obj;
  if (typeof obj !== 'object') return obj;
  try {
    if (Array.isArray(obj)) return obj.map(maskSensitive);
    const out: any = {};
    for (const k of Object.keys(obj)) {
      try {
        if (SENSITIVE_KEYS.includes(k.toLowerCase())) {
          out[k] = '***';
        } else if (typeof obj[k] === 'object' && obj[k] !== null) {
          out[k] = maskSensitive(obj[k]);
        } else {
          out[k] = obj[k];
        }
      } catch (_) {
        out[k] = '***';
      }
    }
    return out;
  } catch (_) {
    return '***';
  }
}

function truncate(s: string | undefined | null, n = 2000) {
  if (s == null) return s;
  if (s.length <= n) return s;
  return s.slice(0, n) + '...(' + (s.length - n) + ' more chars)';
}

export default function requestLogger() {
  return (req: Request, res: Response, next: NextFunction) => {
    const start = process.hrtime();

    // Capture original send to inspect response body
    const originalSend = (res as any).send.bind(res);
    let responseBody: string | undefined;

    (res as any).send = function sendOverride(body?: any) {
      try {
        if (body === undefined || body === null) responseBody = '';
        else if (typeof body === 'string') responseBody = body;
        else if (Buffer.isBuffer(body)) responseBody = body.toString('utf8');
        else responseBody = JSON.stringify(body);
      } catch (e) {
        try { responseBody = String(body); } catch (_) { responseBody = undefined; }
      }
      // call original send
      return originalSend(body);
    } as any;

    // When finished, log structured info
    res.on('finish', () => {
      try {
        const diff = process.hrtime(start);
        const durationMs = Math.round((diff[0] * 1e3) + (diff[1] / 1e6) * 1000) / 1000; // ms with fractional
        const clientIp = (req.headers['x-forwarded-for'] || req.socket.remoteAddress || req.ip || '').toString().split(',')[0].trim();

        // Mask headers (do not include raw headers in logs)
        const maskedHeaders: any = {};
        try {
          for (const hk of Object.keys(req.headers || {})) {
            const lk = hk.toLowerCase();
            if (SENSITIVE_HEADER_KEYS.includes(lk)) {
              maskedHeaders[hk] = '***';
            } else {
              maskedHeaders[hk] = req.headers[hk];
            }
          }
        } catch (_) {}

        const logObj: any = {
          ts: new Date().toISOString(),
          method: req.method,
          route: req.originalUrl || req.url,
          status: res.statusCode,
          duration_ms: durationMs,
          client_ip: clientIp,
          headers: Object.keys(maskedHeaders).length ? maskedHeaders : undefined,
          query: Object.keys(req.query || {}).length ? req.query : undefined,
          params: Object.keys(req.params || {}).length ? req.params : undefined,
        };

        // Mask and include request body if present
        try {
          if (req.body && Object.keys(req.body).length > 0) {
            logObj.request_body = maskSensitive(req.body);
          }
        } catch (_) {}

        // Add a small preview of the response body if captured
        try {
          if (responseBody) {
            // If response appears to be HTML, keep a smaller preview
            const ct = (res.getHeader && res.getHeader('content-type')) || '';
            const isHtml = String(ct).toLowerCase().includes('text/html');
            logObj.response_preview = truncate(responseBody, isHtml ? 500 : 2000);
          }
        } catch (_) {}

        // If status indicates server error, log as error to stderr for visibility
        if (res.statusCode >= 500) {
          try { console.error(JSON.stringify(logObj)); } catch (_) { console.error('error logging request'); }
        } else {
          try { console.info(JSON.stringify(logObj)); } catch (_) { console.log('log', logObj); }
        }
      } catch (e) {
        // Ensure nothing here can crash the app
        try { console.error('[requestLogger] unexpected error:', String(e).slice(0, 500)); } catch (_) {}
      }
    });

    next();
  };
}
