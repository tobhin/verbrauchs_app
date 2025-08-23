// Datei: lib/screens/favorites_screen.dart

import 'package:flutter/material.dart';
import '../models/meter.dart';
import '../models/meter_type.dart';
import '../services/database_service.dart';
import '../utils/icon_mapper.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<Meter>> _metersFuture;
  Map<int, MeterType> _meterTypes = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _metersFuture = AppDb.instance.fetchMeters(onlyActive: false);
      _loadMeterTypes();
    });
  }

  Future<void> _loadMeterTypes() async {
    final types = await AppDb.instance.fetchMeterTypes();
    if (mounted) {
      setState(() {
        _meterTypes = {for (var type in types) type.id!: type};
      });
    }
  }

  Future<void> _toggleFavorite(Meter meter) async {
    await AppDb.instance.updateMeterFavoriteStatus(meter.id!, !meter.isFavorite);
    _loadData(); // Lädt die Liste neu, um den geänderten Status anzuzeigen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoriten verwalten'),
      ),
      body: FutureBuilder<List<Meter>>(
        future: _metersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _meterTypes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Keine Zähler gefunden.'));
          }

          final meters = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: meters.length,
            itemBuilder: (context, index) {
              final meter = meters[index];
              final meterType = _meterTypes[meter.meterTypeId];
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: SwitchListTile(
                  title: Text(meter.name),
                  subtitle: Text(meter.number ?? 'Keine Zählernummer'),
                  secondary: Icon(IconMapper.getIcon(meterType?.iconName ?? 'question_mark')),
                  value: meter.isFavorite,
                  onChanged: (bool value) {
                    _toggleFavorite(meter);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}