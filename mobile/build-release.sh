#!/bin/bash

# Script para construir la aplicación para Google Play
# Ejecutar con: bash build-release.sh

set -e  # Detener si hay errores

echo "🚀 Iniciando build para Google Play..."
echo ""

# 1. Limpiar builds anteriores
echo "🧹 Limpiando builds anteriores..."
flutter clean

# 2. Obtener dependencias
echo "📦 Obteniendo dependencias..."
flutter pub get

# 3. Verificar que key.properties existe
if [ ! -f "android/key.properties" ]; then
    echo "❌ ERROR: android/key.properties no encontrado"
    echo "   Copia android/key.properties.template y completa los valores"
    exit 1
fi

# 4. Verificar que el keystore existe
KEYSTORE=$(grep "storeFile=" android/key.properties | cut -d'=' -f2)
if [ ! -f "android/$KEYSTORE" ]; then
    echo "❌ ERROR: Keystore no encontrado en android/$KEYSTORE"
    exit 1
fi

echo "✅ Keystore encontrado: android/$KEYSTORE"
echo ""

# 5. Construir App Bundle (requerido para Google Play)
echo "🏗️  Construyendo App Bundle (.aab)..."
flutter build appbundle --release

# 6. Construir APK (opcional, para pruebas locales)
echo "🏗️  Construyendo APK (.apk)..."
flutter build apk --release

echo ""
echo "✅ Build completado exitosamente!"
echo ""
echo "📦 Archivos generados:"
echo "   - App Bundle (para Google Play):"
echo "     build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "   - APK (para pruebas locales):"
echo "     build/app/outputs/apk/release/app-release.apk"
echo ""
echo "🎉 Puedes subir el archivo .aab a Google Play Console"
echo ""

# Mostrar información del bundle
echo "📊 Información del App Bundle:"
ls -lh build/app/outputs/bundle/release/app-release.aab
echo ""

# Verificar versión
VERSION=$(grep "^version:" pubspec.yaml | cut -d':' -f2 | xargs)
echo "📌 Versión de la app: $VERSION"
echo ""

echo "⚠️  RECORDATORIO:"
echo "   1. Backup del keystore en lugar seguro"
echo "   2. Verificar política de privacidad publicada"
echo "   3. Preparar capturas de pantalla"
echo "   4. Revisar descripción en Play Store"
echo ""
