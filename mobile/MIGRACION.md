# Guía de Migración: De Backend Intermediario a API Directa

Esta guía te ayudará a migrar tu app de Flutter para conectarse directamente a la API de Farmanet, eliminando el backend intermediario.

---

## 📋 Pre-requisitos

Antes de migrar, asegúrate de tener instalado:

```yaml
# pubspec.yaml
dependencies:
  http: ^1.1.0
  shared_preferences: ^2.2.0  # Para caché local
  flutter_dotenv: ^5.1.0
```

Ejecuta:
```bash
flutter pub get
```

---

## 🚀 Paso 1: Probar Conexión Directa

Primero verifica que la conexión directa funciona:

```bash
flutter test test/direct_api_test.dart
```

**Resultado esperado:**
- ✅ Todos los tests pasan
- ✅ Latencia < 500ms
- ✅ Caché funciona (segunda llamada 10x+ más rápida)

---

## 🔄 Paso 2: Migración Progresiva

### Opción A: Migración Completa (Recomendado para nueva implementación)

**1. Crear instancia del nuevo servicio en `main.dart`:**

```dart
// En TipoFarmaciaScreenState

// ANTES:
String get apiBase {
  return dotenv.env['API_BASE_URL'] ?? 'http://localhost:3001';
}

// DESPUÉS:
PharmacyService get pharmacyService {
  final api = ApiClientDirect();
  return PharmacyService(api);
}
```

**2. Actualizar llamadas a la API:**

```dart
// ANTES:
final client = ApiClient(baseUrl: apiBase);
final res = await client.postForm({'func': 'regiones'});
final data = jsonDecode(res.body);

// DESPUÉS:
final regions = await pharmacyService.getRegions();
```

### Opción B: Migración Gradual (Recomendado para app en producción)

**1. Agregar flag de feature:**

```dart
// lib/config/features.dart
class FeatureFlags {
  static const bool USE_DIRECT_API = false; // Cambiar a true cuando esté listo
}
```

**2. Usar lógica condicional:**

```dart
if (FeatureFlags.USE_DIRECT_API) {
  // Usar nueva implementación
  final regions = await pharmacyService.getRegions();
} else {
  // Usar implementación actual
  final client = ApiClient(baseUrl: apiBase);
  final res = await client.postForm({'func': 'regiones'});
  final data = jsonDecode(res.body);
}
```

**3. Testing A/B:**
- Lanzar versión con flag en `false`
- Monitorear errores
- Cambiar flag a `true` en siguiente versión
- Si todo funciona, eliminar código viejo

---

## 📦 Paso 3: Agregar Assets de Fallback (Opcional pero Recomendado)

### 3.1 Crear archivos de datos estáticos

```bash
mkdir -p assets/data
```

### 3.2 Obtener regiones y guardarlas

```bash
# Ejecutar este script una vez para generar los assets
flutter test test/generate_fallback_assets.dart
```

**O manualmente:**

```dart
// tools/generate_assets.dart
import 'dart:io';
import 'package:mobile/api_client_direct.dart';
import 'dart:convert';

void main() async {
  final api = ApiClientDirect();
  
  // Obtener regiones
  print('Obteniendo regiones...');
  final regions = await api.getRegions();
  await File('assets/data/regiones.json').writeAsString(
    JsonEncoder.withIndent('  ').convert(regions)
  );
  print('✅ Guardadas ${regions.length} regiones');
  
  // Obtener todas las comunas
  print('Obteniendo comunas...');
  final allCommunes = <String, List<Map<String, dynamic>>>{};
  
  for (final region in regions) {
    final regionId = region['id'].toString();
    final communes = await api.getCommunes(regionId);
    allCommunes[regionId] = communes;
    print('  ✅ Región $regionId: ${communes.length} comunas');
  }
  
  await File('assets/data/comunas.json').writeAsString(
    JsonEncoder.withIndent('  ').convert(allCommunes)
  );
  print('✅ Guardadas comunas de todas las regiones');
  
  api.close();
  print('\n🎉 Assets generados exitosamente en assets/data/');
}
```

Ejecutar:
```bash
dart run tools/generate_assets.dart
```

### 3.3 Registrar assets en pubspec.yaml

```yaml
flutter:
  assets:
    - assets/data/regiones.json
    - assets/data/comunas.json
```

---

## 🧪 Paso 4: Testing Exhaustivo

### 4.1 Tests Unitarios

```bash
flutter test test/direct_api_test.dart
```

### 4.2 Tests de Integración

```bash
# Test completo del flujo de la app
flutter test test/integration_test.dart
```

### 4.3 Tests Manuales

**Checklist:**
- [ ] Abrir app sin internet → Debería usar assets de fallback
- [ ] Buscar farmacias por región → Funciona
- [ ] Buscar farmacias por comuna → Funciona
- [ ] Cambiar filtro de fecha → Funciona
- [ ] Ver detalles de farmacia → Funciona
- [ ] Obtener ubicación actual → Funciona
- [ ] Ordenar por distancia → Funciona
- [ ] Segunda búsqueda más rápida (caché) → Funciona

---

## 📊 Paso 5: Monitoreo y Métricas

### 5.1 Agregar logging de performance

```dart
// lib/services/pharmacy_service.dart

Future<List<Map<String, dynamic>>> getRegions() async {
  final stopwatch = Stopwatch()..start();
  
  try {
    final cached = await CacheService.getCachedRegions();
    if (cached != null) {
      stopwatch.stop();
      _logPerformance('getRegions', 'cache', stopwatch.elapsedMilliseconds);
      return cached;
    }
    
    final regions = await _api.getRegions();
    await CacheService.cacheRegions(regions);
    
    stopwatch.stop();
    _logPerformance('getRegions', 'api', stopwatch.elapsedMilliseconds);
    
    return regions;
  } catch (e) {
    stopwatch.stop();
    _logPerformance('getRegions', 'error', stopwatch.elapsedMilliseconds);
    rethrow;
  }
}

void _logPerformance(String method, String source, int milliseconds) {
  AppLogger.i('⚡ Performance: $method from $source took ${milliseconds}ms');
  
  // Opcional: Enviar a Firebase Analytics, Sentry, etc.
  // FirebaseAnalytics.instance.logEvent(
  //   name: 'api_performance',
  //   parameters: {
  //     'method': method,
  //     'source': source,
  //     'duration_ms': milliseconds,
  //   },
  // );
}
```

### 5.2 Agregar error tracking

```dart
try {
  final regions = await pharmacyService.getRegions();
} catch (e, st) {
  // Log a Sentry, Firebase Crashlytics, etc.
  // FirebaseCrashlytics.instance.recordError(e, st);
  
  // Mostrar mensaje al usuario
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error al cargar regiones. Usando datos locales.')),
  );
}
```

---

## 🔥 Paso 6: Eliminar Backend (Solo después de validar)

**IMPORTANTE:** Solo hacer esto después de:
1. ✅ Nueva versión publicada y funcionando
2. ✅ Al menos 90% de usuarios en nueva versión
3. ✅ Sin errores críticos reportados
4. ✅ Métricas de performance confirmadas

### 6.1 Eliminar código viejo

```dart
// Eliminar estos archivos:
// - lib/api_client.dart (viejo)

// Renombrar:
// - api_client_direct.dart → api_client.dart
```

### 6.2 Actualizar .env

```bash
# .env

# ANTES:
API_BASE_URL=https://nearpharma-backend.vercel.app

# DESPUÉS (no necesario, pero puedes dejarlo para debugging):
# API_BASE_URL no se usa más
FARMANET_BASE_URL=https://midas.minsal.cl/farmacia_v2
```

### 6.3 Eliminar backend de Vercel

```bash
# Solo cuando estés 100% seguro
# 1. Hacer backup del código
# 2. Eliminar deployment en Vercel
# 3. Eliminar repositorio (opcional)
```

---

## 📈 Comparación de Performance

### Antes (Con Backend Intermediario)

```
Usuario → Backend Vercel (100ms) → API Farmanet (150ms) = 250ms
        ← Backend Vercel (100ms) ← API Farmanet (150ms) = 250ms
Total: ~500ms
```

### Después (Directo + Caché)

```
Primera vez:
Usuario → API Farmanet (150ms) = 150ms
        ← API Farmanet (150ms) = 150ms
Total: ~300ms (40% más rápido)

Segunda vez (caché):
Usuario → Caché Local (5ms) = 5ms
Total: ~5ms (100x más rápido)
```

### Ahorro de Costos

```
Backend Vercel:
- Hosting: $0-20/mes (según uso)
- Mantenimiento: 2-4 horas/mes
- Total anual: $0-240 + tiempo

Sin Backend:
- Hosting: $0
- Mantenimiento: 0 horas
- Total anual: $0
```

---

## ⚠️ Troubleshooting

### Problema: "Error de conexión"

**Causa:** API de Farmanet caída o cambió
**Solución:** 
1. Verificar si API está disponible
2. Usar assets de fallback
3. Notificar al usuario

```dart
try {
  final regions = await pharmacyService.getRegions();
} catch (e) {
  // Usar fallback automáticamente
  final regions = await pharmacyService._loadRegionsFromAssets();
  
  // Notificar al usuario
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Usando datos locales (sin conexión)')),
  );
}
```

### Problema: "Datos desactualizados en caché"

**Causa:** Caché no se invalida
**Solución:** Agregar botón de "Refrescar"

```dart
// En la UI
IconButton(
  icon: Icon(Icons.refresh),
  onPressed: () async {
    await pharmacyService.clearCache();
    await _loadData(); // Recargar datos
  },
)
```

### Problema: "App muy lenta sin internet"

**Causa:** No tienes assets de fallback
**Solución:** Generar assets (Paso 3)

---

## ✅ Checklist Final

- [ ] Tests unitarios pasan
- [ ] Tests de integración pasan
- [ ] Assets de fallback generados
- [ ] App funciona sin internet
- [ ] Performance mejorado (medido)
- [ ] Error handling implementado
- [ ] Logging agregado
- [ ] Versión beta testeada
- [ ] Usuarios contentos 😊
- [ ] Backend viejo eliminado

---

## 🎉 ¡Listo!

Tu app ahora:
- ✅ Es más rápida (40% en primera carga, 100x con caché)
- ✅ Es más simple (menos código)
- ✅ Cuesta menos (sin backend)
- ✅ Es más resiliente (fallbacks)
- ✅ Funciona offline (assets locales)

---

## 📚 Referencias

- [Documentación API Farmanet](https://midas.minsal.cl/farmacia_v2/WS/)
- [Flutter HTTP Package](https://pub.dev/packages/http)
- [SharedPreferences](https://pub.dev/packages/shared_preferences)
- [ARQUITECTURA_DIRECTA.md](./ARQUITECTURA_DIRECTA.md)

---

¿Preguntas? Abre un issue o contacta al equipo de desarrollo.
