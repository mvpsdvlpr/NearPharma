import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
// 'dart:typed_data' not needed explicitly; ByteData/Uint8List available via services import
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// Use bundled images during tests/development to avoid remote downloads.
const bool kUseBundledImages = true;

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
        } catch (_) {
          return Image.memory(resp.bodyBytes, width: widget.width, height: widget.height, fit: widget.fit, errorBuilder: (_, __, ___) => const Icon(Icons.local_pharmacy, color: Colors.grey));
        }
      }
    } catch (_) {}
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
        } catch (_) {}
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
        } catch (_) {
          // fallthrough to a safe placeholder below
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
    Future<Uint8List?> _try(String p) async {
      try {
        final b = await rootBundle.load(p);
        return b.buffer.asUint8List();
      } catch (_) {
        return null;
      }
    }

    final orig = assetPath;
    final o = await _try(orig);
    if (o != null) return {'bytes': o, 'used': orig};

    if (orig.toLowerCase().endsWith('.svg')) {
      final alt = orig.substring(0, orig.length - 4) + '.png';
      final a = await _try(alt);
      if (a != null) return {'bytes': a, 'used': alt};
    } else if (orig.contains('.')) {
      final alt = orig.replaceFirst(RegExp(r'\.[^./]+\$'), '.svg');
      final a = await _try(alt);
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
  // phone may be optional; keep it available for future use
  final telefono = f['tl'] ?? '';
    final horarioDia = horario['dia'] != null ? _stripHtml(horario['dia'].toString()) : '';
    final imgPath = f['img'];
    final logo = (imgPath != null && imgPath.toString().isNotEmpty)
        ? 'https://seremienlinea.minsal.cl/asdigital/mfarmacias/mapa.php?imagen=${imgPath}'
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
    } catch (_) {}

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 56, height: 56, child: logoWidget)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombre, style: Theme.of(context).textTheme.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (horarioDia.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(horarioDia, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
              const SizedBox(height: 8),
              Text(direccion, style: Theme.of(context).textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              Text('$comunaNombre, $regionNombre', style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (telefono.toString().isNotEmpty) Text('Tel: $telefono', style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 16, height: 16, child: iconWidget), const SizedBox(width: 8), Flexible(child: Text(pillText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis))]),
            ),
            const SizedBox(height: 8),
      disableNetworkImages
        ? const SizedBox(width: 20, height: 20)
        : (kUseBundledImages
          ? AssetSafeImage(assetPath: 'assets/img/map.png', width: 20, height: 20, fit: BoxFit.contain, semanticLabel: 'Pin')
          : AssetSafeImage(assetPath: 'assets/img/map.png', width: 20, height: 20, fit: BoxFit.contain, semanticLabel: 'Pin')),
          ])
        )
        ]),
      ),
    );
  }
}
