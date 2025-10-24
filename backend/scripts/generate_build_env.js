const fs = require('fs');
const path = require('path');

function envVal(k, fallback) {
    if (process.env[k]) return process.env[k];
    return fallback;
}

// Build the output object with a visible RELEASE_CHANNEL inference step so
// CI logs show what channel was chosen.
const inferredChannel = (function() {
    if (process.env.RELEASE_CHANNEL) return { value: process.env.RELEASE_CHANNEL, source: 'env' };
    const vercelEnv = process.env.VERCEL_ENV;
    if (vercelEnv === 'production') return { value: 'stable', source: 'VERCEL_ENV=production' };
    if (vercelEnv === 'preview') return { value: 'preview', source: 'VERCEL_ENV=preview' };
    if (vercelEnv === 'development') return { value: 'development', source: 'VERCEL_ENV=development' };
    const ref = envVal('VERCEL_GIT_COMMIT_REF', envVal('GIT_BRANCH', '')).toLowerCase();
    if (!ref) return { value: 'stable', source: 'no-ref-fallback' };
    if (ref === 'main' || ref === 'master' || ref.startsWith('release/')) return { value: 'stable', source: `ref=${ref}` };
    return { value: 'preview', source: `ref=${ref}` };
})();

const out = {
    VERCEL_GIT_COMMIT_SHA: envVal('VERCEL_GIT_COMMIT_SHA', envVal('GIT_COMMIT_SHA', '')),
    VERCEL_GIT_COMMIT_REF: envVal('VERCEL_GIT_COMMIT_REF', envVal('GIT_BRANCH', '')),
    BUILD_TIME: envVal('BUILD_TIME', new Date().toISOString()),
    RELEASE_CHANNEL: inferredChannel.value,
};

console.log('[generate_build_env] RELEASE_CHANNEL ->', out.RELEASE_CHANNEL, '(source:', inferredChannel.source + ')');

// Only write expected keys and avoid any other env leaking
const allowedKeys = ['VERCEL_GIT_COMMIT_SHA', 'VERCEL_GIT_COMMIT_REF', 'BUILD_TIME', 'RELEASE_CHANNEL'];
const contents = allowedKeys.map(k => `${k}=${String(out[k] || '').replace(/\r?\n/g, '')}`).join('\n') + '\n';
const dest = path.resolve(__dirname, '..', '.env.build');
fs.writeFileSync(dest, contents, { encoding: 'utf8', mode: 0o600 });
console.log('[generate_build_env] wrote', dest);
