# Checklist para Publicar en Google Play

## ✅ Requisitos Técnicos

### 1. Configuración de la Aplicación
- [x] **Application ID**: `cl.nearpharma.app` (definido en `android/app/build.gradle.kts`)
- [x] **Nombre de la App**: `NearPharma` (definido en `AndroidManifest.xml`)
- [ ] **Versión**: Actualizar en `pubspec.yaml` (actualmente: `1.0.0-beta+20251012`)
  - Para producción, cambiar de `1.0.0-beta` a `1.0.0`
  - El número después del `+` es el `versionCode` (build number)

### 2. Iconos y Assets
- [x] **Icono de la app**: `@mipmap/ic_launcher` configurado
- [ ] **Verificar iconos**: 
  ```bash
  # Ubicación: android/app/src/main/res/
  # Necesitas estos tamaños:
  mipmap-mdpi/ic_launcher.png    (48x48)
  mipmap-hdpi/ic_launcher.png    (72x72)
  mipmap-xhdpi/ic_launcher.png   (96x96)
  mipmap-xxhdpi/ic_launcher.png  (144x144)
  mipmap-xxxhdpi/ic_launcher.png (192x192)
  ```
- [ ] **Splash screen**: Verificar en `android/app/src/main/res/drawable*/`

### 3. Firma de la Aplicación (Signing)
- [x] **Keystore creado**: `android/upload-keystore.jks` existe
- [x] **key.properties configurado**: Archivo existe
- [ ] **Verificar key.properties**: Asegúrate de que tenga estos campos:
  ```properties
  storePassword=tu-contraseña-store
  keyPassword=tu-contraseña-key
  keyAlias=tu-alias
  storeFile=upload-keystore.jks
  ```
- [ ] **IMPORTANTE**: Backup del keystore en lugar seguro (si lo pierdes, no podrás actualizar la app)

### 4. Permisos
- [x] **INTERNET**: Configurado (requerido para API)
- [x] **ACCESS_FINE_LOCATION**: Configurado (buscar farmacias cercanas)
- [x] **ACCESS_COARSE_LOCATION**: Configurado (ubicación aproximada)
- [ ] **Verificar que la app solicite permisos correctamente en tiempo de ejecución**

### 5. Build Release
Ejecutar estos comandos:

```bash
# 1. Limpiar builds anteriores
flutter clean

# 2. Obtener dependencias
flutter pub get

# 3. Construir APK de release (para pruebas)
flutter build apk --release

# 4. Construir App Bundle (REQUERIDO para Google Play)
flutter build appbundle --release
```

El archivo generado estará en:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- App Bundle: `build/app/outputs/bundle/release/app-release.aab`

**IMPORTANTE**: Google Play requiere el formato **App Bundle (.aab)**, NO APK

---

## 📱 Requisitos de Google Play Console

### 6. Cuenta de Desarrollador
- [ ] **Cuenta de Google Play Console** ($25 USD único pago)
- [ ] **Completar perfil de desarrollador**
- [ ] **Verificar identidad** (puede requerir documentos)

### 7. Crear Nueva Aplicación
1. [ ] Ir a [Google Play Console](https://play.google.com/console)
2. [ ] Click en "Crear aplicación"
3. [ ] Completar información:
   - **Nombre**: NearPharma
   - **Idioma predeterminado**: Español (Chile) o Español (Latinoamérica)
   - **Tipo**: Aplicación o juego → Aplicación
   - **Gratuita o de pago**: Gratuita
4. [ ] Aceptar declaraciones

### 8. Ficha de Play Store

#### Descripción Corta (80 caracteres máx)
```
Encuentra farmacias de turno cercanas en Chile de forma rápida y fácil
```

#### Descripción Completa (4000 caracteres máx)
```
NearPharma te ayuda a encontrar farmacias de turno y de urgencia en Chile.

🏥 CARACTERÍSTICAS PRINCIPALES:
• Búsqueda por región y comuna
• Farmacias de turno actualizadas
• Horarios de atención detallados
• Información de contacto
• Direcciones y cómo llegar

📍 ENCUENTRA FARMACIAS CERCANAS:
Busca farmacias por:
- Región
- Comuna
- Fecha de turno
- Farmacias de urgencia

⏰ HORARIOS ACTUALIZADOS:
Consulta los horarios de turno y atención regular de cada farmacia.

📞 INFORMACIÓN COMPLETA:
- Nombre y dirección de la farmacia
- Teléfono de contacto
- Horarios de atención
- Cómo llegar (integración con mapas)

✨ INTERFAZ SIMPLE Y RÁPIDA:
Diseño intuitivo que te permite encontrar lo que necesitas en segundos.

🇨🇱 DATOS OFICIALES:
Información proveniente directamente del Ministerio de Salud de Chile (MINSAL).

Descarga NearPharma y encuentra la farmacia que necesitas cuando la necesitas.
```

#### Recursos Gráficos (REQUERIDOS)
- [ ] **Icono de la app**: 512x512 px (PNG con transparencia)
- [ ] **Gráfico de funciones**: 1024x500 px (JPG o PNG)
- [ ] **Capturas de pantalla del teléfono**: 
  - Mínimo 2, máximo 8
  - 16:9 o 9:16
  - Mínimo: 320px
  - Máximo: 3840px
  - Recomendado: Captura la app mostrando:
    1. Pantalla principal con búsqueda
    2. Lista de farmacias
    3. Detalle de farmacia con horarios
    4. Selección de región/comuna

#### Recursos Opcionales pero Recomendados
- [ ] **Video promocional**: Hasta 30 segundos (YouTube)
- [ ] **Capturas tablet 7"**: Si soportas tablets
- [ ] **Capturas tablet 10"**: Si soportas tablets

### 9. Categorización
- [ ] **Categoría**: Medicina
- [ ] **Tags**: farmacia, salud, turno, urgencia, chile
- [ ] **Clasificación de contenido**: Completar cuestionario (probablemente "Para todos")

### 10. Información de Contacto
- [ ] **Sitio web**: (si tienes uno)
- [ ] **Correo electrónico**: Tu email de contacto
- [ ] **Teléfono**: (opcional)
- [ ] **Dirección física**: (opcional, pero recomendado)

### 11. Política de Privacidad
**MUY IMPORTANTE**: Google Play REQUIERE política de privacidad si:
- Solicitas permisos sensibles (ubicación ✅)
- Recopilas datos del usuario

- [ ] **Crear política de privacidad** que incluya:
  - Qué datos recopilas (ubicación)
  - Para qué los usas (encontrar farmacias cercanas)
  - Cómo los proteges
  - Con quién los compartes (MINSAL API)
  - Derechos del usuario

- [ ] **Publicar política en web** (puede ser GitHub Pages, tu sitio, etc.)
- [ ] **Agregar URL en Play Console**

#### Ejemplo de Política de Privacidad Simple:

```markdown
# Política de Privacidad - NearPharma

Última actualización: [FECHA]

## Recopilación de Datos
NearPharma solicita acceso a tu ubicación únicamente para:
- Encontrar farmacias cercanas a ti
- Ordenar resultados por proximidad

## Uso de Datos
- Tu ubicación NO se almacena en nuestros servidores
- Los datos de ubicación se procesan localmente en tu dispositivo
- Se envían únicamente las coordenadas necesarias a la API del MINSAL

## Permisos
- **Ubicación**: Para buscar farmacias cercanas
- **Internet**: Para obtener información actualizada de farmacias

## Terceros
Obtenemos información de farmacias desde:
- API oficial del Ministerio de Salud de Chile (MINSAL)

## Contacto
Para consultas: [TU EMAIL]
```

### 12. Declaración de Seguridad de Datos
- [ ] **Completar formulario de seguridad de datos**:
  - ¿Recopilas datos de ubicación? → Sí
  - ¿Es obligatorio? → No (opcional)
  - ¿Los compartes con terceros? → Sí (MINSAL API)
  - ¿El usuario puede solicitar eliminación? → No aplica (no se almacenan)
  - ¿Cifras datos en tránsito? → Sí (HTTPS)

### 13. Pruebas Internas/Cerradas (Opcional pero Recomendado)
Antes de lanzamiento público:

- [ ] **Crear pista de prueba interna**
- [ ] **Agregar testers** (email de Google)
- [ ] **Probar la app** por 1-2 semanas
- [ ] **Corregir bugs encontrados**

### 14. Preparar Release de Producción
- [ ] **Subir app-release.aab**
- [ ] **Configurar países**: Chile (o más países si quieres)
- [ ] **Revisar todas las advertencias**
- [ ] **Completar cuestionarios obligatorios**

### 15. Enviar a Revisión
- [ ] Click en "Enviar a revisión"
- [ ] Esperar aprobación (usualmente 1-3 días, puede ser hasta 7 días)
- [ ] Revisar feedback de Google si rechazan

---

## 🚀 Comandos Útiles

```bash
# Verificar que el build funciona correctamente
flutter build appbundle --release --verbose

# Ver información del bundle
unzip -l build/app/outputs/bundle/release/app-release.aab

# Probar release localmente (instalar desde archivo)
flutter install --release

# Ver versión compilada
flutter --version
```

---

## ⚠️ Problemas Comunes

### Error: "Upload key not configured"
**Solución**: Verifica que `key.properties` existe y está correctamente configurado

### Error: "Version code already exists"
**Solución**: Incrementa el número después del `+` en `pubspec.yaml`
```yaml
version: 1.0.0+2  # Cambia el último número
```

### Error: "Icon not found"
**Solución**: Genera iconos con:
```bash
# Opción 1: Usar flutter_launcher_icons package
# Opción 2: Generarlos manualmente en las carpetas mipmap-*
```

### Error: "Missing privacy policy"
**Solución**: Crea y sube tu política de privacidad a un sitio web público

---

## 📋 Checklist Final Antes de Publicar

- [ ] ✅ App funciona correctamente en modo release
- [ ] ✅ Todos los permisos están justificados
- [ ] ✅ Política de privacidad publicada
- [ ] ✅ Capturas de pantalla listas
- [ ] ✅ Descripción completa y atractiva
- [ ] ✅ Icono de alta calidad
- [ ] ✅ Gráfico de funciones creado
- [ ] ✅ Versión correcta en pubspec.yaml
- [ ] ✅ App Bundle generado (.aab)
- [ ] ✅ Keystore respaldado en lugar seguro
- [ ] ✅ Información de contacto completa
- [ ] ✅ Categoría y tags correctos
- [ ] ✅ Clasificación de contenido completada
- [ ] ✅ Declaración de seguridad de datos completada

---

## 📞 Soporte

Si tienes problemas durante el proceso:
1. Revisa la [documentación oficial de Flutter](https://docs.flutter.dev/deployment/android)
2. Consulta el [Centro de ayuda de Google Play](https://support.google.com/googleplay/android-developer)
3. Revisa este checklist punto por punto

¡Buena suerte con tu publicación! 🎉
