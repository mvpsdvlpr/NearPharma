import { Request, Response, NextFunction } from 'express';

// Basic input sanitization middleware
export function sanitizeInputs(req: Request, res: Response, next: NextFunction) {
  // Sanitize query params
  for (const key in req.query) {
    if (typeof req.query[key] === 'string') {
      req.query[key] = String(req.query[key]).replace(/[<>"'`;(){}]/g, '');
    }
  }
  next();
}
