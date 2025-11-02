#!/usr/bin/env dart
/// Script para generar assets de fallback (regiones y comunas)
/// desde la API de Farmanet.
/// 
/// Estos assets se usan cuando:
/// - No hay conexión a internet
/// - La API de Farmanet está caída
/// - Como respaldo general
/// 
/// Uso:
///   dart run tools/generate_fallback_assets.dart

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String FARMANET_BASE_URL = 'https://midas.minsal.cl/farmacia_v2';
const String OUTPUT_DIR = 'assets/data';

void main() async {
  print('🚀 Generando assets de fallback desde API Farmanet...\n');
  
  // Crear directorio de salida
  final dir = Directory(OUTPUT_DIR);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
    print('📁 Creado directorio: $OUTPUT_DIR\n');
  }
  
  final client = http.Client();
  
  try {
    // 1. Generar regiones
    print('1️⃣  Obteniendo regiones...');
    final regions = await _getRegions(client);
    await _saveJson('$OUTPUT_DIR/regiones.json', regions);
    print('   ✅ Guardadas ${regions.length} regiones\n');
    
    // 2. Generar comunas por región
    print('2️⃣  Obteniendo comunas de todas las regiones...');
    final allCommunes = <String, List<Map<String, dynamic>>>{};
    
    for (final region in regions) {
      final regionId = region['id'].toString();
      final regionName = region['nombre'];
      
      try {
        final communes = await _getCommunes(client, regionId);
        allCommunes[regionId] = communes;
        print('   ✅ Región $regionId ($regionName): ${communes.length} comunas');
      } catch (e) {
        print('   ❌ Error en región $regionId: $e');
      }
      
      // Esperar un poco para no saturar la API
      await Future.delayed(Duration(milliseconds: 500));
    }
    
    await _saveJson('$OUTPUT_DIR/comunas.json', allCommunes);
    print('\n   ✅ Guardadas comunas de ${allCommunes.length} regiones\n');
    
    // 3. Generar metadata
    print('3️⃣  Generando metadata...');
    final metadata = {
      'generated_at': DateTime.now().toIso8601String(),
      'source': FARMANET_BASE_URL,
      'regions_count': regions.length,
      'communes_count': allCommunes.values.fold(0, (sum, list) => sum + list.length),
      'version': '1.0.0',
    };
    await _saveJson('$OUTPUT_DIR/metadata.json', metadata);
    print('   ✅ Metadata guardada\n');
    
    // 4. Resumen
    print('═' * 60);
    print('🎉 Assets generados exitosamente!\n');
    print('📊 Resumen:');
    print('   - Regiones: ${regions.length}');
    print('   - Comunas totales: ${metadata['communes_count']}');
    print('   - Fecha: ${metadata['generated_at']}');
    print('   - Ubicación: $OUTPUT_DIR/');
    print('═' * 60);
    print('\n📝 No olvides agregar estos assets en pubspec.yaml:');
    print('''
flutter:
  assets:
    - assets/data/regiones.json
    - assets/data/comunas.json
    - assets/data/metadata.json
''');
    
  } catch (e, st) {
    print('\n❌ Error general: $e');
    print('Stack trace: $st');
    exit(1);
  } finally {
    client.close();
  }
}

/// Obtener regiones desde API
Future<List<Map<String, dynamic>>> _getRegions(http.Client client) async {
  final url = Uri.parse('$FARMANET_BASE_URL/WS/getLocalesTurnos.php');
  
  final response = await client.post(
    url,
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: {'func': 'regiones'},
  );
  
  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }
  
  final data = jsonDecode(response.body);
  
  if (data is List) {
    return data.map((e) => e as Map<String, dynamic>).toList();
  } else if (data is Map) {
    return data.values.map((e) => e as Map<String, dynamic>).toList();
  }
  
  throw Exception('Formato de respuesta inesperado');
}

/// Obtener comunas de una región
Future<List<Map<String, dynamic>>> _getCommunes(http.Client client, String regionId) async {
  final url = Uri.parse('$FARMANET_BASE_URL/WS/getLocalesTurnos.php');
  
  final response = await client.post(
    url,
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: {
      'func': 'comunas',
      'region': regionId,
    },
  );
  
  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }
  
  final data = jsonDecode(response.body);
  
  if (data is List) {
    return data.map((e) => e as Map<String, dynamic>).toList();
  } else if (data is Map) {
    return data.values.map((e) => e as Map<String, dynamic>).toList();
  }
  
  return [];
}

/// Guardar datos en formato JSON con formato bonito
Future<void> _saveJson(String path, dynamic data) async {
  final file = File(path);
  final json = JsonEncoder.withIndent('  ').convert(data);
  await file.writeAsString(json);
}
