
// Load environment variables: prefer build-generated .env.build
const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');
const buildEnv = path.resolve(__dirname, '..', '.env.build');
if (fs.existsSync(buildEnv)) {
  dotenv.config({ path: buildEnv });
} else {
  dotenv.config();
}
import app from './app';

const PORT = process.env.PORT || 3001;

// In serverless environments (Vercel) we should NOT call listen();
// Vercel will import the app and handle HTTP invocation. Only start
// a listener when running locally (e.g. npm start).
if (!process.env.VERCEL) {
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
} else {
  console.log('Running in Vercel environment; skipping app.listen');
}
