// Datei: lib/screens/erfassen_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/meter.dart';
import '../models/meter_type.dart';
import '../models/reading.dart';
import '../services/database_service.dart';
import '../services/ocr_service.dart';
import '../utils/icon_mapper.dart'; // HINZUGEFÜGT: Import für unseren neuen Helfer

class ErfassenScreen extends StatefulWidget {
  const ErfassenScreen({super.key});

  @override
  State<ErfassenScreen> createState() => _ErfassenScreenState();
}

class _ErfassenScreenState extends State<ErfassenScreen> {
  final _formKey = GlobalKey<FormState>();
  List<Meter> _allMeters = [];
  List<Meter> _favoriteMeters = [];
  Map<int, MeterType> _meterTypes = {};
  Meter? _selected;
  MeterType? _selectedMeterType;
  final _valueCtrl = TextEditingController();
  final _htCtrl = TextEditingController();
  final _ntCtrl = TextEditingController();
  String? _imagePath;
  bool _isSaving = false;
  Reading? _lastReading;

  // ENTFERNT: Die lokale _iconMap wurde gelöscht.

  @override
  void initState() {
    super.initState();
    _loadMeters();
  }

  Future<void> _loadMeters() async {
    final allMs = await AppDb.instance.fetchMeters();
    final favMs = await AppDb.instance.fetchMeters(onlyFavorites: true);
    final allTypes = await AppDb.instance.fetchMeterTypes();
    final Map<int, MeterType> typeMap = { for (var type in allTypes) type.id!: type };
    
    if (mounted) {
      setState(() {
        _allMeters = allMs;
        _favoriteMeters = favMs;
        _meterTypes = typeMap;
      });
      if (allMs.isNotEmpty) {
        await _onMeterChanged(allMs.first);
      }
    }
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    _htCtrl.dispose();
    _ntCtrl.dispose();
    super.dispose();
  }

  Future<void> _onMeterChanged(Meter? newMeter) async {
    _valueCtrl.clear();
    _htCtrl.clear();
    _ntCtrl.clear();
    if (context.mounted) FocusScope.of(context).unfocus();

    if (newMeter == null) {
      setState(() {
        _selected = null;
        _selectedMeterType = null;
        _lastReading = null;
      });
      return;
    }

    final meterType = await AppDb.instance.getMeterTypeById(newMeter.meterTypeId);
    final readings = await AppDb.instance.fetchReadingsForMeter(newMeter.id!);
    
    setState(() {
      _selected = newMeter;
      _selectedMeterType = meterType;
      _lastReading = readings.isNotEmpty ? readings.first : null;
    });
  }

  double? _parseNum(String? s) {
    if (s == null || s.isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.').trim());
  }

  Future<void> _pickImage() async {
    // ... (dein restlicher Code in dieser Methode bleibt unverändert) ...
  }

  void _clearImage() => setState(() => _imagePath = null);

  Future<void> _save() async {
    // ... (dein restlicher Code in dieser Methode bleibt unverändert) ...
  }

  Widget _buildQuickTiles(BuildContext context) {
    if(_favoriteMeters.isEmpty) return const SizedBox.shrink();

    List<Widget> cards = _favoriteMeters.map((m) {
      final type = _meterTypes[m.meterTypeId];
      return Expanded(
        child: InkWell(
          onTap: () => _onMeterChanged(m),
          child: Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _selected?.id == m.id 
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
              border: _selected?.id == m.id
                ? Border.all(color: Theme.of(context).colorScheme.primary)
                : null,
            ),
            child: Column(
              children: [
                Icon(
                  // GEÄNDERT: Verwendet jetzt unseren zentralen IconMapper
                  IconMapper.getIcon(type?.iconName ?? 'question_mark'),
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(m.name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      );
    }).toList();
    
    int rows = (cards.length / 2).ceil();
    List<Widget> rowWidgets = [];
    for(int i = 0; i < rows; i++) {
      List<Widget> rowChildren = cards.skip(i * 2).take(2).toList();
      while(rowChildren.length < 2) {
        rowChildren.add(const Expanded(child: SizedBox.shrink()));
      }
      rowWidgets.add(Row(children: rowChildren));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rowWidgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... (dein restlicher build-Code bleibt unverändert) ...
  }
}