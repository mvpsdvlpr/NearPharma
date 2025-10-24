import { Request, Response, NextFunction } from 'express';

// Basic input sanitization middleware
export function sanitizeInputs(req: Request, res: Response, next: NextFunction) {
  // Sanitize query params
  for (const key in req.query) {
    if (typeof req.query[key] === 'string') {
      req.query[key] = String(req.query[key]).replace(/[<>"'`;(){}]/g, '');
    }
  }
  // Sanitize body (only string fields) for form submissions
  try {
    if (req.body && typeof req.body === 'object') {
      for (const key in req.body) {
        if (typeof req.body[key] === 'string') {
          req.body[key] = String(req.body[key]).replace(/[<>"'`;(){}]/g, '');
        }
      }
    }
  } catch (_) {
    // Don't fail the request if sanitization has an unexpected type
  }
  next();
}
