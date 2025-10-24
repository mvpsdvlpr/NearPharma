import 'package:flutter/material.dart';
import '../widgets/pharmacy_card.dart';

class PharmacyDemoPage extends StatelessWidget {
  const PharmacyDemoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mock = [
      {
        'name': 'Farmacia Central',
        'today': '09:00 - 22:00',
        'week': ['Lun: 09:00-22:00', 'Mar: 09:00-22:00', 'Mie: 09:00-22:00', 'Jue: 09:00-22:00', 'Vie: 09:00-22:00', 'Sab: 10:00-20:00', 'Dom: 10:00-18:00'],
        'address': 'Av. Principal 123, Santiago',
        'status': 'Turno',
      },
      {
        'name': 'Farmacia Urgencias',
        'today': '24 horas',
        'week': ['Lun: 00:00-23:59', 'Mar: 00:00-23:59', 'Mie: 00:00-23:59', 'Jue: 00:00-23:59', 'Vie: 00:00-23:59', 'Sab: 00:00-23:59', 'Dom: 00:00-23:59'],
        'address': 'Calle Urgente 45, Santiago',
        'status': 'Urgencia',
      }
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Demo - Farmacias')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: mock.length,
        itemBuilder: (context, idx) {
          final item = mock[idx];
          return PharmacyCard(
            name: item['name']!,
            todayHours: item['today']!,
            weekSchedule: List<String>.from(item['week']!),
            address: item['address']!,
            status: item['status']!,
          );
        },
      ),
    );
  }
}
