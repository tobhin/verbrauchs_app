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
import '../services/logger_service.dart';

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
  bool _isScanning = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMeters();
  }

  Future<void> _loadMeters() async {
    try {
      final allMs = await AppDb.instance.fetchMeters();
      final favMs = allMs.where((m) => m.isFavorite == true).toList();
      final allTypes = await AppDb.instance.fetchMeterTypes();
      final Map<int, MeterType> typeMap = {for (var type in allTypes) type.id!: type};

      if (mounted) {
        setState(() {
          _allMeters = allMs;
          _favoriteMeters = favMs;
          _meterTypes = typeMap;
          _isLoading = false;
          _selected = favMs.isNotEmpty ? favMs.first : (allMs.isNotEmpty ? allMs.first : null);
        });
        if (_selected != null) {
          await _onMeterChanged(_selected!);
        }
      }
    } catch (e, st) {
      await Logger.log('[ErfassenScreen] ERROR: Failed to load meters: $e\n$st');
      if (mounted) setState(() => _isLoading = false);
    }
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

    final meterType = await AppDb.instance.fetchMeterTypeById(newMeter.meterTypeId);
    final readings = await AppDb.instance.fetchReadingsForMeter(newMeter.id!);
    final lastReading = readings.isNotEmpty ? readings.first : null;

    if (mounted) {
      setState(() {
        _selected = newMeter;
        _selectedMeterType = meterType;
        _lastReading = lastReading;
      });
    }
  }

  Future<void> _pickImage() async {
    if (await Permission.camera.request().isGranted) {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await File(pickedFile.path).copy(path);
        setState(() {
          _imagePath = path;
        });
      }
    }
  }

  Future<void> _clearImage() async {
    if (_imagePath != null) {
      await File(_imagePath!).delete();
      setState(() {
        _imagePath = null;
      });
    }
  }

Future<void> _scanImage() async {
  if (_imagePath == null) return;
  setState(() => _isScanning = true);
  try {
    // MeterTypeForOcr dynamisch bestimmen
    MeterTypeForOcr meterTypeForOcr = MeterTypeForOcr.wasser;
    if (_selectedMeterType != null) {
      final name = _selectedMeterType!.name.toLowerCase();
      if (name.contains('strom')) {
        meterTypeForOcr = MeterTypeForOcr.strom;
      } else if (name.contains('gas')) {
        meterTypeForOcr = MeterTypeForOcr.gas;
      } else if (name.contains('schmutzwasser')) {
        meterTypeForOcr = MeterTypeForOcr.schmutzwasser;
      }
    }
    final result = await tryOcrSmart(
      imagePath: _imagePath!,
      meterType: meterTypeForOcr,
      meterSerial: _selected?.number,
      lastValue: _lastReading?.value,
    );
    if (result != null) {
      _valueCtrl.text = result.toString();
    }
  } catch (e) {
    await Logger.log('[ErfassenScreen] OCR scan error: $e');
  }
  setState(() => _isScanning = false);
}

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      final value = double.tryParse(_valueCtrl.text.replaceAll(',', '.'));
      final ht = double.tryParse(_htCtrl.text.replaceAll(',', '.'));
      final nt = double.tryParse(_ntCtrl.text.replaceAll(',', '.'));

      await AppDb.instance.insertReading(Reading(
        meterId: _selected!.id!,
        date: DateTime.now(),
        value: value,
        ht: ht,
        nt: nt,
        imagePath: _imagePath,
      ));

      await _clearImage();
      await _onMeterChanged(_selected);

      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zählerstand gespeichert')),
      );
    }
  }

  Widget _buildFavoriteQuickSelect() {
    if (_favoriteMeters.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: _favoriteMeters.map((meter) => GestureDetector(
          onTap: () {
            _onMeterChanged(meter);
          },
          child: Card(
            elevation: _selected == meter ? 6 : 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: _selected == meter ? Colors.blue[100] : Colors.white,
            child: Container(
              width: 130,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getMeterIcon(_meterTypes[meter.meterTypeId]?.name ?? meter.name), size: 36),
                  const SizedBox(height: 10),
                  Text(meter.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  IconData _getMeterIcon(String typeName) {
    switch (typeName.toLowerCase()) {
      case 'gas': return Icons.local_fire_department;
      case 'wasser': return Icons.water_drop;
      case 'strom (ht/nt)': return Icons.bolt;
      case 'schmutzwasser': return Icons.waves;
      default: return Icons.speed;
    }
  }

  String _getUnit(MeterType? type) {
    if (type == null) return '';
    if (type.name.toLowerCase().contains('strom')) return 'kWh';
    return 'm³';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Favoriten-Schnellauswahl als Kacheln
                    _buildFavoriteQuickSelect(),
                    // Zähler Dropdown
                    DropdownButtonFormField<Meter>(
                      value: _selected,
                      items: _allMeters
                          .map((meter) => DropdownMenuItem(
                                value: meter,
                                child: Text(meter.name),
                              ))
                          .toList(),
                      onChanged: _onMeterChanged,
                      decoration: const InputDecoration(labelText: 'Zähler auswählen'),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedMeterType?.name == 'Strom (HT/NT)') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _htCtrl,
                        decoration: const InputDecoration(labelText: 'HT (kWh)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _ntCtrl,
                        decoration: const InputDecoration(labelText: 'NT (kWh)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ] else if (_selectedMeterType != null) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _valueCtrl,
                        decoration: InputDecoration(labelText: 'Zählerstand (${_getUnit(_selectedMeterType)})'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (_imagePath == null)
                      if (_isScanning)
                        const Row(
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3)),
                            SizedBox(width: 16),
                            Expanded(child: Text('Foto wird analysiert...')),
                          ],
                        )
                      else
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.add_a_photo),
                              label: const Text('Foto'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _scanImage,
                              icon: const Icon(Icons.search),
                              label: const Text('Wert per Kamera erkennen'),
                            ),
                          ],
                        ),
                    if (_imagePath != null) ...[
                      const SizedBox(height: 8),
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(_imagePath!), height: 140, width: double.infinity, fit: BoxFit.cover),
                          ),
                          IconButton(
                            onPressed: _clearImage,
                            icon: const CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: _isSaving ? null : _save,
                      child: const Text('Speichern'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    _htCtrl.dispose();
    _ntCtrl.dispose();
    super.dispose();
  }
}