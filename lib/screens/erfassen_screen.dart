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

  IconData _getMeterIcon(String typeName) {
    switch (typeName.toLowerCase()) {
      case 'gas':
        return Icons.local_fire_department;
      case 'wasser':
        return Icons.water_drop;
      case 'strom (ht/nt)':
        return Icons.bolt;
      case 'schmutzwasser':
        return Icons.waves;
      default:
        return Icons.speed;
    }
  }

  String _getDisplayName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('zähler')) {
      return name.substring(0, lower.indexOf('zähler')).trim();
    }
    return name.trim();
  }

  String _getUnit(MeterType? type) {
    if (type == null) return '';
    if (type.name.toLowerCase().contains('strom')) return 'kWh';
    return 'm³';
  }

  Widget _buildFavoriteQuickSelect(BuildContext context) {
    if (_allMeters.isEmpty) return const SizedBox.shrink();

    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    final cardHeight = 90.0;
    final cardWidth = (width - 48) / crossAxisCount;

    final meterTypesSorted = [
      'Gas',
      'Schmutzwasser',
      'Strom (HT/NT)',
      'Wasser',
    ];

    List<Widget> tiles = [];
    for (var typeName in meterTypesSorted) {
      MeterType? type = _meterTypes.values.firstWhere(
          (t) => t.name.toLowerCase() == typeName.toLowerCase(),
          orElse: () => MeterType(id: -1, name: typeName, iconName: ""));
      Meter? meter = _allMeters.firstWhere(
          (m) => _meterTypes[m.meterTypeId]?.name.toLowerCase() == typeName.toLowerCase(),
          orElse: () => Meter(id: -1, meterTypeId: type.id!, name: typeName, number: '', active: true, isFavorite: false));
      if (meter.id == -1) continue;

      bool isSelected = _selected != null && _selected!.id == meter.id;
      tiles.add(
        GestureDetector(
          onTap: () {
            _onMeterChanged(meter);
          },
          child: Container(
            width: cardWidth,
            height: cardHeight,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF376DAA) : const Color(0xFFE5F0FB),
              borderRadius: BorderRadius.circular(14),
              border: isSelected ? Border.all(color: const Color(0xFF376DAA), width: 2) : Border.all(color: const Color(0xFFB2CBE8), width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getMeterIcon(typeName), size: 30, color: Colors.black87),
                const SizedBox(height: 8),
                Text(
                  typeName.replaceAll('zähler', '').replaceAll('Zähler', '').trim(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: tiles,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String zaehlerNummer = _selected?.number ?? '';

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      "Erfassen",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _buildFavoriteQuickSelect(context),
                    // Zähler Dropdown mit Rahmen
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFB2CBE8), width: 1.3),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: DropdownButtonFormField<Meter>(
                          value: _selected,
                          items: _allMeters
                              .map((meter) => DropdownMenuItem(
                                    value: meter,
                                    child: Text(
                                      (_meterTypes[meter.meterTypeId]?.name ?? '').replaceAll('zähler', '').replaceAll('Zähler', '').trim(),
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ))
                              .toList(),
                          onChanged: _onMeterChanged,
                          decoration: const InputDecoration(
                            labelText: 'Zähler wählen',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    // Zählerstand Eingabe mit Rahmen und Zählernummer
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFB2CBE8), width: 1.3),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: TextFormField(
                          controller: _selectedMeterType?.name == 'Strom (HT/NT)'
                              ? null
                              : _valueCtrl,
                          decoration: InputDecoration(
                            labelText: 'Wert',
                            hintText: zaehlerNummer.isNotEmpty ? '(${zaehlerNummer})' : null,
                            border: InputBorder.none,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ),
                    // Bei Strom NT/HT: Zeige beide Felder
                    if (_selectedMeterType?.name == 'Strom (HT/NT)') ...[
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFFB2CBE8), width: 1.3),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: TextFormField(
                            controller: _htCtrl,
                            decoration: InputDecoration(
                              labelText: 'HT',
                              hintText: zaehlerNummer.isNotEmpty ? '(${zaehlerNummer})' : null,
                              border: InputBorder.none,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFFB2CBE8), width: 1.3),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: TextFormField(
                            controller: _ntCtrl,
                            decoration: InputDecoration(
                              labelText: 'NT',
                              hintText: zaehlerNummer.isNotEmpty ? '(${zaehlerNummer})' : null,
                              border: InputBorder.none,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Foto und OCR in einer Zeile, nur Text und Icon
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text('Foto'),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            backgroundColor: Color(0xFFE5F0FB),
                            foregroundColor: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Wert per Kamera erkennen',
                          style: TextStyle(fontSize: 16, color: Colors.black87),
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
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: const Color(0xFF376DAA),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.save),
                      onPressed: _isSaving ? null : _save,
                      label: const Text('Speichern'),
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