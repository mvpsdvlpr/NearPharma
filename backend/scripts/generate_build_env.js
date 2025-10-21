const fs = require('fs');
const path = require('path');

function envVal(k, fallback) {
  if (process.env[k]) return process.env[k];
  return fallback;
}

const out = {
  VERCEL_GIT_COMMIT_SHA: envVal('VERCEL_GIT_COMMIT_SHA', envVal('GIT_COMMIT_SHA', '')),
  VERCEL_GIT_COMMIT_REF: envVal('VERCEL_GIT_COMMIT_REF', envVal('GIT_BRANCH', '')),
  BUILD_TIME: envVal('BUILD_TIME', new Date().toISOString()),
  RELEASE_CHANNEL: envVal('RELEASE_CHANNEL', 'stable'),
};

// Only write expected keys and avoid any other env leaking
const allowedKeys = ['VERCEL_GIT_COMMIT_SHA', 'VERCEL_GIT_COMMIT_REF', 'BUILD_TIME', 'RELEASE_CHANNEL'];
const contents = allowedKeys.map(k => `${k}=${String(out[k] || '').replace(/\r?\n/g, '')}`).join('\n') + '\n';
const dest = path.resolve(__dirname, '..', '.env.build');
fs.writeFileSync(dest, contents, { encoding: 'utf8', mode: 0o600 });
console.log('[generate_build_env] wrote', dest);
