import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';
import 'src/logger.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import 'widgets/pharmacy_card.dart';
import 'utils/pill.dart';
import 'theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  // try to read package version at runtime; if available, inject into MyApp.appVersion
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isNotEmpty || info.buildNumber.isNotEmpty) {
      MyApp.packageVersion = info.version;
      MyApp.packageBuild = info.buildNumber;
      MyApp.appVersion = '${info.version}+${info.buildNumber}';
    }
  } catch (e, st) {
    AppLogger.d('PackageInfo.fromPlatform failed, using compile-time fallback', e, st);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  /// App version string. The build metadata (after '+') uses the current
  /// date in YYYYMMDD format so releases can be identified by release day.
  ///4
  /// Example: '1.0.0-beta+20251012'
  // Set this to the release date (format YYYYMMDD) when publishing a new version.
  // Example: '20251012' for October 12, 2025.
  static const String releaseDate = '20251012';

  // Mutable static that can be overridden at startup from PackageInfo.
  static String appVersion = '1.0.0-beta+$releaseDate';
  // When PackageInfo is available we also keep its components for display.
  static String packageVersion = '';
  static String packageBuild = '';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NearPharma',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const TipoFarmaciaScreen(),
    );
  }
}

class TipoFarmaciaScreen extends StatefulWidget {
  final ApiClient? apiClient;
  final bool autoInit;
  final bool disableNetworkImages;
  const TipoFarmaciaScreen({super.key, this.apiClient, this.autoInit = true, this.disableNetworkImages = false});
  @override
  TipoFarmaciaScreenState createState() => TipoFarmaciaScreenState();
}

class TipoFarmaciaScreenState extends State<TipoFarmaciaScreen> {
  List<dynamic> tipos = [];
  List<String> iconosTipos = [];
  List<String> titulosTipos = [];
  int? tipoSeleccionado;
  List<dynamic> fechas = [];
  String? fechaSeleccionada;
  // Global filter selection: 'turnos' (default) or 'urgencia'. This controls the
  // value sent in the form body as 'filtro'. Kept separate from `tipoSeleccionado`
  // which maps to icon/tipo metadata loaded from the server.
  String filtroSeleccionado = 'turnos';
  List<dynamic> regiones = [];
  String? regionSeleccionada;
  List<dynamic> comunas = [];
  String? comunaSeleccionada;
  List<dynamic> farmacias = [];
  Position? currentPosition;
  Map<String, String> regionesMap = {};
  Map<String, String> comunasMap = {};
  // Fallback metadata mapping for known tipo icon ids from the web UI
  final Map<String, Map<String, String>> _tipoMetadata = {
    'turnos': {
      'nombre': 'Farmacia de Turno / Urgencia',
      'descripcion': 'Apertura obligatoria para asegurar disponibilidad de medicamentos en horarios fijados por la autoridad sanitaria. Incluye también farmacias de urgencia (atención 24h).'
    },
    'urgencia': {
      'nombre': 'Urgencia',
    },
    'movil': {
      'nombre': 'Farmacia Móvil',
    },
    'popular': {
      'nombre': 'Farmacia Municipal',
    },
    'privado': {
      'nombre': 'Farmacia Privada',
    },
    'todos': {
      'nombre': 'Todas las farmacias',
      'descripcion': ''
    },
    'almacen': {
      'nombre': 'Almacén Farmacéutico'
    },
  };
  bool cargando = true;
  String? error;
  DateTime _deviceTime = DateTime.now();
  Timer? _clockTimer;

  // Quick filters removed — app always filters to 'turnos'

  @override
  void initState() {
    super.initState();
    if (widget.autoInit) {
      _ensureLocation();
      _loadFiltros();
    }
    // start device clock
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() { _deviceTime = DateTime.now(); });
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  // Load global comunas map used for lookups (equivalent to map.js initial comunas call)
  Future<void> _loadAllComunas() async {
    try {
    final resp = await _postForm({'func': 'comunas'});
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data is Map && data['respuesta'] != null && data['respuesta'] is List) {
          final list = data['respuesta'] as List<dynamic>;
          final map = <String, String>{};
          for (final c in list) {
            try {
              map[c['id'].toString()] = c['nombre'].toString();
            } catch (e, st) {
              AppLogger.d('parse comuna entry failed in _loadAllComunas', e, st);
            }
          }
          setState(() {
            comunasMap = map;
          });
        }
      }
    } catch (e, st) {
      AppLogger.d('_loadTipos error', e, st);
    }
  }

  Future<String> _apiBase() async {
    await dotenv.load();
    return dotenv.env['API_BASE_URL'] ?? 'http://localhost:3001';
  }

  Future<http.Response> _postForm(Map<String, String> body) async {
    if (widget.apiClient != null) {
      return widget.apiClient!.postForm(body);
    }
    // When no ApiClient is injected, create a short-lived ApiClient so we get
    // consistent request/response logging (ApiClient.postForm logs requests).
    final apiBase = await _apiBase();
    final client = ApiClient(baseUrl: apiBase);
    try {
      return await client.postForm(body);
    } finally {
      client.close();
    }
  }

  Future<void> _loadFiltros() async {
    setState(() {
      cargando = true;
      error = null;
    });
    try {
      // load iconos (tipos), regiones, comunas (global) and fechas similar to web init
      await Future.wait([_loadTipos(), _loadRegiones(), _loadAllComunas(), _loadFechas()]);
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        cargando = false;
      });
    }
  }

  Future<void> _loadTipos() async {
    try {
      final resp = await _postForm({'func': 'iconos'});
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        List<dynamic> tiposList = [];
        List<dynamic> titulos = [];
        List<dynamic> iconos = [];
        if (data is Map) {
          if (data['respuesta'] != null && data['respuesta']['titulos'] != null && data['respuesta']['iconos'] != null) {
            titulos = List<dynamic>.from(data['respuesta']['titulos']);
            iconos = List<dynamic>.from(data['respuesta']['iconos']);
          } else if (data['titulos'] != null && data['iconos'] != null) {
            titulos = List<dynamic>.from(data['titulos']);
            iconos = List<dynamic>.from(data['iconos']);
          }
        }
        if (titulos.isNotEmpty && iconos.isNotEmpty) {
          iconosTipos = iconos.map((e) => e.toString()).toList();
          titulosTipos = titulos.map((e) => e.toString()).toList();
          for (int i = 0; i < titulos.length && i < iconos.length; i++) {
            final id = iconos[i].toString();
            // prefer server title, but fallback to metadata nombre if present
            String nombre = titulos[i].toString();
            if (nombre.isEmpty && _tipoMetadata.containsKey(id)) {
              nombre = _tipoMetadata[id]!['nombre'] ?? id;
            }
            String descripcion = '';
            if (_tipoMetadata.containsKey(id)) descripcion = _tipoMetadata[id]!['descripcion'] ?? '';
            tiposList.add({'id': id, 'nombre': nombre.toString(), 'descripcion': descripcion});
          }
        }
        setState(() {
          // Restrict available tipos to only 'turnos' per reconfiguration
          tipos = tiposList.where((t) => (t['id']?.toString() ?? '') == 'turnos').toList();
          tipoSeleccionado = tipos.isNotEmpty ? 0 : null;
        });
      } else {
        throw Exception('Error iconos: ${resp.statusCode}');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    }
  }

  Future<void> _loadComunas(String regionId) async {
    try {
      // Try requesting comunas filtered by region first (more efficient)
      final resp = await _postForm({'func': 'comunas', 'region': regionId});
      List<dynamic> comunasList = [];
      bool ok = false;
      if (resp.statusCode == 200) {
        try {
          final data = json.decode(resp.body);
          if (data is Map && data['respuesta'] != null && data['respuesta'] is List) {
            comunasList = data['respuesta'];
            ok = true;
          } else if (data is List) {
            comunasList = data;
            ok = true;
          }
        } catch (_) {
          // parsing failed, fall through to fallback
          ok = false;
        }
      }

      if (!ok) {
        // Fallback: request global comunas and then filter by regionId if possible
        try {
          final allResp = await _postForm({'func': 'comunas'});
          if (allResp.statusCode == 200) {
            final raw = json.decode(allResp.body);
            List<dynamic> allList = [];
            if (raw is Map && raw['respuesta'] != null && raw['respuesta'] is List) {
              allList = raw['respuesta'];
            } else if (raw is List) {
              allList = raw;
            }
            // If items contain a region id field, try to filter; otherwise keep all
            try {
              comunasList = allList.where((c) {
                try {
                  final r = c['region'] ?? c['region_id'] ?? c['regionId'];
                  if (r == null) return true; // no region info -> keep
                  return r.toString() == regionId.toString();
                } catch (_) {
                  return true;
                }
              }).toList();
            } catch (_) {
              comunasList = allList;
            }
          }
        } catch (_) {}
      }

      setState(() {
        comunas = comunasList;
        // build/update comunasMap for quick lookup
        comunasMap = {};
        for (final c in comunasList) {
          try {
            comunasMap[c['id'].toString()] = c['nombre'].toString();
          } catch (_) {}
        }
        // Do not preselect a comuna; user must choose
        comunaSeleccionada = null;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    }
  }

  Future<void> _buscarFarmacias() async {
    setState(() {
      cargando = true;
      error = null;
      farmacias = [];
    });
    try {
      // Ensure we have the user's location when possible before querying
      if (currentPosition == null) {
        await _ensureLocation();
      }
        final tipo = (filtroSeleccionado == 'turnos' ? 'turnos' : (tipoSeleccionado != null ? tipos[tipoSeleccionado!]['id'] : ''));
    // Build body map similar to web: func=region, filtro, fecha (if turnos), region, hora
    final hora = _horaActual();

    List<dynamic> farmaciasList = [];
    if (tipo == 'turnos') {
      // Query both 'turnos' and 'urgencia' and merge results (avoid duplicates by 'im')
      final bodies = <Map<String, String>>[];
      final b1 = {'func': 'region', 'filtro': 'turnos', 'region': regionSeleccionada ?? '', 'hora': hora};
      final b2 = {'func': 'region', 'filtro': 'urgencia', 'region': regionSeleccionada ?? '', 'hora': hora};
      // Note: Coordinates are not sent to backend, following MVP pattern where location handling is frontend-only
      if (fechaSeleccionada != null && fechaSeleccionada!.isNotEmpty) {
        b1['fecha'] = fechaSeleccionada!;
        b2['fecha'] = fechaSeleccionada!;
      }
      bodies.add(b1);
      bodies.add(b2);

      final responses = await Future.wait(bodies.map((b) => _postForm(b)));
      final seen = <String>{};
      for (final resp in responses) {
        if (resp.statusCode != 200) continue;
        try {
          final data = json.decode(resp.body);
          if (data is Map && data['respuesta'] != null && data['respuesta']['locales'] != null) {
            final locals = List<dynamic>.from(data['respuesta']['locales']);
            for (final l in locals) {
              try {
                final id = l['im']?.toString() ?? l['id']?.toString() ?? json.encode(l);
                if (!seen.contains(id)) {
                  seen.add(id);
                  farmaciasList.add(l);
                }
              } catch (e, st) {
                AppLogger.d('failed to extract id for local entry', e, st);
              }
            }
          }
        } catch (e, st) {
          AppLogger.d('failed to parse region response for locales', e, st);
        }
      }
    } else {
      final bodyMap = <String, String>{'func': 'region', 'filtro': tipo, 'region': regionSeleccionada ?? '', 'hora': hora};
      if (tipo == 'turnos' && fechaSeleccionada != null && fechaSeleccionada!.isNotEmpty) {
        bodyMap['fecha'] = fechaSeleccionada!;
      }
      // Note: Coordinates are not sent to backend, following MVP pattern where location handling is frontend-only
      final resp = await _postForm(bodyMap);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
  // Debug: print raw region response
  // Log region response preview via AppLogger
  try {
    final preview = resp.body.length > 1000 ? resp.body.substring(0, 1000) + '...[truncated]' : resp.body;
    AppLogger.d('region response preview: $preview');
  } catch (e, st) {
    AppLogger.d('region response preview failed to build', e, st);
  }
        if (data is Map && data['respuesta'] != null && data['respuesta']['locales'] != null) {
          farmaciasList = List<dynamic>.from(data['respuesta']['locales']);
        }
      }
    }

    if (farmaciasList.isEmpty) {
      // Attempt fallbacks: try without filtro and then with 'todos' to increase chance of data
      final tried = <String>{};
      final fallbackFilters = ['', 'todos'];
      for (final alt in fallbackFilters) {
        if (tried.contains(alt)) continue;
        tried.add(alt);
        try {
          final b = {'func': 'region', 'filtro': alt, 'region': regionSeleccionada ?? '', 'hora': hora};
          if (fechaSeleccionada != null && fechaSeleccionada!.isNotEmpty) b['fecha'] = fechaSeleccionada!;
          // Note: Coordinates are not sent to backend, following MVP pattern where location handling is frontend-only
          final resp = await _postForm(b);
          if (resp.statusCode != 200) continue;
          final data = json.decode(resp.body);
          if (data is Map && data['respuesta'] != null && data['respuesta']['locales'] != null) {
            farmaciasList = List<dynamic>.from(data['respuesta']['locales']);
            if (farmaciasList.isNotEmpty) break;
          } else if (data is Map && data['respuesta'] != null && data['respuesta'] is List) {
            farmaciasList = List<dynamic>.from(data['respuesta']);
            if (farmaciasList.isNotEmpty) break;
          } else if (data is List) {
            farmaciasList = List<dynamic>.from(data);
            if (farmaciasList.isNotEmpty) break;
          }
        } catch (e, st) {
          AppLogger.d('fallback region request failed for filter $alt', e, st);
        }
      }

      if (farmaciasList.isEmpty) {
        setState(() {
          farmacias = [];
          cargando = false;
        });
        return;
      }
    }

        // If we have a current position, compute distances and sort nearest->farthest
        if (currentPosition != null && farmaciasList.isNotEmpty) {
          farmaciasList = sortByProximity(farmaciasList, currentPosition!.latitude, currentPosition!.longitude);
        }

    // For each local request detailed info (func=local) in parallel
    final futures = farmaciasList.map<Future<Map<String, dynamic>>>((local) => _fetchLocalDetail(local));
    final detailed = await Future.wait(futures);

    // Apply global filtroSeleccionado (if any) using the `tp` code from each
    // local's `f` object when available: '1' -> turno, '3' -> urgencia.
    // Note: tp is used for pill display only, NOT for filtering pharmacies
    List<dynamic> detailedAfterFiltro = detailed;

    // Ensure final displayed list is ordered by distance to the user when possible.
      // If a comuna is selected, filter the detailed results by that comuna using the detailed 'f' object
  final filteredDetailed = detailedAfterFiltro.where((d) {
        try {
          final f = d['f'] ?? d['raw'] ?? d;
          final targetComunaId = comunaSeleccionada?.toString() ?? '';
          final targetComunaName = comunasMap[targetComunaId] ?? '';

          // Check comuna id
          final cm = (f['cm'] ?? f['comuna'] ?? f['comuna_id'] ?? f['comunaId'])?.toString();
          if (cm != null && cm == targetComunaId) {
            return true;
          }

          // Check comuna name
          final cname = (f['comuna_nombre'] ?? f['comunaNombre'] ?? f['comuna_nombre_local'] ?? f['comuna'])?.toString() ?? '';
          if (cname.toLowerCase().contains(targetComunaName.toLowerCase())) {
            return true;
          }

          // Check address
          final dr = (f['dr'] ?? f['direccion'] ?? f['local_dr'] ?? f['local_direccion'])?.toString() ?? '';
          if (dr.toLowerCase().contains(targetComunaName.toLowerCase())) {
            return true;
          }
        } catch (_) {}
        return false;
      }).toList();

      // Use filteredDetailed instead of detailed
      // Keep the complete structure needed by PharmacyCard: { 'f': mergedF, 'horario': horario, 'raw': raw }
      // Merge raw + detailed `f` so we don't lose fields present only in the
      // initial `raw` item when the detail response omits them. Detailed `f`
      // should override raw values when present.
      final mapped = filteredDetailed.map((d) {
        final raw = (d['raw'] is Map) ? Map<String, dynamic>.from(d['raw']) : <String, dynamic>{};
        final fdet = (d['f'] is Map) ? Map<String, dynamic>.from(d['f']) : <String, dynamic>{};
        final horario = (d['horario'] is Map) ? Map<String, dynamic>.from(d['horario']) : <String, dynamic>{};
        final mergedF = <String, dynamic>{}..addAll(raw)..addAll(fdet);
        return {
          'f': mergedF,
          'horario': horario,
          'raw': raw,
        };
      }).toList();

      if (mapped.isNotEmpty) {
        // If a comuna is selected, show only those entries that match the comuna.
        // Do NOT sort by proximity in that case — the requirement is to list only
        // the farmacias that belong to the selected comuna, not the nearest ones.
        if (comunaSeleccionada != null && comunaSeleccionada!.isNotEmpty) {
          setState(() {
            farmacias = mapped;
            cargando = false;
          });
        } else if (currentPosition != null) {
          // No comuna selected: keep the previous behaviour of sorting by proximity
          final sorted = sortByProximity(mapped, currentPosition!.latitude, currentPosition!.longitude);
          setState(() {
            farmacias = sorted;
            cargando = false;
          });
        } else {
          // No position available: just present the mapped list
          setState(() {
            farmacias = mapped;
            cargando = false;
          });
        }
      } else {
        setState(() {
          farmacias = [];
          cargando = false;
        });
      }
  } catch (e) {
    setState(() {
      error = e.toString();
      cargando = false;
    });
  }
}

  String _horaActual() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  // Safe parse helper: returns null when parse fails
  double? _safeParseDouble(String? s) {
    if (s == null) return null;
    try {
      final cleaned = s.trim().replaceAll(',', '.');
      final m = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(cleaned);
      if (m == null) return null;
      return double.tryParse(m.group(0) ?? '');
    } catch (e, st) {
      AppLogger.d('safeParseDouble failed for input: $s', e, st);
      return null;
    }
  }

  // Load regiones (similar to web func=regiones)
  Future<void> _loadRegiones() async {
    try {
      final resp = await _postForm({'func': 'regiones'});
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        List<dynamic> regionesList = [];
        if (data is Map && data['respuesta'] != null && data['respuesta'] is List) {
          regionesList = data['respuesta'];
        } else if (data is List) {
          regionesList = data;
        }
        final map = <String, String>{};
        for (final r in regionesList) {
          try {
            map[r['id'].toString()] = r['nombre'].toString();
          } catch (e, st) {
            AppLogger.d('failed to compute id in sorted mapping', e, st);
          }
        }
        setState(() {
          regiones = regionesList;
          regionesMap = map;
        });
      }
    } catch (e, st) {
      AppLogger.d('_loadRegiones top-level catch', e, st);
    }
  }

  // Load fechas (func=fechas) and convert map to list of {id,label}
  Future<void> _loadFechas() async {
    try {
      final resp = await _postForm({'func': 'fechas'});
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        List<dynamic> out = [];
        if (data is Map && data['respuesta'] != null) {
          final raw = data['respuesta'];
          if (raw is Map) {
            raw.forEach((k, v) {
              try {
                out.add({'id': k.toString(), 'label': v.toString()});
              } catch (_) {}
            });
          } else if (raw is List) {
            out = List<dynamic>.from(raw);
          }
        }
        setState(() {
          fechas = out;
        });
      }
    } catch (e, st) {
      AppLogger.d('_loadFechas top-level catch', e, st);
    }
  }

  String _stripHtml(String? s) {
    if (s == null) return '';
    // Replace <br> and variants with newline, then remove other tags
  var t = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    t = t.replaceAll(RegExp(r'<[^>]+>'), '');
    return t.trim();
  }

  double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    double toRad(double x) => x * 3.141592653589793 / 180.0;
    const R = 6371.0;
    final dLat = toRad(lat2 - lat1);
    final dLng = toRad(lng2 - lng1);
    final a = (sin(dLat / 2) * sin(dLat / 2)) + (cos(toRad(lat1)) * cos(toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  // Parse several coordinate formats into a double.
  // Accepts numeric types or strings with commas, degree symbols or extra characters.
  // Returns `null` when parsing fails.
  double? _toDoubleCoord(dynamic v) {
    if (v == null) return null;
    try {
      final s = v.toString().trim().replaceAll(',', '.');
      // Match an optional sign, digits, optional decimal part.
      final m = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(s);
      if (m == null) return null;
      return double.tryParse(m.group(0) ?? '');
    } catch (_) {
      return null;
    }
  }
  /// Sort a list of farmacia-like maps by proximity to (lat,lng).
  /// Each item can have keys 'lt'/'lat' and 'lg'/'lng'. Returns a new list sorted nearest->farthest.
  List<dynamic> sortByProximity(List<dynamic> items, double lat, double lng) {
    final copied = List<dynamic>.from(items);
    copied.sort((a, b) {
      double aDist = double.infinity;
      double bDist = double.infinity;
      try {
        final aLat = _toDoubleCoord(a['lt'] ?? a['lat'] ?? a['local_lat']);
        final aLng = _toDoubleCoord(a['lg'] ?? a['lng'] ?? a['local_lng']);
        if (aLat != null && aLng != null) {
          aDist = _distanceKm(lat, lng, aLat, aLng);
        }
      } catch (_) {}
      try {
        final bLat = _toDoubleCoord(b['lt'] ?? b['lat'] ?? b['local_lat']);
        final bLng = _toDoubleCoord(b['lg'] ?? b['lng'] ?? b['local_lng']);
        if (bLat != null && bLng != null) {
          bDist = _distanceKm(lat, lng, bLat, bLng);
        }
      } catch (_) {}
      return aDist.compareTo(bDist);
    });
    return copied;
  }

  Future<Map<String, dynamic>> _fetchLocalDetail(dynamic local) async {
    // local is the item from respuesta.locales; call func=local with at least im and fecha if needed
    try {
      // Build body by sending the whole lc object like the web does (map.js: lc.func='local'; lc.fecha=fecha)
      final body = <String, String>{};
      if (local is Map) {
        local.forEach((k, v) {
          try {
            body[k.toString()] = v?.toString() ?? '';
          } catch (_) {}
        });
      } else {
        // fallback: if local is a primitive, send it as im
        body['im'] = local?.toString() ?? '';
      }
      // ensure func and fecha when applicable
      body['func'] = 'local';
      // Use the global filtro selection to decide whether to include fecha for local details.
      if (filtroSeleccionado == 'turnos' && fechaSeleccionada != null && fechaSeleccionada!.isNotEmpty) {
        body['fecha'] = fechaSeleccionada!;
      }
      // include lat/lng if present (map.js sends the whole lc object but im is enough for server)
      final resp = await _postForm(body);
      if (resp.statusCode == 200) {
        // Debug: print raw local response
        debugPrint('DEBUG local(${body['im'] ?? 'no-im'}) response: ${resp.body}');
        final data = json.decode(resp.body);
        if (data is Map && data['respuesta'] != null) {
          final localResp = data['respuesta']['local'];
          final horario = data['respuesta']['horario'];
          // return combined map
          return {'f': localResp ?? local, 'horario': horario ?? {}, 'raw': local};
        }
      }
    } catch (_) {}
    // fallback: return original local without detalle
    return {'f': local, 'horario': {}, 'raw': local};
  }

  bool _inputsSuficientes() {
    // tipo and region and comuna are required; if tipo == 'turnos' also require fecha
    if (tipoSeleccionado == null) return false;
    if (regionSeleccionada == null || comunaSeleccionada == null) return false;
  if (filtroSeleccionado == 'turnos' && (fechaSeleccionada == null || fechaSeleccionada!.isEmpty)) return false;
    return true;
  }

  void _maybeBuscar() {
    if (_inputsSuficientes() && !cargando) {
      _buscarFarmacias();
    }
  }

  // Pill derivation moved to `lib/utils/pill.dart` to make it testable.

  // Build a styled filter button that visually matches the PharmacyCard's
  // ElevatedButton.icon used for the "¿Cómo llegar?" action. The selected
  // button appears filled; the unselected one is outlined.
  Widget _buildFilterButton(String id, IconData icon, String label) {
    final selected = filtroSeleccionado == id;
    return Builder(builder: (context) {
      final onPressed = () {
        setState(() {
          filtroSeleccionado = id;
          // Clear dependent filters when switching
          fechaSeleccionada = null;
          regionSeleccionada = null;
          comunaSeleccionada = null;
          comunas = [];
          farmacias = [];
          error = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBuscar());
      };

      const pad = EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0);
      if (selected) {
        return ElevatedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label), style: ElevatedButton.styleFrom(padding: pad));
      }
      return OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label), style: OutlinedButton.styleFrom(padding: pad));
    });
  }

  // Public wrapper for tests to trigger filter loading when autoInit is false
  Future<void> loadFiltros() async {
    await _loadFiltros();
  }

  // Public test helper to load comunas for a given region. Keeps _loadComunas private but
  // exposes a safe wrapper for tests and external callers that need to trigger it.
  Future<void> loadComunasForTest(String regionId) async {
    await _loadComunas(regionId);
  }

  /// Busca por tipo usando la misma semántica que la función `buscar(tipo)` en mapa.php.
  /// Ejemplo de uso: `buscar('todos')`, `buscar('turno')`, `buscar('movil')`.
  /// Normaliza y mapea sinónimos (por ejemplo 'turno' -> 'turnos', 'todo' -> 'todos', 'almacén' -> 'almacen').
  /// Selecciona el tipo en la UI, carga las fechas si corresponde, limpia la comuna y dispara la búsqueda automática.
  Future<void> buscar(String tipo) async {
    // normalize input: trim, lowercase, strip common diacritics
    String norm(String s) {
      var t = s.trim().toLowerCase();
      t = t.replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ü', 'u').replaceAll('ñ', 'n');
      return t;
    }

    final aliases = <String, String>{
      'turno': 'turnos',
      'turnos': 'turnos',
      'urgencia': 'urgencia',
      'urgencias': 'urgencia',
  'movil': 'movil',
      'popular': 'popular',
      'privado': 'privado',
      'todo': 'todos',
      'todos': 'todos',
      'almacen': 'almacen',
      'almacén': 'almacen',
    };

  final key = norm(tipo);
    final mapped = aliases[key] ?? key;

    // Ensure tipos are loaded
    if (tipos.isEmpty) {
      await _loadTipos();
    }

    // Find index in tipos by id
    int idx = tipos.indexWhere((t) => (t['id']?.toString() ?? '') == mapped);
    if (idx < 0) {
      // If not found, try matching by nombre (fallback)
      idx = tipos.indexWhere((t) => (t['nombre']?.toString().toLowerCase() ?? '') == mapped);
    }

    setState(() {
      if (idx >= 0) {
        tipoSeleccionado = idx;
      } else {
        // no match: clear selection
        tipoSeleccionado = null;
      }
      // limpiarComuna = 0 equivalent: clear comuna selection and list
      comunaSeleccionada = null;
      comunas = [];
      // clear previous results
      farmacias = [];
      error = null;
    });

    // If selecting turnos, ensure fechas are loaded and a sensible fecha is chosen
    if (mapped == 'turnos') {
      await _loadFechas();
      if ((fechaSeleccionada == null || fechaSeleccionada == '0') && fechas.isNotEmpty) {
        // pick the first available fecha (skip placeholder '0' if present)
        String pick = '';
        for (final f in fechas) {
          try {
            final id = f is Map && f['id'] != null ? f['id'].toString() : f.toString();
            if (id != '0') { pick = id; break; }
          } catch (_) {}
        }
        if (pick.isEmpty) {
          final f = fechas.first;
          pick = f is Map && f['id'] != null ? f['id'].toString() : f.toString();
        }
        setState(() { fechaSeleccionada = pick; });
      }
    } else {
      // hide fecha: clear selection
      setState(() { fechaSeleccionada = null; });
    }

    // Reload regiones (web code reloads regiones after tipo change)
    await _loadRegiones();

    // Trigger search if inputs are sufficient
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBuscar());
  }

  // Public helper for tests: set selections and directly trigger the search.
  // This avoids interacting with dropdown overlays in widget tests and speeds them up.
  Future<void> buscarFarmaciasPublic({int? tipoIndex, String? regionId, String? comunaId, String? fechaId}) async {
    setState(() {
      tipoSeleccionado = tipoIndex;
      regionSeleccionada = regionId;
      comunaSeleccionada = comunaId;
      fechaSeleccionada = fechaId;
      // clear previous results
      farmacias = [];
      error = null;
    });
    await _buscarFarmacias();
  }

  Future<void> _ensureLocation() async {
    try {
      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDisabledDialog();
        return;
      }
      
      // Verificar permisos actuales
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationPermissionDeniedDialog();
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showLocationPermissionDeniedForeverDialog();
        return;
      }
      
      // Obtener la posición actual
      currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best)
      );
      
      // Si ya tenemos farmacias cargadas, reordenarlas por proximidad
      if (currentPosition != null && farmacias.isNotEmpty) {
        try {
          // farmacias list contains 'f' wrapped entries from _fetchLocalDetail; map to f and reorder
          final mapped = farmacias.map((d) => d['f'] ?? d['raw'] ?? d).toList();
          final sorted = sortByProximity(mapped, currentPosition!.latitude, currentPosition!.longitude);
          Map<String, int> idToIndex = {};
          for (int i = 0; i < sorted.length; i++) {
            try {
              final id = (sorted[i]['im'] ?? sorted[i]['id'] ?? i).toString();
              idToIndex[id] = i;
            } catch (_) {}
          }
          setState(() {
            farmacias.sort((a, b) {
              final aRaw = a['f'] ?? a['raw'] ?? a;
              final bRaw = b['f'] ?? b['raw'] ?? b;
              final aId = (aRaw['im'] ?? aRaw['id'] ?? '').toString();
              final bId = (bRaw['im'] ?? bRaw['id'] ?? '').toString();
              final ai = idToIndex.containsKey(aId) ? idToIndex[aId]! : 9223372036854775807;
              final bi = idToIndex.containsKey(bId) ? idToIndex[bId]! : 9223372036854775807;
              return ai.compareTo(bi);
            });
          });
        } catch (e, st) {
          AppLogger.d('_ensureLocation: reordering mapping failed', e, st);
        }
      }
    } catch (e, st) {
      AppLogger.d('_ensureLocation top-level failed', e, st);
      currentPosition = null;
    }
  }

  void _showLocationServiceDisabledDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Servicio de ubicación deshabilitado'),
          content: const Text(
            'Para mostrar las farmacias más cercanas, por favor habilita el servicio de ubicación en la configuración de tu dispositivo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openLocationSettings();
              },
              child: const Text('Ir a configuración'),
            ),
          ],
        );
      },
    );
  }

  void _showLocationPermissionDeniedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permiso de ubicación denegado'),
          content: const Text(
            'Para encontrar las farmacias más cercanas, necesitamos acceso a tu ubicación. Puedes intentar otorgar el permiso nuevamente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _ensureLocation();
              },
              child: const Text('Intentar nuevamente'),
            ),
          ],
        );
      },
    );
  }

  void _showLocationPermissionDeniedForeverDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permiso de ubicación permanentemente denegado'),
          content: const Text(
            'Para usar la función de farmacias cercanas, necesitas habilitar los permisos de ubicación en la configuración de la aplicación.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openAppSettings();
              },
              child: const Text('Ir a configuración'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openMaps(String direccion, String comuna, String region, {double? lat, double? lng}) async {
    if (!mounted) return;
    final address = '$direccion, $comuna, $region'.trim();
    final encodedAddress = Uri.encodeComponent(address);

    // helper removed: using canLaunchUrl/launchUrl inline with fallbacks

    // Show chooser bottom sheet
    await showModalBottomSheet<void>(context: context, builder: (ctx) {
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Abrir en Google Maps'),
            onTap: () async {
              Navigator.of(ctx).pop();
              // Prefer native comgooglemaps scheme (installed app), then geo:, then web URL
              if (lat != null && lng != null) {
                final native = Uri.parse('comgooglemaps://?center=$lat,$lng&zoom=14');
                final geo = Uri.parse('geo:$lat,$lng?q=$lat,$lng($encodedAddress)');
                final web = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');
                if (await canLaunchUrl(native)) {
                  await launchUrl(native);
                } else if (await canLaunchUrl(geo)) {
                  await launchUrl(geo);
                } else {
                  await launchUrl(web);
                }
              } else {
                final web = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');
                await launchUrl(web);
              }
            },
          ),
          ListTile(
            leading: SizedBox(width: 28, height: 28, child: SvgPicture.asset('assets/img/waze_icon.svg', semanticsLabel: 'Waze', placeholderBuilder: (_) => const Icon(Icons.navigation, size: 28))),
            title: const Text('Abrir en Waze'),
            onTap: () async {
              Navigator.of(ctx).pop();
              if (lat != null && lng != null) {
                final native = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
                final web = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
                if (await canLaunchUrl(native)) {
                  await launchUrl(native);
                } else {
                  await launchUrl(web);
                }
              } else {
                final web = Uri.parse('https://waze.com/ul?q=$encodedAddress');
                await launchUrl(web);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('Abrir en el navegador'),
            onTap: () async {
              Navigator.of(ctx).pop();
              final web = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');
              await launchUrl(web);
            },
          ),
        ]),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Contenido principal con padding superior para evitar superposición
          Padding(
            padding: const EdgeInsets.only(top: 80.0), // Aumentado de 60 a 80 para más espacio
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(child: Text(error!))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // Global filter toggle: Turno (default) or Urgencia. This controls
                    // the 'filtro' sent to the backend. Placed above the other filters.
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(children: [
                        const Text('Farmacia:',style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        Row(children: [
                          _buildFilterButton('turnos', Icons.calendar_today, 'Turno'),
                          const SizedBox(width: 8),
                          _buildFilterButton('urgencia', Icons.local_hospital, 'Urgencia'),
                        ]),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: fechas.isEmpty
                            ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<String>(
                isExpanded: true,
                                initialValue: fechaSeleccionada,
                                items: fechas.map<DropdownMenuItem<String>>((f) {
                                  if (f is Map && f['id'] != null && f['label'] != null) {
                                    return DropdownMenuItem(value: f['id'], child: Text(f['label']));
                                  }
                                  // fallback: if f is a string, use it as both id and label
                                  final label = f is String ? f : f.toString();
                                  return DropdownMenuItem(value: label, child: Text(label));
                                }).toList(),
                                // After choosing fecha, set and try search
                                onChanged: (v) { setState(() { fechaSeleccionada = v; }); WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBuscar()); },
                                decoration: const InputDecoration(labelText: 'Fecha de turno'),
                              ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: regionSeleccionada,
                        items: regiones.map<DropdownMenuItem<String>>((r) => DropdownMenuItem(value: r['id'].toString(), child: Text(r['nombre']))).toList(),
                        onChanged: (v) {
                          setState(() {
                            regionSeleccionada = v;
                            // clear comuna selection when region changes
                            comunas = [];
                            comunaSeleccionada = null;
                          });
                          if (v != null) _loadComunas(v);
                          WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBuscar());
                        },
                        decoration: const InputDecoration(labelText: 'Región', hintText: 'Selecciona región'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: comunaSeleccionada,
                        items: comunas.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['nombre']))).toList(),
                        onChanged: (v) { setState(() { comunaSeleccionada = v; }); WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBuscar()); },
                        decoration: const InputDecoration(labelText: 'Comuna'),
                      ),
                    ),
                    // Device time status line (simple, under filters) - moved below Comuna
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Row(children: [
                        const Icon(Icons.notifications_active, size: 18, color: Colors.black54),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Hora del dispositivo:', style: Theme.of(context).textTheme.bodySmall)),
                        const SizedBox(width: 8),
                        Text('${_deviceTime.hour.toString().padLeft(2, '0')}:${_deviceTime.minute.toString().padLeft(2, '0')}:${_deviceTime.second.toString().padLeft(2, '0')}', style: Theme.of(context).textTheme.bodySmall)
                      ]),
                    ),
                    // Button removed: searches now run automatically when selections are complete
                    if (farmacias.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 32.0),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: farmacias.length,
                          itemBuilder: (context, idx) {
                            final item = farmacias[idx];
                            // item shape: { 'f': localResp, 'horario': {...}, 'raw': original }
                            final raw = (item['raw'] ?? <String, dynamic>{}) as Map<String, dynamic>;
                            final f = (item['f'] ?? <String, dynamic>{}) as Map<String, dynamic>;
                            final mergedF = <String, dynamic>{}..addAll(raw)..addAll(f);
                            final horario = (item['horario'] ?? <String, dynamic>{}) as Map<String, dynamic>;
                            return PharmacyCard(
                              f: mergedF,
                              horario: horario,
                              comunasMap: comunasMap,
                              regionesMap: regionesMap,
                              titulosTipos: titulosTipos,
                              iconosTipos: iconosTipos,
                              disableNetworkImages: widget.disableNetworkImages,
                            );
                          },
                        ),
                      ),
                    if (!cargando && farmacias.isEmpty)
                      const Padding(padding: EdgeInsets.only(top: 32.0), child: Center(child: Text('No se encontraron farmacias.'))),
                    // App version displayed at the bottom
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
                      child: Center(child: Text(
                        MyApp.packageVersion.isNotEmpty
                          ? (MyApp.packageBuild.isNotEmpty ? 'Version: ${MyApp.packageVersion} (build ${MyApp.packageBuild})' : 'Version: ${MyApp.packageVersion}')
                          : 'Version: ${MyApp.appVersion.replaceAll(RegExp(r"\s*-\s*"), "-")}',
                        style: Theme.of(context).textTheme.bodySmall)),
                    ),
                  ]),
                ),
          ),
          // Título posicionado en la esquina superior izquierda
          Positioned(
            top: 45.0, // Movido un poco más abajo
            left: 16.0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 8.0), // Padding inferior para separación visual
              child: Text(
                'NearPharma',
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
