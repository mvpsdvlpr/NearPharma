import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
// 'dart:typed_data' not needed explicitly; ByteData/Uint8List available via services import
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../src/logger.dart';

// Use bundled images during tests/development to avoid remote downloads.
const bool kUseBundledImages = true;

// Utility: convert HSL (h in 0..360, s and l in 0..100) to a Flutter Color.
Color hslToColor(double h, double s, double l) {
  s /= 100;
  l /= 100;
  final c = (1 - (2 * l - 1).abs()) * s;
  final x = c * (1 - ((h / 60) % 2 - 1).abs());
  final m = l - c / 2;
  double r = 0, g = 0, b = 0;
  if (0 <= h && h < 60) {
    r = c;
    g = x;
    b = 0;
  } else if (60 <= h && h < 120) {
    r = x;
    g = c;
    b = 0;
  } else if (120 <= h && h < 180) {
    r = 0;
    g = c;
    b = x;
  } else if (180 <= h && h < 240) {
    r = 0;
    g = x;
    b = c;
  } else if (240 <= h && h < 300) {
    r = x;
    g = 0;
    b = c;
  } else {
    r = c;
    g = 0;
    b = x;
  }
  final R = ((r + m) * 255).round();
  final G = ((g + m) * 255).round();
  final B = ((b + m) * 255).round();
  return Color.fromARGB(255, R.clamp(0, 255), G.clamp(0, 255), B.clamp(0, 255));
}

final Color kPrimaryColor = hslToColor(142, 76, 36);
final Color kPrimaryForeground = hslToColor(0, 0, 100);
final Color kDestructiveColor = hslToColor(0, 84, 60);
final Color kDestructiveForeground = hslToColor(0, 0, 98);

/// Minimal adaptive network image that prefers SVG when possible.
class AdaptiveNetworkImage extends StatefulWidget {
  final String url;
  final double width;
  final double height;
  final BoxFit fit;
  final bool disableNetworkImages;
  final http.Client? client;

  const AdaptiveNetworkImage({super.key, required this.url, required this.width, required this.height, this.fit = BoxFit.contain, this.disableNetworkImages = false, this.client});

  @override
  State<AdaptiveNetworkImage> createState() => _AdaptiveNetworkImageState();
}

class _AdaptiveNetworkImageState extends State<AdaptiveNetworkImage> {
  String? _type; // 'svg' | 'raster' | 'disabled'
  Uint8List? _bytes;

  Future<Widget> _fetchAndRenderSvg() async {
    http.Client? local;
    final client = widget.client ?? (local = http.Client());
    try {
      final uri = Uri.tryParse(widget.url);
      if (uri == null) return const Icon(Icons.local_pharmacy, color: Colors.grey);
      final resp = await client.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        try {
          return SvgPicture.memory(resp.bodyBytes, width: widget.width, height: widget.height, fit: widget.fit);
        } catch (e, st) {
          AppLogger.d('AdaptiveNetworkImage._fetchAndRenderSvg failed', e, st);
          return Image.memory(resp.bodyBytes, width: widget.width, height: widget.height, fit: widget.fit, errorBuilder: (_, __, ___) => const Icon(Icons.local_pharmacy, color: Colors.grey));
        }
      }
    } catch (e, st) {
      AppLogger.d('AdaptiveNetworkImage._fetchAndRenderSvg failed', e, st);
    }
    finally {
      if (local != null) local.close();
    }
    return const Icon(Icons.local_pharmacy, color: Colors.grey);
  }

  @override
  void initState() {
    super.initState();
    if (widget.disableNetworkImages) {
      _type = 'disabled';
    } else {
      _detect();
    }
  }

  Future<void> _detect() async {
    final uri = Uri.tryParse(widget.url);
    final looksSvg = widget.url.toLowerCase().endsWith('.svg');
    http.Client? local;
    final client = widget.client ?? (local = http.Client());
    try {
      if (uri == null) {
        setState(() => _type = 'raster');
        return;
      }
      final head = await client.head(uri).timeout(const Duration(seconds: 5));
      final ct = head.headers['content-type'] ?? '';
      if (head.statusCode == 200 && ct.contains('svg')) {
        final get = await client.get(uri).timeout(const Duration(seconds: 8));
        if (get.statusCode == 200 && get.bodyBytes.isNotEmpty) {
          _bytes = get.bodyBytes;
          setState(() => _type = 'svg');
          return;
        }
      }
      if (looksSvg) {
        // try fetch bytes
        try {
          final get = await client.get(uri).timeout(const Duration(seconds: 8));
          if (get.statusCode == 200 && get.bodyBytes.isNotEmpty) {
            _bytes = get.bodyBytes;
            setState(() => _type = 'svg');
            return;
          }
        } catch (e, st) {
            AppLogger.d('AdaptiveNetworkImage._detect: head/get failed', e, st);
        }
      }
      setState(() => _type = 'raster');
    } catch (_) {
      // conservative fallback
      setState(() => _type = looksSvg ? 'svg' : 'raster');
    } finally {
      if (local != null) local.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_type == 'disabled') return SizedBox(width: widget.width, height: widget.height);
    if (_type == null) return SizedBox(width: widget.width, height: widget.height);
    if (_type == 'svg') {
      if (_bytes != null) {
        try {
          return SvgPicture.memory(_bytes!, width: widget.width, height: widget.height, fit: widget.fit);
        } catch (e, st) {
          AppLogger.d('AdaptiveNetworkImage build svg bytes failed', e, st);
        }
      }
      // Avoid using SvgPicture.network which performs its own HttpClient fetch and can throw in test environments.
      return FutureBuilder<Widget>(
        future: _fetchAndRenderSvg(),
        builder: (c, snap) {
          if (snap.connectionState != ConnectionState.done) return SizedBox(width: widget.width, height: widget.height);
          return snap.data ?? const Icon(Icons.local_pharmacy, color: Colors.grey);
        },
      );
    }
    // If the URL looks like an SVG but detection classified it as raster, prefer to try SvgPicture.network
    final looksSvg = widget.url.toLowerCase().endsWith('.svg');
    if (looksSvg) {
      // Prefer to fetch via our HTTP client and render safely; avoid SvgPicture.network.
      return FutureBuilder<Widget>(
        future: _fetchAndRenderSvg(),
        builder: (c, snap) {
          if (snap.connectionState != ConnectionState.done) return SizedBox(width: widget.width, height: widget.height);
          return snap.data ?? const Icon(Icons.local_pharmacy, color: Colors.grey);
        },
      );
    }
    return Image.network(widget.url, width: widget.width, height: widget.height, fit: widget.fit, errorBuilder: (_, __, ___) => const Icon(Icons.local_pharmacy, color: Colors.grey));
  }
}

/// Load asset (svg or raster) safely: tries original path, then alternative extension, then placeholders.
class AssetAdaptiveImage extends StatelessWidget {
  final String assetPath;
  final double width;
  final double height;
  final BoxFit fit;
  const AssetAdaptiveImage({super.key, required this.assetPath, required this.width, required this.height, this.fit = BoxFit.contain});

  Future<Map<String, dynamic>?> _resolveBytes() async {
    Future<Uint8List?> tryLoad(String p) async {
      try {
        final b = await rootBundle.load(p);
        return b.buffer.asUint8List();
          } catch (e, st) {
          AppLogger.d('AssetAdaptiveImage._resolveBytes: tryLoad alternative failed', e, st);
          return null;
          }
    }

    final orig = assetPath;
  final o = await tryLoad(orig);
    if (o != null) return {'bytes': o, 'used': orig};

    if (orig.toLowerCase().endsWith('.svg')) {
  final alt = '${orig.substring(0, orig.length - 4)}.png';
  final a = await tryLoad(alt);
      if (a != null) return {'bytes': a, 'used': alt};
    } else if (orig.contains('.')) {
      final alt = orig.replaceFirst(RegExp(r'\.[^./]+\$'), '.svg');
  final a = await tryLoad(alt);
      if (a != null) return {'bytes': a, 'used': alt};
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _resolveBytes(),
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return SizedBox(width: width, height: height);
        final map = s.data;
        if (map == null) {
          // prefer a compact raster placeholder (map.png) when available — use AssetSafeImage to avoid decode crashes
          return AssetSafeImage(assetPath: 'assets/img/map.png', width: width, height: height, fit: fit);
        }
        final bytes = map['bytes'] as Uint8List?;
        final used = map['used'] as String? ?? assetPath;
        if (bytes == null) return const Icon(Icons.local_pharmacy, color: Colors.grey);
        final head = String.fromCharCodes(bytes.take(256));
        final looksSvg = used.toLowerCase().endsWith('.svg') || head.toLowerCase().contains('<svg');
        if (looksSvg) {
          try {
            return SvgPicture.memory(bytes, width: width, height: height, fit: fit);
          } catch (_) {
            try {
              return Image.memory(bytes, width: width, height: height, fit: fit);
            } catch (_) {
              return const Icon(Icons.local_pharmacy, color: Colors.grey);
            }
          }
        }
        try {
          return Image.memory(bytes, width: width, height: height, fit: fit);
        } catch (_) {
          try {
            return SvgPicture.memory(bytes, width: width, height: height, fit: fit);
          } catch (_) {
            return const Icon(Icons.local_pharmacy, color: Colors.grey);
          }
        }
      },
    );
  }
}

/// Safely load an asset's bytes and render an appropriate widget without letting invalid bytes crash the engine.
class AssetSafeImage extends StatelessWidget {
  final String assetPath;
  final double width;
  final double height;
  final BoxFit fit;
  final String? semanticLabel;
  const AssetSafeImage({super.key, required this.assetPath, required this.width, required this.height, this.fit = BoxFit.contain, this.semanticLabel});

  Future<Widget> _loadWidget() async {
    try {
      final bd = await rootBundle.load(assetPath);
      final bytes = bd.buffer.asUint8List();
      if (bytes.length < 4) return const Icon(Icons.local_pharmacy, color: Colors.grey);
      // Signatures
      final isPng = bytes.length >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
      final isJpeg = bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
      final isWebP = bytes.length >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 && bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50;
      final head = String.fromCharCodes(bytes.take(256));
      final isSvg = assetPath.toLowerCase().endsWith('.svg') || head.toLowerCase().contains('<svg');

      if (isSvg) {
        try {
          return SvgPicture.memory(bytes, width: width, height: height, fit: fit);
        } catch (_) {
          return const Icon(Icons.local_pharmacy, color: Colors.grey);
        }
      }

      if (isPng || isJpeg || isWebP) {
        try {
          return Image.memory(bytes, width: width, height: height, fit: fit);
        } catch (_) {
          return const Icon(Icons.local_pharmacy, color: Colors.grey);
        }
      }

      // Unknown format: try SVG first, then raster — if both fail, fallback to icon
      try {
        return SvgPicture.memory(bytes, width: width, height: height, fit: fit);
      } catch (_) {}
      try {
        return Image.memory(bytes, width: width, height: height, fit: fit);
      } catch (_) {}
    } catch (_) {}
    return const Icon(Icons.local_pharmacy, color: Colors.grey);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _loadWidget(),
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return SizedBox(width: width, height: height);
        return s.data ?? const Icon(Icons.local_pharmacy, color: Colors.grey);
      },
    );
  }
}

/// Minimal, modern PharmacyCard.
class PharmacyCard extends StatelessWidget {
  final Map<String, dynamic> f;
  final Map<String, dynamic> horario;
  final Map<String, String> comunasMap;
  final Map<String, String> regionesMap;
  final List<String> titulosTipos;
  final List<String> iconosTipos;
  final bool disableNetworkImages;

  const PharmacyCard({super.key, required this.f, required this.horario, required this.comunasMap, required this.regionesMap, required this.titulosTipos, required this.iconosTipos, this.disableNetworkImages = false});

  String ucwords(String s) => s.split(RegExp(r'\s+')).map((p) => p.isEmpty ? p : (p[0].toUpperCase() + (p.length>1? p.substring(1):''))).join(' ');

  String _stripHtml(String? s) {
    if (s == null) return '';
    var t = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    t = t.replaceAll(RegExp(r'<[^>]+>'), '');
    return t.trim();
  }

  @override
  Widget build(BuildContext context) {
    final nombre = ucwords((f['nm'] ?? '').toString());
    final direccion = ucwords((f['dr'] ?? '').toString());
    final comunaId = f['cm']?.toString() ?? '';
    final regionId = f['rg']?.toString() ?? '';
    final comunaNombre = comunasMap[comunaId] ?? comunaId;
    final regionNombre = regionesMap[regionId] ?? regionId;
      final telefonoLocal = f['tl'] ?? ''; // renamed variable
    final horarioDia = horario['dia'] != null ? _stripHtml(horario['dia'].toString()) : '';
    final imgPath = f['img'];
  final logo = (imgPath != null && imgPath.toString().isNotEmpty)
    ? 'https://seremienlinea.minsal.cl/asdigital/mfarmacias/mapa.php?imagen=$imgPath'
        : 'https://seremienlinea.minsal.cl/asdigital/mfarmacias/img/logo.svg';

  final Widget logoWidget = disableNetworkImages
    ? const SizedBox(width: 48, height: 48)
    : (kUseBundledImages
          ? ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AssetSafeImage(assetPath: 'assets/img/map.png', width: 48, height: 48, fit: BoxFit.cover, semanticLabel: 'Mapa (vista previa)'),
        )
      : AdaptiveNetworkImage(url: logo, width: 48, height: 48, fit: BoxFit.contain, disableNetworkImages: disableNetworkImages));

    String pillText = '';
    Widget iconWidget = const SizedBox.shrink();
    try {
      final tpIdx = int.parse((f['tp'] ?? f['tp']?.toString() ?? '-1').toString());
      if (tpIdx >= 0 && tpIdx < titulosTipos.length) pillText = titulosTipos[tpIdx];
      if (tpIdx >= 0 && tpIdx < iconosTipos.length) {
        final tipoIcon = iconosTipos[tpIdx];
        final iconUrl = 'https://seremienlinea.minsal.cl/asdigital/mfarmacias/img/i${tipoIcon}b.png';
        iconWidget = disableNetworkImages
            ? const SizedBox.shrink()
            : (kUseBundledImages
                ? AssetAdaptiveImage(assetPath: 'assets/img/i${tipoIcon}b.png', width: 15, height: 15, fit: BoxFit.contain)
                : AdaptiveNetworkImage(url: iconUrl, width: 15, height: 15, fit: BoxFit.contain, disableNetworkImages: disableNetworkImages));
        if (tipoIcon == 'turnos') pillText = 'Turno';
      }
    } catch (e, st) {
      AppLogger.d('Failed to compute pill/icon for local entry', e, st);
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header: title + map pin icon
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(nombre, style: Theme.of(context).textTheme.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            // Use the provided app icon as a map-pin substitute
            SizedBox(width: 28, height: 28, child: SvgPicture.asset('assets/icons/icon_pharmacy.svg', width: 28, height: 28, color: Theme.of(context).iconTheme.color)),
          ]),
          const SizedBox(height: 8),

          // Today's hours
          if (horarioDia.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Text(
                '${_weekdaySpanish(DateTime.now().weekday)}: $horarioDia',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),

          // Weekly schedule (best-effort extraction)
          Builder(builder: (ctx) {
            final week = _extractWeekSchedule(horario);
            if (week.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Horario Semanal', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ...week.map((s) => Text(s, style: Theme.of(context).textTheme.bodySmall)),
              ]),
            );
          }),

          // Address
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text('Dirección: $direccion', style: Theme.of(context).textTheme.bodyMedium),
          ),

          // Footer: directions button + status badge
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            OutlinedButton.icon(
              onPressed: () async {
                final query = direccion.isNotEmpty ? direccion : '$comunaNombre, $regionNombre';
                final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e, st) {
                  AppLogger.d('launch maps failed', e, st);
                }
              },
              icon: const Icon(Icons.navigation, size: 16),
              label: const Text('¿Cómo llegar?'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (pillText.toLowerCase().contains('turno')) ? kPrimaryColor : kDestructiveColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(pillText, style: TextStyle(color: (pillText.toLowerCase().contains('turno')) ? kPrimaryForeground : kDestructiveForeground, fontWeight: FontWeight.w700)),
            ),
          ])
        ]),
      ),
    );
  }

  // Helper: weekday in Spanish (lowercase as in design)
  String _weekdaySpanish(int weekday) {
    const names = ['lunes','martes','miércoles','jueves','viernes','sábado','domingo'];
    if (weekday < 1 || weekday > 7) return '';
    return names[weekday - 1];
  }

  // Best-effort weekly schedule extractor. Looks for common keys and returns readable lines.
  List<String> _extractWeekSchedule(Map<String, dynamic> horario) {
    if (horario == null) return [];
    try {
      if (horario is Map) {
        // If explicitly provided as a list
        final maybeList = horario['semana'] ?? horario['week'] ?? horario['horarios'];
        if (maybeList is List) return maybeList.map((e) => e.toString()).toList();

        // Look for day keys
        final keys = ['lunes','martes','miercoles','miércoles','jueves','viernes','sabado','sábado','domingo','lun','mar','mie','jue','vie','sab','dom'];
        final out = <String>[];
        final seen = <String>{};
        for (final key in keys) {
          if (horario.containsKey(key)) {
            final val = horario[key];
            final label = key[0].toUpperCase() + key.substring(1);
            final s = val == null ? '' : val.toString().replaceAll(RegExp(r'<[^>]+>'), '').trim();
            if (s.isNotEmpty && !seen.contains(s)) {
              out.add('$label: $s');
              seen.add(s);
            }
          }
        }
        return out;
      }
    } catch (_) {}
    return [];
  }
}
