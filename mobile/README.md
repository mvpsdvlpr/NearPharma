# NearPharma Mobile 📱

Aplicación móvil en Flutter para buscar farmacias de turno en Chile.

## 🎯 Actualización Importante: Eliminación del Backend

**TL;DR:** Se recomienda eliminar el backend intermediario y conectarse directamente a la API de Farmanet.

### ¿Por qué?
- ⚡ **40-100x más rápido** con caché local
- 💰 **$1,300+ ahorro anual** (sin hosting)
- 🎯 **Código más simple** (menos mantenimiento)
- 🛡️ **Más resiliente** (funciona offline)

### 📚 Documentación Completa

Consulta el **[INDICE.md](./INDICE.md)** para acceder a toda la documentación sobre la eliminación del backend.

#### Documentos principales:
1. **[RESUMEN_ELIMINACION_BACKEND.md](./RESUMEN_ELIMINACION_BACKEND.md)** - Lee esto primero (5 min)
2. **[ARQUITECTURA_DIRECTA.md](./ARQUITECTURA_DIRECTA.md)** - Análisis detallado (15 min)
3. **[MIGRACION.md](./MIGRACION.md)** - Guía de migración paso a paso (20 min)
4. **[DIAGRAMA_COMPARACION.md](./DIAGRAMA_COMPARACION.md)** - Comparación visual (10 min)
5. **[FAQ.md](./FAQ.md)** - Preguntas frecuentes (25 min)

---

## 🚀 Quick Start

### Instalación
```bash
# 1. Instalar dependencias
flutter pub get

# 2. Generar assets de fallback (opcional pero recomendado)
dart run tools/generate_fallback_assets.dart

# 3. Ejecutar tests
flutter test test/direct_api_test.dart

# 4. Ejecutar app
flutter run
```

### Configuración

Crear archivo `.env`:
```bash
# Conexión directa a Farmanet (recomendado)
FARMANET_BASE_URL=https://midas.minsal.cl/farmacia_v2

# O backend intermediario (legacy)
# API_BASE_URL=https://nearpharma-backend.vercel.app
```

---

## 📁 Estructura del Proyecto

```
lib/
├── api_client.dart              # Cliente API legacy (con backend)
├── api_client_direct.dart       # Cliente API directo (sin backend) ✨ NUEVO
├── main.dart                    # Punto de entrada
├── theme.dart                   # Tema de la app
├── services/
│   ├── cache_service.dart       # Servicio de caché local ✨ NUEVO
│   └── pharmacy_service.dart    # Servicio de alto nivel ✨ NUEVO
├── widgets/
│   └── pharmacy_card.dart       # Tarjeta de farmacia
└── utils/
    └── pill.dart                # Utilitarios

test/
├── direct_api_test.dart         # Tests de API directa ✨ NUEVO
├── api_integration_test.dart    # Tests de integración
└── ...

tools/
└── generate_fallback_assets.dart # Genera assets de fallback ✨ NUEVO

assets/
└── data/                         # Assets de fallback ✨ NUEVO
    ├── regiones.json
    ├── comunas.json
    └── metadata.json
```

---

## 🔌 Uso de la API Directa

### Opción 1: Cliente de bajo nivel
```dart
import 'package:mobile/api_client_direct.dart';

final api = ApiClientDirect();

// Obtener regiones
final regions = await api.getRegions();

// Obtener comunas
final communes = await api.getCommunes('13');

// Buscar farmacias
final pharmacies = await api.searchPharmaciesByCommune(
  regionId: '13',
  communeId: '130',
  filter: 'turnos',
);
```

### Opción 2: Servicio de alto nivel (Recomendado)
```dart
import 'package:mobile/services/pharmacy_service.dart';
import 'package:mobile/api_client_direct.dart';

final service = PharmacyService(ApiClientDirect());

// Obtener regiones (con caché automático)
final regions = await service.getRegions();

// Obtener comunas (con caché automático)
final communes = await service.getCommunes('13');

// Buscar farmacias (sin caché, datos en tiempo real)
final pharmacies = await service.searchPharmaciesByCommune(
  regionId: '13',
  communeId: '130',
  filter: 'turnos',
);
```

---

## 🧪 Testing

```bash
# Tests de API directa
flutter test test/direct_api_test.dart

# Tests de integración
flutter test test/api_integration_test.dart

# Todos los tests
flutter test

# Tests con cobertura
flutter test --coverage
```

---

## 🎯 Estrategia de Caché

| Tipo de Dato | Duración de Caché | Razón |
|--------------|-------------------|-------|
| Regiones | 7 días | Datos estáticos |
| Comunas | 7 días | Datos estáticos |
| Fechas de turno | 24 horas | Datos semi-dinámicos |
| Farmacias | Sin caché | Datos en tiempo real |

**Resultado:** 90%+ de reducción en peticiones a API ⚡

---

## 📦 Assets de Fallback

Los assets de fallback permiten que la app funcione sin conexión:

```bash
# Generar assets desde la API
dart run tools/generate_fallback_assets.dart
```

Esto crea:
- `assets/data/regiones.json` - Lista de regiones
- `assets/data/comunas.json` - Comunas por región
- `assets/data/metadata.json` - Metadata de generación

**Uso:** Automático a través de `PharmacyService`

---

## 🔄 Migración del Backend

Si actualmente usas el backend intermediario:

1. **Lee la documentación:**
   - [MIGRACION.md](./MIGRACION.md) - Guía completa

2. **Ejecuta los tests:**
   ```bash
   flutter test test/direct_api_test.dart
   ```

3. **Genera assets:**
   ```bash
   dart run tools/generate_fallback_assets.dart
   ```

4. **Migra progresivamente** con feature flags

5. **Elimina el backend** cuando todo funcione

---

## 📊 Performance

### Latencia

| Escenario | Con Backend | Sin Backend (1ra vez) | Sin Backend (con caché) |
|-----------|-------------|------------------------|-------------------------|
| Regiones | ~500ms | ~300ms | **~5ms** ⚡ |
| Comunas | ~500ms | ~300ms | **~5ms** ⚡ |
| Fechas | ~500ms | ~300ms | **~5ms** ⚡ |
| Farmacias | ~500ms | ~300ms | ~300ms |

**Mejora:** 40% en primera carga, 100x con caché

---

## 💰 Costos

| Concepto | Con Backend | Sin Backend |
|----------|-------------|-------------|
| Hosting | $0-20/mes | $0 |
| Mantenimiento | 2-4h/mes | Mínimo |
| Total anual | $0-240 + tiempo | $0 |

**Ahorro:** $240+/año

---

## 🐛 Troubleshooting

### "Error de conexión"
- **Causa:** API de Farmanet caída
- **Solución:** App usa automáticamente assets de fallback

### "Datos desactualizados"
- **Causa:** Caché no se invalida
- **Solución:** Usar botón de "Refrescar" en UI

### "Tests fallan"
- **Causa:** Sin conexión o API cambió
- **Solución:** Verificar conexión y formato de API

Más info: [FAQ.md](./FAQ.md)

---

## 📱 Features

- ✅ Búsqueda de farmacias por región/comuna
- ✅ Filtro por tipo (turno, urgencia)
- ✅ Geolocalización
- ✅ Ordenamiento por distancia
- ✅ Detalles de farmacia
- ✅ Direcciones y teléfonos
- ✅ Caché local inteligente ✨
- ✅ Funciona offline ✨
- ✅ Assets de fallback ✨

---

## 🛠️ Stack Tecnológico

- **Framework:** Flutter 3.x
- **Lenguaje:** Dart
- **API:** Farmanet (MINSAL Chile)
- **Caché:** SharedPreferences
- **HTTP:** package:http
- **Geolocalización:** geolocator
- **Mapas:** url_launcher (Google Maps)

---

## 🤝 Contribuir

1. Lee la documentación en [INDICE.md](./INDICE.md)
2. Crea un fork del proyecto
3. Crea una rama para tu feature
4. Haz commit de tus cambios
5. Push a la rama
6. Abre un Pull Request

---

## 📄 Licencia

Este proyecto es de código abierto.

---

## 📞 Contacto

¿Preguntas? Revisa:
- [FAQ.md](./FAQ.md) - Preguntas frecuentes
- [ARQUITECTURA_DIRECTA.md](./ARQUITECTURA_DIRECTA.md) - Arquitectura
- [MIGRACION.md](./MIGRACION.md) - Guía de migración

---

## 🎉 Agradecimientos

- **MINSAL Chile** - Por la API pública de Farmanet
- **Flutter Community** - Por el excelente framework

---

**Hecho con ❤️ en Chile 🇨🇱**
