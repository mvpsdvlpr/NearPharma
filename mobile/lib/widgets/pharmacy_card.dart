import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../src/logger.dart';
import '../theme.dart';
import '../utils/pill.dart';

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

	const AdaptiveNetworkImage({
		super.key,
		required this.url,
		required this.width,
		required this.height,
		this.fit = BoxFit.contain,
		this.disableNetworkImages = false,
		this.client,
	});

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
					return Image.memory(
						resp.bodyBytes,
						width: widget.width,
						height: widget.height,
						fit: widget.fit,
						errorBuilder: (_, __, ___) => const Icon(Icons.local_pharmacy, color: Colors.grey),
					);
				}
			}
		} catch (e, st) {
			AppLogger.d('AdaptiveNetworkImage._fetchAndRenderSvg failed', e, st);
		} finally {
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
			return FutureBuilder<Widget>(
				future: _fetchAndRenderSvg(),
				builder: (c, snap) {
					if (snap.connectionState != ConnectionState.done) return SizedBox(width: widget.width, height: widget.height);
					return snap.data ?? const Icon(Icons.local_pharmacy, color: Colors.grey);
				},
			);
		}
		final looksSvg = widget.url.toLowerCase().endsWith('.svg');
		if (looksSvg) {
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
	final head = String.fromCharCodes(bytes.take(256));
	final isSvg = assetPath.toLowerCase().endsWith('.svg') || head.toLowerCase().contains('<svg');
			if (isSvg) {
				try {
					return SvgPicture.memory(bytes, width: width, height: height, fit: fit, semanticsLabel: semanticLabel);
				} catch (_) {
					// fallthrough to image
				}
			}
			try {
				return Image.memory(bytes, width: width, height: height, fit: fit);
			} catch (_) {
				return const Icon(Icons.local_pharmacy, color: Colors.grey);
			}
		} catch (e, st) {
			AppLogger.d('AssetSafeImage._loadWidget failed', e, st);
			return const Icon(Icons.local_pharmacy, color: Colors.grey);
		}
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

/// The visible card used in the app. It expects a minimal map "f" with keys used by the original app.
class PharmacyCard extends StatelessWidget {
	final Map<String, dynamic> f;
	final Map<String, dynamic> horario;
	final Map<String, String> comunasMap;
	final Map<String, String> regionesMap;
	final List<String> titulosTipos;
	final List<String> iconosTipos;
	final bool disableNetworkImages;

	const PharmacyCard({
		super.key,
		required this.f,
		required this.horario,
		required this.comunasMap,
		required this.regionesMap,
		required this.titulosTipos,
		required this.iconosTipos,
		this.disableNetworkImages = false,
	});

	String _title() {
		final raw = (f['nm'] ?? f['name'] ?? 'Farmacia').toString();
		// Title-case like the rest of the app (ucwords)
		return raw.split(RegExp(r'\s+')).map((p) => p.isEmpty ? p : (p[0].toUpperCase() + (p.length>1? p.substring(1):''))).join(' ');
	}

	String _address() {
		final cl = f['cl'] ?? f['dr'] ?? f['address'];
		if (cl == null) return '';
		final raw = cl.toString();
		
		// Get comuna and region names
		final comunaId = f['cm']?.toString() ?? '';
		final regionId = f['rg']?.toString() ?? '';
		final comunaNombre = comunasMap[comunaId] ?? '';
		final regionNombre = regionesMap[regionId] ?? '';
		
		// Build complete address
		String address = raw.split(RegExp(r'\s+')).map((p) => p.isEmpty ? p : (p[0].toUpperCase() + (p.length>1? p.substring(1):''))).join(' ');
		
		if (comunaNombre.isNotEmpty) {
			address += ', $comunaNombre';
		}
		if (regionNombre.isNotEmpty) {
			address += ', $regionNombre';
		}
		
		return address;
	}

	String? _iconPath() {
		final img = f['img'] as String?;
		if (img == null || img.isEmpty) return null;
		// app expects 'assets/icons/icon_pharmacy.svg' or remote url
		return img;
	}

	String _phone() {
		final phone = f['tl'] ?? f['telefono'] ?? f['phone'];
		if (phone == null) return '';
		return phone.toString().trim();
	}

	void _openMaps() async {
		final lat = f['lat'];
		final lng = f['lng'];
		final url = (lat != null && lng != null) ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng' : null;
		if (url != null && await canLaunchUrl(Uri.parse(url))) {
			await launchUrl(Uri.parse(url));
		}
	}

	/// Opens location in maps with app selector
	Future<void> _openLocationInMaps(BuildContext context, String lat, String lng, String pharmacyName) async {
		// Clean pharmacy name for URL encoding
		final cleanName = Uri.encodeComponent(pharmacyName.trim());
		
		// List of map options to try in order of preference
		final mapOptions = [
			// Android native maps with app selector
			'geo:$lat,$lng?q=$lat,$lng($cleanName)',
			// Google Maps web URL
			'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
			// Alternative Google Maps format
			'https://maps.google.com/?q=$lat,$lng',
			// OpenStreetMap fallback
			'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng&zoom=16',
		];
		
		for (final uriString in mapOptions) {
			try {
				final uri = Uri.parse(uriString);
				// Try to launch without checking canLaunchUrl first
				// This avoids the "component name is null" logs
				await launchUrl(
					uri,
					mode: LaunchMode.externalApplication,
				);
				// If we get here, launch was successful
				AppLogger.d('Successfully opened maps with: $uriString');
				return;
			} catch (e) {
				// Continue to next option
				AppLogger.d('Failed to open maps with $uriString: $e');
				continue;
			}
		}
		
		// If all options failed, show user-friendly message
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text('No se pudo abrir la aplicación de mapas. Coordenadas: $lat, $lng'),
				action: SnackBarAction(
					label: 'Copiar',
					onPressed: () {
						Clipboard.setData(ClipboardData(text: '$lat, $lng'));
						ScaffoldMessenger.of(context).showSnackBar(
							const SnackBar(content: Text('Coordenadas copiadas al portapapeles')),
						);
					},
				),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		final title = _title();
		final address = _address();
		final icon = _iconPath();

		return Card(
			margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
			child: InkWell(
				onTap: _openMaps,
				child: Padding(
					padding: const EdgeInsets.all(12),
					child: Row(
						children: [
							Container(
								width: 56,
								height: 56,
								clipBehavior: Clip.hardEdge,
								decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppColors.muted),
								child: icon == null
										? Image.asset(
												'assets/icons/glyph-cross-rounded.png',
												width: 32,
												height: 32,
												fit: BoxFit.contain,
											)
										: (icon.startsWith('http') && !kUseBundledImages
												? AdaptiveNetworkImage(url: icon, width: 56, height: 56, disableNetworkImages: disableNetworkImages)
												: AssetAdaptiveImage(assetPath: icon.startsWith('assets/') ? icon : 'assets/icons/$icon', width: 56, height: 56)),
							),
							const SizedBox(width: 12),
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										// 1. Nombre farmacia
										Text(title, style: theme.textTheme.titleLarge),
										const SizedBox(height: 4),
										
										// 2. Dirección
										Text(address, style: theme.textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
										const SizedBox(height: 6),
										
										// 3. Fecha turno (campo turno de horario)
										Builder(builder: (context) {
											final turno = horario['turno'];
											if (turno != null && turno.toString().trim().isNotEmpty) {
												// Helper function to clean HTML tags from text
												String cleanHtmlText(String text) {
													return text
														.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
														.replaceAll(RegExp(r'<[^>]*>'), '')
														.replaceAll(RegExp(r'\s+'), ' ')
														.trim();
												}
												
												String turnoText = cleanHtmlText(turno.toString());
												if (turnoText.isNotEmpty) {
													return Padding(
														padding: const EdgeInsets.only(bottom: 6),
														child: Column(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																Row(
																	children: [
																		Icon(Icons.calendar_today, size: 14, color: theme.hintColor),
																		const SizedBox(width: 6),
																		Text(
																			'Fecha turno:',
																			style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
																		),
																	],
																),
																const SizedBox(height: 2),
																Padding(
																	padding: const EdgeInsets.only(left: 20),
																	child: Text(
																		turnoText,
																		style: theme.textTheme.bodySmall,
																		maxLines: 1,
																		overflow: TextOverflow.ellipsis,
																	),
																),
															],
														),
													);
												}
											}
											return const SizedBox.shrink();
										}),
										
										// 4. Horario Semanal (semana y dia)
										Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Row(
													children: [
														Icon(Icons.access_time, size: 14, color: theme.hintColor),
														const SizedBox(width: 6),
														Text(
															'Horarios:',
															style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
														),
													],
												),
												const SizedBox(height: 2),
												Builder(builder: (context) {
													// Show available horario information (semana and dia)
													List<Widget> horarioWidgets = [];
													
													// Helper function to clean HTML tags from text
													String cleanHtmlText(String text) {
														return text
															.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
															.replaceAll(RegExp(r'<[^>]*>'), '')
															.replaceAll(RegExp(r'\s+'), ' ')
															.trim();
													}
													
													// Add semana if exists
													if (horario['semana'] != null && horario['semana'].toString().trim().isNotEmpty) {
														String semanaText = cleanHtmlText(horario['semana'].toString());
														if (semanaText.isNotEmpty) {
															horarioWidgets.add(
																Padding(
																	padding: const EdgeInsets.only(left: 20),
																	child: Text(
																		semanaText,
																		style: theme.textTheme.bodySmall,
																		maxLines: 4,
																		overflow: TextOverflow.ellipsis,
																	),
																),
															);
														}
													}
													
													// Add dia if exists
													if (horario['dia'] != null && horario['dia'].toString().trim().isNotEmpty) {
														String diaText = cleanHtmlText(horario['dia'].toString());
														if (diaText.isNotEmpty) {
															if (horarioWidgets.isNotEmpty) {
																horarioWidgets.add(const SizedBox(height: 2));
															}
															horarioWidgets.add(
																Padding(
																	padding: const EdgeInsets.only(left: 20),
																	child: Text(
																		diaText,
																		style: theme.textTheme.bodySmall,
																		maxLines: 4,
																		overflow: TextOverflow.ellipsis,
																	),
																),
															);
														}
													}
													
													if (horarioWidgets.isEmpty) {
														horarioWidgets.add(
															Padding(
																padding: const EdgeInsets.only(left: 20),
																child: Text(
																	'Horario no disponible',
																	style: theme.textTheme.bodySmall,
																),
															),
														);
													}
													
													return Column(
														crossAxisAlignment: CrossAxisAlignment.start,
														children: horarioWidgets,
													);
												}),
											],
										),
										const SizedBox(height: 6),
										
										// 5. Teléfono
										Builder(builder: (context) {
											final phone = _phone();
											if (phone.isNotEmpty) {
												return Padding(
													padding: const EdgeInsets.only(bottom: 6),
													child: Column(
														crossAxisAlignment: CrossAxisAlignment.start,
														children: [
															Row(
																children: [
																	Icon(Icons.phone, size: 14, color: theme.hintColor),
																	const SizedBox(width: 6),
																	Text(
																		'Teléfono:',
																		style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
																	),
																],
															),
															const SizedBox(height: 2),
															Padding(
																padding: const EdgeInsets.only(left: 20),
																child: Text(phone, style: theme.textTheme.bodySmall),
															),
														],
													),
												);
											}
											return const SizedBox.shrink();
										}),
										
										// 6. Botón "¿Cómo llegar?"
										Builder(builder: (context) {
											final lat = f['lt'] ?? f['lat'];
											final lng = f['lg'] ?? f['lng'];
											if (lat != null && lng != null) {
												return Padding(
													padding: const EdgeInsets.only(top: 8, bottom: 8),
													child: SizedBox(
														width: double.infinity,
														child: ElevatedButton.icon(
															onPressed: () async {
																await _openLocationInMaps(context, lat.toString(), lng.toString(), _title());
															},
															icon: const Icon(Icons.map, size: 16),
															label: const Text('¿Cómo llegar?'),
															style: ElevatedButton.styleFrom(
																padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
															),
														),
													),
												);
											}
											return const SizedBox.shrink();
										}),
										
										// 7. Pill (tipo de farmacia)
										Builder(builder: (c) {
											try {
												// Attempt to get a readable tipoNombre from tp index
												final tpRaw = f['tp']?.toString();
												int? tpIdx;
												if (tpRaw != null) tpIdx = int.tryParse(tpRaw);
												String tipoNombre = '';
												if (tpIdx != null && tpIdx >= 0 && tpIdx < titulosTipos.length) {
													tipoNombre = titulosTipos[tpIdx];
												}

												// Use utility to derive pill text/color from maps. We pass
												// `tipoNombre` as a hint; `filtroActual` is unknown here so
												// we pass empty string — the util will still prioritize
												// explicit server fields.
												final pill = derivePillFromResponse(Map<String, dynamic>.from(f), Map<String, dynamic>.from(horario), false, tipoNombre, '');
												final pillText = (pill['text'] ?? '').toString();
												final pillColor = pill['color'] as Color? ?? Colors.green.shade600;

												if (pillText.isNotEmpty) {
													return Container(
														// Slightly more compact pill so it doesn't dominate the
														// card while remaining single-line and readable.
														constraints: const BoxConstraints(minWidth: 56, maxWidth: 200, minHeight: 28),
														padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
														decoration: BoxDecoration(color: pillColor, borderRadius: BorderRadius.circular(8)),
														alignment: Alignment.center,
														child: Text(
															pillText,
															style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
															maxLines: 1,
															overflow: TextOverflow.ellipsis,
															textAlign: TextAlign.center,
															softWrap: false,
															strutStyle: StrutStyle(forceStrutHeight: true, height: 1.0),
														),
													);
												}
											} catch (_) {}
											return const SizedBox.shrink();
										}),
									],
								),
							),
						],
					),
				),
			),
		);
	}
}
