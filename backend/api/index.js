// Handler para Vercel (usa el artefacto compilado en backend/dist)
// Asegúrate de ejecutar `npm run build` en backend antes de desplegar.
try {
  // CommonJS require of the compiled app
  const app = require('../dist/app');
  module.exports = app && app.default ? app.default : app;
} catch (e) {
  // Si dist no existe, exportamos un handler explicativo para que el deploy falle con mensaje claro
  module.exports = (req, res) => {
    res.statusCode = 500;
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ error: 'Dist not built. Run `cd backend && npm run build` before deploy.' }));
  };
}
