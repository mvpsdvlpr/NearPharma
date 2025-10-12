# NearPharma Backend

This is a secure Node.js + TypeScript backend for the NearPharma app, designed for Vercel deployment and scalable cloud hosting.

## Features
- Express REST API proxy to Chilean Ministry of Health pharmacy data
- In-memory cache with TTL (easy to migrate to Redis)
- Input validation and sanitization
- CORS, Helmet, rate limiting, and logging
- Error handling and 404 responses
- Ready for Vercel or other cloud deployment

## Endpoints
- `GET /api/pharmacies?region=...&comuna=...&tipo=...`

## Security
- Input validation (express-validator)
- Input sanitization middleware
- CORS (adjust origin for production)
- Helmet for HTTP headers
- Rate limiting (per IP)
- Error handling

## Setup
1. `npm install`
2. Copy `.env.example` to `.env` and adjust as needed
3. `npm run build && npm start` (for local dev)

## Deployment
- Vercel: uses `vercel.json` for config

## Future Improvements
- Replace in-memory cache with Redis for scale
- Add authentication for admin endpoints
- Add monitoring/logging integrations
