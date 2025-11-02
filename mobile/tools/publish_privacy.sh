#!/bin/bash

# Script para publicar política de privacidad en GitHub Pages

echo "📄 Configurando repositorio para GitHub Pages..."

# Crear directorio temporal
mkdir -p /tmp/nearpharma-privacy
cd /tmp/nearpharma-privacy

# Inicializar git
git init

# Copiar y renombrar el archivo HTML
cp /home/mvpdvlp/Documents/Projects/apps/BuscaFarmacia/mobile/privacy_policy.html index.html

# Agregar archivo
git add index.html

# Commit inicial
git commit -m "Add privacy policy"

echo ""
echo "✅ Repositorio local creado"
echo ""
echo "📋 Ahora ejecuta estos comandos:"
echo ""
echo "1. Crea un nuevo repositorio en GitHub llamado 'nearpharma-privacy' (público)"
echo "2. Luego ejecuta:"
echo ""
echo "   cd /tmp/nearpharma-privacy"
echo "   git branch -M main"
echo "   git remote add origin https://github.com/TU_USUARIO/nearpharma-privacy.git"
echo "   git push -u origin main"
echo ""
echo "3. En GitHub, ve a Settings → Pages → Source: 'main' branch → Save"
echo ""
echo "4. Tu política estará disponible en:"
echo "   https://TU_USUARIO.github.io/nearpharma-privacy/"
