# ✅ Checklist Final para Google Play - NearPharma

## Estado Actual: Lista para Build

---

## 📋 PASO 1: Preparar la Versión para Producción

### 1.1 Actualizar Versión (CRÍTICO)
- [ ] **Cambiar versión de beta a producción**

Edita `pubspec.yaml`:
```yaml
# Cambiar de:
version: 1.0.0-beta+20251012

# A:
version: 1.0.0+1
```

**Explicación:**
- `1.0.0` = Versión visible para usuarios (versionName)
- `+1` = Código interno de build (versionCode) - incrementar con cada actualización

---

## 📋 PASO 2: Verificar Configuración de Firma

### 2.1 Keystore (✅ Ya configurado)
```bash
# Verificar que existe
ls -la android/upload-keystore.jks
ls -la android/key.properties
```

**IMPORTANTE:** 
- ⚠️ Hacer backup del keystore en 3 lugares seguros
- ⚠️ Si pierdes el keystore, NO podrás actualizar la app jamás
- ⚠️ NO subir a GitHub ni compartir públicamente

Ubicaciones sugeridas para backup:
1. Google Drive / Dropbox (cifrado)
2. Disco duro externo
3. USB cifrado

### 2.2 Verificar key.properties
```bash
cat android/key.properties
```

Debe contener:
```properties
storePassword=nearpharma2024
keyPassword=nearpharma2024
keyAlias=upload
storeFile=upload-keystore.jks
```

✅ **VERIFICADO**

---

## 📋 PASO 3: Construir la Aplicación

### 3.1 Limpiar y Construir
```bash
# Dar permisos al script
chmod +x build-release.sh

# Ejecutar build
./build-release.sh
```

O manualmente:
```bash
# Limpiar
flutter clean

# Obtener dependencias
flutter pub get

# Construir App Bundle (REQUERIDO para Google Play)
flutter build appbundle --release

# Construir APK (opcional, para pruebas)
flutter build apk --release
```

### 3.2 Ubicación de archivos generados
- **App Bundle (subir a Google Play):** 
  ```
  build/app/outputs/bundle/release/app-release.aab
  ```
- **APK (pruebas locales):** 
  ```
  build/app/outputs/apk/release/app-release.apk
  ```

### 3.3 Verificar que el build funciona
```bash
# Instalar APK en dispositivo para probar
flutter install --release

# O instalar manualmente
adb install build/app/outputs/apk/release/app-release.apk
```

**Pruebas mínimas:**
- [ ] App abre correctamente
- [ ] Permisos de ubicación se solicitan
- [ ] Búsqueda de farmacias funciona
- [ ] Mapa abre correctamente
- [ ] No hay crashes

---

## 📋 PASO 4: Recursos Gráficos para Play Store

### 4.1 REQUERIDOS (sin estos NO puedes publicar)

#### 🎨 Icono de la aplicación (512x512 px)
- [ ] Crear icono PNG de 512x512 px
- [ ] Fondo opaco o transparente (recomendado transparente)
- [ ] Sin bordes/padding adicional (Google añade el "safe zone")

**Herramientas:**
- [Android Asset Studio](https://romannurik.github.io/AndroidAssetStudio/icons-launcher.html)
- Figma / Photoshop / GIMP

#### 📱 Capturas de Pantalla (Mínimo 2, Máximo 8)
Requisitos:
- Formato: JPEG o PNG 24-bit
- Dimensiones: 16:9 o 9:16
- Mínimo: 320px en lado corto
- Máximo: 3840px en lado largo
- Sin transparencias

**Capturas sugeridas (tomar desde la app):**
1. [ ] **Pantalla principal** - Muestra búsqueda por fecha/región/comuna
2. [ ] **Lista de farmacias** - Resultados con cards
3. [ ] **Detalle de farmacia** - Card expandida con horarios
4. [ ] **Mapa/ubicación** - Si muestras mapa (opcional)

**Cómo tomar capturas:**
```bash
# Desde dispositivo conectado
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png

# O directamente desde Android Studio / VS Code
```

#### 🖼️ Gráfico de Funciones (Feature Graphic)
- [ ] Crear imagen de 1024 x 500 px
- [ ] Formato: JPEG o PNG 24-bit
- [ ] Debe ser llamativo y mostrar el propósito de la app

**Contenido sugerido:**
```
┌────────────────────────────────────────────┐
│  [Logo]  NearPharma                       │
│                                            │
│  Encuentra farmacias de turno             │
│  en Chile                                  │
│                                            │
│  [Mini screenshot de la app]               │
└────────────────────────────────────────────┘
```

---

## 📋 PASO 5: Textos para Play Store

### 5.1 Título de la aplicación (Máx 50 caracteres)
```
NearPharma - Farmacias de Turno Chile
```
(42 caracteres) ✅

### 5.2 Descripción Corta (Máx 80 caracteres)
```
Encuentra farmacias de turno cercanas en Chile de forma rápida y fácil
```
(70 caracteres) ✅

### 5.3 Descripción Completa (Máx 4000 caracteres)
```markdown
NearPharma te ayuda a encontrar farmacias de turno y de urgencia en todo Chile.

🏥 CARACTERÍSTICAS PRINCIPALES
• Búsqueda por región y comuna
• Farmacias de turno actualizadas diariamente
• Horarios de atención detallados
• Información de contacto y direcciones
• Integración con Google Maps

📍 ENCUENTRA FARMACIAS CERCANAS
Busca farmacias filtrando por:
- Región
- Comuna  
- Fecha de turno
- Tipo (turno o urgencia)

⏰ HORARIOS ACTUALIZADOS
Consulta los horarios de turno y atención regular de cada farmacia.

📞 INFORMACIÓN COMPLETA
Para cada farmacia encuentras:
- Nombre y dirección completa
- Teléfono de contacto
- Horarios de turno
- Horario semanal de atención
- Cómo llegar (integración con mapas)

✨ INTERFAZ SIMPLE Y RÁPIDA
Diseño intuitivo que te permite encontrar lo que necesitas en segundos.

🇨🇱 DATOS OFICIALES
Información actualizada directamente desde el Ministerio de Salud de Chile (MINSAL).

💚 GRATUITA Y SIN PUBLICIDAD
Aplicación completamente gratuita y sin anuncios molestos.

Descarga NearPharma y encuentra la farmacia que necesitas cuando la necesitas.
```

---

## 📋 PASO 6: Política de Privacidad (OBLIGATORIO)

### 6.1 Crear Política de Privacidad

La app solicita ubicación, por lo tanto **DEBES** tener una política de privacidad pública.

**Contenido mínimo:**

```markdown
# Política de Privacidad - NearPharma

**Última actualización:** 2 de noviembre de 2025

## 1. Información que Recopilamos

### Ubicación
NearPharma solicita acceso a tu ubicación para:
- Encontrar farmacias cercanas a tu posición actual
- Ordenar los resultados por proximidad

**Tu ubicación NO se almacena en ningún servidor.**

## 2. Cómo Usamos la Información

- La ubicación se procesa localmente en tu dispositivo
- Solo se envían coordenadas geográficas a la API del MINSAL para obtener farmacias cercanas
- No compartimos tu ubicación con terceros comerciales
- No creamos perfiles de usuario
- No rastreamos tu historial de ubicaciones

## 3. Permisos de la Aplicación

### Ubicación (Opcional)
- **Propósito:** Encontrar farmacias cerca de ti
- **Tipo:** Acceso mientras usas la app
- **¿Es obligatorio?:** No, puedes buscar sin compartir ubicación

### Internet (Requerido)
- **Propósito:** Obtener información actualizada de farmacias desde la API del MINSAL

## 4. Fuentes de Datos

Obtenemos información de farmacias desde:
- API oficial del Ministerio de Salud de Chile (MINSAL)
- URL: https://seremienlinea.minsal.cl/asdigital/mfarmacias/

## 5. Seguridad

- Todas las comunicaciones con servidores usan HTTPS
- No almacenamos datos personales
- No requerimos creación de cuenta

## 6. Cambios en la Política

Cualquier cambio en esta política será notificado mediante actualización de la app.

## 7. Contacto

Para consultas sobre esta política:
- Email: [TU_EMAIL_AQUI]

---

NearPharma es una aplicación independiente y no está afiliada oficialmente con el Ministerio de Salud de Chile.
```

### 6.2 Publicar la Política

**Opciones:**
1. **GitHub Pages** (Gratis y fácil):
   ```bash
   # En tu repositorio, crear archivo docs/privacy-policy.md
   # Activar GitHub Pages en Settings → Pages
   # URL será: https://tu-usuario.github.io/repo/privacy-policy
   ```

2. **Google Sites** (Gratis)
3. **Tu propio sitio web**

- [ ] Política de privacidad creada
- [ ] Política publicada en URL pública
- [ ] URL copiada para Google Play Console

---

## 📋 PASO 7: Completar Google Play Console

### 7.1 Crear Cuenta de Desarrollador
- [ ] Cuenta de Google Play Console ($25 USD pago único)
- [ ] Completar perfil de desarrollador
- [ ] Verificar identidad (puede requerir ID)

### 7.2 Crear Nueva Aplicación
1. [ ] Ir a [Google Play Console](https://play.google.com/console)
2. [ ] "Crear aplicación"
3. [ ] Nombre: **NearPharma**
4. [ ] Idioma predeterminado: **Español (Chile)** o **Español**
5. [ ] Tipo: **Aplicación**
6. [ ] Gratuita o de pago: **Gratuita**

### 7.3 Completar Ficha de Play Store

#### Información Principal
- [ ] Título de la app (del PASO 5.1)
- [ ] Descripción corta (del PASO 5.2)
- [ ] Descripción completa (del PASO 5.3)

#### Recursos Gráficos
- [ ] Icono 512x512
- [ ] Capturas de pantalla (mínimo 2)
- [ ] Gráfico de funciones 1024x500

#### Categorización
- [ ] **Categoría principal:** Medicina
- [ ] **Categoría secundaria:** Salud y bienestar (opcional)
- [ ] **Tags:** farmacia, salud, turno, urgencia, chile, medicamentos

#### Información de Contacto
- [ ] Correo electrónico
- [ ] Sitio web (opcional)
- [ ] Número de teléfono (opcional)

#### Política de Privacidad
- [ ] URL de la política (del PASO 6.2)

### 7.4 Clasificación de Contenido
- [ ] Completar cuestionario
- [ ] Resultado esperado: **Para todos** o **Para mayores de 3 años**

### 7.5 Declaración de Seguridad de Datos

**Datos de ubicación:**
- ¿Recopilas ubicación? → **Sí**
- ¿Es obligatorio? → **No (opcional)**
- ¿La compartes con terceros? → **Sí (API MINSAL para búsqueda)**
- ¿La almacenas? → **No**
- ¿Cifras en tránsito? → **Sí (HTTPS)**

**Otros datos:**
- No recopilas datos de cuenta
- No recopilas datos personales adicionales

### 7.6 Países de Distribución
Opciones:
1. **Solo Chile** (recomendado para inicio)
2. **Todos los países de habla hispana**
3. **Todos los países** (si la info de farmacias es solo Chile, no tiene sentido)

Recomendación: **Solo Chile**

---

## 📋 PASO 8: Subir el App Bundle

### 8.1 Crear Versión de Producción
1. [ ] En Play Console, ir a "Producción"
2. [ ] Click "Crear nueva versión"
3. [ ] Subir `app-release.aab`
4. [ ] Completar "Notas de la versión":
   ```
   Versión inicial de NearPharma:
   - Búsqueda de farmacias de turno en Chile
   - Filtros por región, comuna y fecha
   - Información detallada de horarios
   - Integración con mapas
   - Datos oficiales del MINSAL
   ```

### 8.2 Revisión y Envío
- [ ] Revisar que todos los campos estén completos
- [ ] No debe haber advertencias críticas
- [ ] Click "Revisar versión"
- [ ] Click "Iniciar lanzamiento en producción"

---

## 📋 PASO 9: Después del Envío

### 9.1 Tiempos de Revisión
- **Normal:** 1-3 días
- **Primera app:** Puede tardar hasta 7 días
- **Verificación adicional:** Posible si detectan algo

### 9.2 Si es Rechazada
Google te enviará email con:
- Razón del rechazo
- Qué corregir
- Cómo apelar

**Motivos comunes de rechazo:**
- Falta política de privacidad
- Permisos no justificados
- Contenido inapropiado
- Problemas de funcionalidad

### 9.3 Si es Aprobada
- Recibirás confirmación por email
- App estará visible en Play Store en pocas horas
- Puedes compartir el link: `https://play.google.com/store/apps/details?id=cl.nearpharma.app`

---

## 🚨 CHECKLIST FINAL PRE-ENVÍO

Verifica que TODO esté marcado:

**Técnico:**
- [ ] Versión actualizada a 1.0.0+1 en pubspec.yaml
- [ ] App Bundle generado exitosamente
- [ ] APK probado en dispositivo real
- [ ] App funciona sin crashes
- [ ] Todos los permisos justificados

**Recursos Gráficos:**
- [ ] Icono 512x512 subido
- [ ] Mínimo 2 capturas de pantalla subidas
- [ ] Gráfico de funciones 1024x500 subido

**Textos:**
- [ ] Título completo
- [ ] Descripción corta completa
- [ ] Descripción larga completa
- [ ] Categoría seleccionada
- [ ] Clasificación de contenido completada

**Legal:**
- [ ] Política de privacidad publicada
- [ ] URL de política ingresada
- [ ] Declaración de seguridad completada
- [ ] Información de contacto completa

**Play Console:**
- [ ] Todas las secciones con ✅ verde
- [ ] Sin advertencias críticas
- [ ] Países de distribución seleccionados

---

## 📞 Comandos Útiles

```bash
# Ver versión actual
grep "^version:" pubspec.yaml

# Construir release
flutter build appbundle --release

# Instalar y probar
flutter install --release

# Ver tamaño del bundle
ls -lh build/app/outputs/bundle/release/app-release.aab

# Verificar firma
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

---

## ✅ Próximos Pasos

1. [ ] Actualizar versión en `pubspec.yaml`
2. [ ] Ejecutar `./build-release.sh`
3. [ ] Probar APK en dispositivo
4. [ ] Crear recursos gráficos
5. [ ] Crear y publicar política de privacidad
6. [ ] Completar Google Play Console
7. [ ] Subir App Bundle
8. [ ] Esperar aprobación

---

**¿Necesitas ayuda con algún paso específico?**

¡Estás muy cerca de publicar tu app! 🎉
