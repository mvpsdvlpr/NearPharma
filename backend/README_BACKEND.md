# Backend - Versioning & Deployment notes

This document explains the `/api/version` endpoint and how to provide accurate build metadata during CI/Vercel builds.

## /api/version

- Returns JSON with the following fields (in non-production):
  - `version` (from `package.json`)
  - `label` formatted as `<version> - <channel> - build DDMMYYYY.HHMM` (example: `1.0.0 - stable - build 20102025.2214`)
  - `commit` (short SHA) and `branch` when available
  - `buildTime` (ISO)
  - `env` (NODE_ENV)

- In production the endpoint returns only `{ ok: true, label, env }` unless `ALLOW_VERSION=true` is set.

## Build-time environment variables

During CI / Vercel build, run the provided script to generate `.env.build` before compilation:

```
node ./scripts/generate_build_env.js
```

The generator writes the following keys to `.env.build`:

- `VERCEL_GIT_COMMIT_SHA` - commit SHA (or CI-provided equivalent)
- `VERCEL_GIT_COMMIT_REF` - branch name
- `BUILD_TIME` - ISO timestamp of build
- `RELEASE_CHANNEL` - e.g. `stable` or `beta`

The `vercel-build` script already runs the generator before `tsc`.

## Security & Ops

- `.env.build` is ignored by git and written with restrictive permissions (600). Do not commit it.
- In production, prefer to keep `/api/version` minimal (only label) unless strictly necessary.
- Route logs go to stdout as structured JSON; configure a secure log sink (with redaction and RBAC) in production.
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

## Deploying to Vercel

This project is compatible with Vercel's Node.js serverless/runtime. To deploy:

1. Install the Vercel CLI (optional): `npm i -g vercel`
2. From the `backend/` folder run `vercel` and follow the prompts, or connect this repository in the Vercel dashboard.
3. Vercel will run the `vercel-build` script (which delegates to `npm run build`) and deploy the compiled `dist/` files.

Notes:
- Ensure `NODE_ENV=production` is set in Vercel Environment Variables if you depend on it.
- The `vercel.json` routes the `/api/*` path to the serverless function at `src/app.ts`.

## Future Improvements
- Replace in-memory cache with Redis for scale
- Add authentication for admin endpoints
- Add monitoring/logging integrations
