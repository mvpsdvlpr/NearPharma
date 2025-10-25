// Vercel serverless function at root level
// This file handles all API requests for the backend

try {
  // Require the compiled backend app
  const app = require('../backend/dist/app');
  
  // Export the Express app for Vercel
  module.exports = app && app.default ? app.default : app;
} catch (error) {
  console.error('Error loading backend app:', error);
  
  // Fallback handler if compilation fails
  module.exports = (req, res) => {
    res.status(500).json({ 
      error: 'Backend compilation failed',
      message: 'Run `npm run vercel-build` to compile the backend',
      details: error.message
    });
  };
}