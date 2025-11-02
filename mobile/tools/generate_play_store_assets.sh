#!/bin/bash

# Script para generar recursos gráficos para Google Play Store
# Requiere ImageMagick instalado: sudo apt install imagemagick

OUTPUT_DIR="screenshots/google-play/assets"
mkdir -p "$OUTPUT_DIR"

echo "🎨 Generando recursos gráficos para Google Play..."

# 1. Icono de alta resolución (512x512)
if command -v convert &> /dev/null; then
    echo "📱 Generando icono de alta resolución (512x512)..."
    convert android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png \
        -resize 512x512 \
        -background none \
        -gravity center \
        -extent 512x512 \
        "$OUTPUT_DIR/ic_launcher_512.png"
    echo "✅ Icono creado: $OUTPUT_DIR/ic_launcher_512.png"
else
    echo "⚠️  ImageMagick no está instalado. Instala con: sudo apt install imagemagick"
    echo "   Mientras tanto, puedes redimensionar manualmente el icono a 512x512px"
fi

# 2. Feature Graphic placeholder (1024x500)
# Este necesita diseño personalizado, creamos un template básico
if command -v convert &> /dev/null; then
    echo "🎨 Generando plantilla de Feature Graphic (1024x500)..."
    
    # Crear un fondo con gradiente básico
    convert -size 1024x500 \
        gradient:'#4CAF50-#2196F3' \
        "$OUTPUT_DIR/feature_graphic_template.png"
    
    # Agregar el icono en el centro
    convert "$OUTPUT_DIR/feature_graphic_template.png" \
        "$OUTPUT_DIR/ic_launcher_512.png" \
        -geometry 300x300+50+100 \
        -composite \
        "$OUTPUT_DIR/feature_graphic_template.png"
    
    echo "✅ Plantilla de Feature Graphic creada: $OUTPUT_DIR/feature_graphic_template.png"
    echo "   ⚠️  IMPORTANTE: Esta es solo una plantilla básica."
    echo "   Deberías personalizarla con un diseñador o herramienta como Canva/Figma"
fi

echo ""
echo "📦 Resumen de archivos generados:"
ls -lh "$OUTPUT_DIR"

echo ""
echo "📋 Próximos pasos:"
echo "   1. Copia tus capturas de pantalla a: screenshots/google-play/"
echo "   2. Revisa y personaliza el Feature Graphic en: $OUTPUT_DIR/feature_graphic_template.png"
echo "   3. El icono de 512x512 está en: $OUTPUT_DIR/ic_launcher_512.png"
echo ""
echo "🎯 Requisitos de Google Play:"
echo "   - Capturas: mínimo 2, máximo 8 (JPEG/PNG 24-bit)"
echo "   - Icono: 512x512px (PNG 32-bit con alfa)"
echo "   - Feature Graphic: 1024x500px (JPEG/PNG 24-bit)"
