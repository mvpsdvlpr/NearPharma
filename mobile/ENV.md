Mobile environment and build instructions

Resolution order for API_BASE_URL:
1. --dart-define=API_BASE_URL (highest priority) — recommended for CI and Play/App Store builds
2. .env file using flutter_dotenv (development/emulator)
3. Fallback: http://localhost:3001

Local development using emulator:
- Android emulator should use 10.0.2.2 to reach host localhost.
- Copy .env.development.example -> .env in mobile/ and adjust values.

Commands:
- Run on emulator using dart define (example):
  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3001

- Run using .env (no dart-define):
  # from mobile/ directory
  cp .env.development.example .env
  flutter run

- Build release APK with dart-define (CI / production):
  flutter build apk --release --dart-define=API_BASE_URL=https://your-backend.vercel.app

Notes for CI:
- Use --dart-define during build to inject production API URL; do not store production URLs in plaintext .env files in the repo.
- For Android emulator host access on local dev, use 10.0.2.2 instead of localhost.

Vercel domains (you provided):

- nearpharma-gvmztqdse-nuvra-projects.vercel.app
- nearpharma-liard.vercel.app

Which to use:
- Use the shorter, stable domain `nearpharma-liard.vercel.app` as the production API_BASE_URL when it points to your live backend.
- The longer name `nearpharma-gvmztqdse-nuvra-projects.vercel.app` looks like a generated preview/alias — you can use it for a temporary or preview build but prefer the stable project domain for production.

Example production build using the Vercel domain you provided:

flutter build apk --release --dart-define=API_BASE_URL=https://nearpharma-liard.vercel.app

Notes and recommendations:
- If you control the Vercel project, consider adding a custom domain and configure HTTPS there. Then use the custom domain in production builds.
- For CI, inject the production URL as a secret and pass it to the Flutter build via --dart-define so production builds never include plain-text URLs in committed files.
- Double-check that the backend route the app uses matches the domain (the mobile app calls endpoints under /mfarmacias/*). If your API lives under a subpath or another base path, include it in the URL (for example `https://nearpharma-liard.vercel.app/mfarmacias`), but the current app expects the base URL to be scheme+host (e.g., https://nearpharma-liard.vercel.app) and appends `/mfarmacias/...` internally.

If you want, I can:
- Update the example `.env.production.example` to set `API_BASE_URL` to `https://nearpharma-liard.vercel.app`.
- Add a small CI snippet that shows how to inject the production URL using a secret and pass it to `flutter build` via `--dart-define`.

CI example (GitHub Actions)
---------------------------

Below is a minimal GitHub Actions snippet showing how to inject the production API base URL stored as a repository secret (do NOT store secrets in code).

1) Add a repository secret named `PROD_API_BASE_URL` with value like `https://nearpharma-liard.vercel.app`.

2) Example workflow job (add to `.github/workflows/mobile-ci.yml`):

```yaml
name: Mobile CI

on: [push, pull_request]

jobs:
  test-and-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: 'stable'
      - name: Install dependencies
        run: flutter pub get
      - name: Run tests
        run: flutter test --coverage
      - name: Build APK (unsigned, for verification)
        env:
          API_BASE_URL: ${{ secrets.PROD_API_BASE_URL }}
        run: |
          flutter build apk --release --dart-define=API_BASE_URL=${{ secrets.PROD_API_BASE_URL }}

Notes:
- This workflow builds an unsigned APK for verification. For Play Store uploads, configure signing (keystore) and only use secrets for sensitive values.
- For iOS builds you must use a macOS runner and configure code signing (certs and provisioning profiles).

If you want, I can:
- Update the example `.env.production.example` to set `API_BASE_URL` to `https://nearpharma-liard.vercel.app`.
- Add the actual workflow file `.github/workflows/mobile-ci.yml` in this repo (I can create it now).

```

