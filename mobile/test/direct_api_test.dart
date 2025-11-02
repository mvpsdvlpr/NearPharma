import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api_client_direct.dart';
import 'package:mobile/services/pharmacy_service.dart';
import 'package:mobile/services/cache_service.dart';

void main() {
  group('ApiClientDirect - Conexión directa a Farmanet', () {
    late ApiClientDirect api;

    setUp(() {
      api = ApiClientDirect();
    });

    tearDown(() {
      api.close();
    });

    test('Obtener regiones directamente', () async {
      final regions = await api.getRegions();
      
      expect(regions, isNotEmpty);
      expect(regions.first, isA<Map<String, dynamic>>());
      
      // Verificar estructura básica
      expect(regions.first.keys, contains('id'));
      expect(regions.first.keys, contains('nombre'));
      
      print('✅ Obtenidas ${regions.length} regiones');
      print('Ejemplo: ${regions.first}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('Obtener comunas de Región Metropolitana', () async {
      // Región Metropolitana suele ser ID 13
      final communes = await api.getCommunes('13');
      
      expect(communes, isNotEmpty);
      expect(communes.first, isA<Map<String, dynamic>>());
      
      print('✅ Obtenidas ${communes.length} comunas de RM');
      print('Ejemplo: ${communes.first}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('Obtener fechas de turno', () async {
      final dates = await api.getTurnDates();
      
      expect(dates, isNotEmpty);
      
      print('✅ Obtenidas ${dates.length} fechas');
      print('Ejemplo: ${dates.entries.first}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('Buscar farmacias en Santiago', () async {
      final pharmacies = await api.searchPharmaciesByCommune(
        regionId: '13',
        communeId: '130', // Santiago Centro
        filter: 'turnos',
      );
      
      expect(pharmacies, isA<List>());
      
      print('✅ Encontradas ${pharmacies.length} farmacias en Santiago');
      if (pharmacies.isNotEmpty) {
        print('Ejemplo: ${pharmacies.first}');
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('PharmacyService - Con caché', () {
    late PharmacyService service;

    setUp(() async {
      final api = ApiClientDirect();
      service = PharmacyService(api);
      
      // Limpiar caché antes de cada test
      await CacheService.clearAll();
    });

    tearDown(() {
      service.close();
    });

    test('Primera llamada debería ir a API, segunda a caché', () async {
      // Primera llamada - debe ir a la API
      final start1 = DateTime.now();
      final regions1 = await service.getRegions();
      final duration1 = DateTime.now().difference(start1);
      
      expect(regions1, isNotEmpty);
      print('Primera llamada (API): ${duration1.inMilliseconds}ms');
      
      // Segunda llamada - debe usar caché (mucho más rápido)
      final start2 = DateTime.now();
      final regions2 = await service.getRegions();
      final duration2 = DateTime.now().difference(start2);
      
      expect(regions2, isNotEmpty);
      expect(regions1.length, equals(regions2.length));
      print('Segunda llamada (caché): ${duration2.inMilliseconds}ms');
      
      // El caché debería ser al menos 10x más rápido
      expect(duration2.inMilliseconds, lessThan(duration1.inMilliseconds ~/ 10));
      
      print('✅ Caché funciona: ${(duration1.inMilliseconds / duration2.inMilliseconds).toStringAsFixed(1)}x más rápido');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('Estadísticas de caché después de usar el servicio', () async {
      // Hacer algunas llamadas
      await service.getRegions();
      await service.getCommunes('13');
      await service.getTurnDates();
      
      // Verificar estadísticas
      final stats = await service.getCacheStats();
      
      expect(stats['hasRegions'], isTrue);
      expect(stats['hasDates'], isTrue);
      expect(stats['cachedCommuneRegions'], greaterThan(0));
      
      print('✅ Estadísticas de caché: $stats');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('Limpiar caché funciona', () async {
      // Cachear algunos datos
      await service.getRegions();
      
      var stats = await service.getCacheStats();
      expect(stats['hasRegions'], isTrue);
      
      // Limpiar caché
      await service.clearCache();
      
      stats = await service.getCacheStats();
      expect(stats['hasRegions'], isFalse);
      
      print('✅ Caché limpiado exitosamente');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('Comparación: Backend vs Directo', () {
    test('Medir latencia de conexión directa', () async {
      final api = ApiClientDirect();
      
      final start = DateTime.now();
      final regions = await api.getRegions();
      final duration = DateTime.now().difference(start);
      
      expect(regions, isNotEmpty);
      
      print('⚡ Latencia conexión directa: ${duration.inMilliseconds}ms');
      print('📊 Regiones obtenidas: ${regions.length}');
      
      // Con backend intermediario sería aproximadamente el doble
      print('📈 Latencia estimada con backend: ~${duration.inMilliseconds * 2}ms');
      print('💡 Ahorro: ~${duration.inMilliseconds}ms por petición');
      
      api.close();
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
