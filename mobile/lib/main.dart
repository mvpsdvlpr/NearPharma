
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const BuscaFarmaciaApp());
}

class BuscaFarmaciaApp extends StatelessWidget {
  const BuscaFarmaciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BuscaFarmacia',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Filtros y datos
  List<dynamic> tipos = [];
  String? tipoSeleccionado;
  List<dynamic> fechas = [];
  String? fechaSeleccionada;
  List<dynamic> regiones = [];
  String? regionSeleccionada;
  List<dynamic> comunas = [];
  String? comunaSeleccionada;
  List<dynamic> farmacias = [];
  bool cargando = false;
  double? userLat;
  double? userLng;


  // Cargar la URL base desde variables de entorno (usando flutter_dotenv)
  late final String apiBaseUrl;

  @override
  void initState() {
    super.initState();
    // Cargar dotenv antes de cualquier request
    _loadEnv().then((_) {
      _initFiltros();
      _getUserLocation();
    });
  }

  Future<void> _loadEnv() async {
    // flutter_dotenv debe estar en pubspec.yaml
    try {
      // ignore: import_of_legacy_library_into_null_safe
      await Future.delayed(Duration.zero); // placeholder para dotenv.load()
      // apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3001/api';
      apiBaseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3001/api');
    } catch (e) {
      apiBaseUrl = 'http://localhost:3001/api';
    }
  }

  Future<void> _initFiltros() async {
    setState(() { cargando = true; });
    // Cargar tipos de farmacia (fijos para MVP):
    tipos = [
      { 'id': 'turnos', 'nombre': 'Turno' },
      { 'id': 'dia', 'nombre': 'Día' },
      { 'id': 'noche', 'nombre': 'Noche' },
      { 'id': '24hrs', 'nombre': '24 Horas' },
    ];
    tipoSeleccionado = tipos.isNotEmpty ? tipos[0]['id'] : null;
    // Cargar regiones
    final regionesResp = await http.get(Uri.parse('[200mapiBaseUrl/regions[0m'));
    if (regionesResp.statusCode == 200) {
      regiones = json.decode(regionesResp.body);
    }
    setState(() { cargando = false; });
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      userLat = pos.latitude;
      userLng = pos.longitude;
    });
  }

  Future<void> _cargarComunas(String regionId) async {
    setState(() { comunas = []; comunaSeleccionada = null; });
    final resp = await http.get(Uri.parse('[200mapiBaseUrl/communes?region=$regionId[0m'));
    if (resp.statusCode == 200) {
      comunas = json.decode(resp.body);
      setState(() {});
    }
  }

  Future<void> _buscarFarmacias() async {
    if (regionSeleccionada == null || comunaSeleccionada == null || tipoSeleccionado == null) return;
    setState(() { cargando = true; farmacias = []; });
    final url = Uri.parse('[200mapiBaseUrl/pharmacies?region=$regionSeleccionada&comuna=$comunaSeleccionada&tipo=$tipoSeleccionado${userLat != null && userLng != null ? '&lat=$userLat&lng=$userLng' : ''}[0m');
    final resp = await http.get(url);
    if (resp.statusCode == 200) {
      farmacias = json.decode(resp.body);
    }
    setState(() { cargando = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BuscaFarmacia'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filtros
            DropdownButtonFormField<String>(
              value: tipoSeleccionado,
              items: tipos.map<DropdownMenuItem<String>>((t) => DropdownMenuItem(
                value: t['id'],
                child: Text(t['nombre'] ?? t['id']),
              )).toList(),
              onChanged: (v) => setState(() { tipoSeleccionado = v; }),
              decoration: const InputDecoration(labelText: 'Tipo de farmacia'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: regionSeleccionada,
              items: regiones.map<DropdownMenuItem<String>>((r) => DropdownMenuItem(
                value: r['id'],
                child: Text(r['nombre'] ?? r['id']),
              )).toList(),
              onChanged: (v) {
                setState(() { regionSeleccionada = v; });
                if (v != null) _cargarComunas(v);
              },
              decoration: const InputDecoration(labelText: 'Región'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: comunaSeleccionada,
              items: comunas.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(
                value: c['id'],
                child: Text(c['nombre'] ?? c['id']),
              )).toList(),
              onChanged: (v) => setState(() { comunaSeleccionada = v; }),
              decoration: const InputDecoration(labelText: 'Comuna'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: cargando ? null : _buscarFarmacias,
              child: cargando ? const CircularProgressIndicator() : const Text('Buscar farmacias'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: farmacias.isEmpty
                  ? const Center(child: Text('No hay farmacias para mostrar.'))
                  : ListView.builder(
                      itemCount: farmacias.length,
                      itemBuilder: (context, idx) {
                        final f = farmacias[idx];
                        return Card(
                          child: ListTile(
                            title: Text(f['nombre'] ?? 'Farmacia'),
                            subtitle: Text(f['direccion'] ?? ''),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
