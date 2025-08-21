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
  
  // HINZUGEFÜGT: Statusvariable für den OCR-Scanvorgang
  bool _isScanning = false;

  final Map<String, IconData> _iconMap = {
    'water_drop': Icons.water_drop, 'bolt': Icons.bolt, 'local_fire_department': Icons.local_fire_department,
    'thermostat': Icons.thermostat, 'solar_power': Icons.solar_power, 'waves': Icons.waves,
    'heat_pump': Icons.heat_pump, 'add': Icons.add, 'question_mark': Icons.question_mark,
  };

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
    if (_isScanning) return; // Verhindert doppeltes Ausführen

    final messenger = ScaffoldMessenger.of(context);
    final src = await showModalBottomSheet<ImageSource?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Kamera'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Galerie'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (src == null) return;
    if (src == ImageSource.camera) {
      final ok = await Permission.camera.request();
      if (!ok.isGranted) {
        messenger.showSnackBar(const SnackBar(content: Text('Kamera nicht erlaubt.')));
        return;
      }
    }
    final picker = ImagePicker();
    final x = await picker.pickImage(source: src, imageQuality: 90, maxWidth: 2048, maxHeight: 2048);
    if (x == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final ext = x.path.split('.').last;
    final save = '${dir.path}/img_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(x.path).copy(save);
    
    setState(() {
      _imagePath = save;
      _isScanning = true; // Ladeindikator anzeigen
    });
    
    try {
      final meterTypeName = _selectedMeterType?.name ?? '';
      MeterTypeForOcr meterTypeLabel;
      switch (meterTypeName) {
        case 'Strom': meterTypeLabel = MeterTypeForOcr.strom; break;
        case 'Wasser': meterTypeLabel = MeterTypeForOcr.wasser; break;
        case 'Abwasser': meterTypeLabel = MeterTypeForOcr.schmutzwasser; break;
        case 'Gas': meterTypeLabel = MeterTypeForOcr.gas; break;
        default: meterTypeLabel = MeterTypeForOcr.wasser;
      }
      
      final best = await tryOcrSmart(
        imagePath: save,
        meterType: meterTypeLabel,
        meterSerial: _selected?.number,
        lastValue: _lastReading?.value,
      );
      
      if (best != null) {
        if (_selectedMeterType?.name == 'Strom') {
          _htCtrl.text = best.toString();
        } else {
          _valueCtrl.text = best.toString();
        }
         messenger.showSnackBar(SnackBar(
          content: Text('OCR: Wert vorgeschlagen ($best)'),
        ));
      } else {
         messenger.showSnackBar(const SnackBar(
          content: Text('OCR: kein plausibler Wert gefunden'),
        ));
      }
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('OCR fehlgeschlagen')));
    } finally {
      // WICHTIG: Ladeindikator immer ausblenden
      if(mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  void _clearImage() => setState(() => _imagePath = null);

  Future<void> _save() async {
    if (_isSaving || _selected == null || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final tariff = await AppDb.instance.getTariff(_selected!.id!);
    
    Reading newReading;
    if (_selectedMeterType?.name == 'Strom') {
      newReading = Reading(
        meterId: _selected!.id!,
        date: DateTime.now(),
        ht: _parseNum(_htCtrl.text)!,
        nt: _parseNum(_ntCtrl.text), // NT ist optional
        imagePath: _imagePath,
        tariffId: tariff?.id,
      );
    } else {
      newReading = Reading(
        meterId: _selected!.id!,
        date: DateTime.now(),
        value: _parseNum(_valueCtrl.text)!,
        imagePath: _imagePath,
        tariffId: tariff?.id,
      );
    }

    await AppDb.instance.insertReading(newReading);
    
    _htCtrl.clear();
    _ntCtrl.clear();
    _valueCtrl.clear();
    _clearImage();
    if (context.mounted) FocusScope.of(context).unfocus();

    await _onMeterChanged(_selected);
    
    setState(() => _isSaving = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gespeichert')));
    }
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
                  _iconMap[type?.iconName] ?? Icons.question_mark,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildQuickTiles(context),
          const SizedBox(height: 16),
          if (_allMeters.isEmpty)
            const Center(child: Text('Bitte im Menü zuerst einen Zähler anlegen.'))
          else ...[
            DropdownButtonFormField<Meter>(
              key: ValueKey(_selected),
              isExpanded: true,
              value: _selected,
              items: _allMeters.map((m) => DropdownMenuItem(value: m, child: Text(m.name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: _onMeterChanged,
              decoration: const InputDecoration(labelText: 'Zähler wählen', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  if (_selectedMeterType?.name == 'Strom') ...[
                    TextFormField(
                      controller: _htCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'HT-Wert (${_selected?.number ?? ""})',
                        hintText: _lastReading?.ht != null ? 'Letzter Wert: ${_lastReading!.ht}' : 'Neuen Wert eingeben',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final val = _parseNum(v);
                        if (val == null) return 'Bitte eine Zahl eingeben';
                        if (_lastReading?.ht != null && val < _lastReading!.ht!) return 'Wert darf nicht niedriger sein als der letzte!';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ntCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'NT-Wert (${_selected?.number ?? ""})',
                        hintText: _lastReading?.nt != null ? 'Letzter Wert: ${_lastReading!.nt}' : 'Neuen Wert eingeben',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        // NT ist optional, Validierung nur wenn nicht leer
                        if (v != null && v.isNotEmpty) {
                          final val = _parseNum(v);
                          if (val == null) return 'Bitte eine gültige Zahl eingeben';
                           if (_lastReading?.nt != null && val < _lastReading!.nt!) return 'Wert darf nicht niedriger sein als der letzte!';
                        }
                        return null;
                      },
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _valueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Wert (${_selected?.number ?? ""})',
                        hintText: _lastReading?.value != null ? 'Letzter Wert: ${_lastReading!.value}' : 'Neuen Wert eingeben',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final val = _parseNum(v);
                        if (val == null) return 'Bitte eine Zahl eingeben';
                        if (_lastReading?.value != null && val < _lastReading!.value!) return 'Wert darf nicht niedriger sein als der letzte!';
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  // HINZUGEFÜGT: Zeigt entweder den Button oder einen Ladeindikator an
                  _isScanning 
                    ? const Row(
                        children: [
                          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3)),
                          SizedBox(width: 16),
                          Expanded(child: Text('Foto wird analysiert...')),
                        ],
                      )
                    : Row(
                      children: [
                        ElevatedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.add_a_photo), label: const Text('Foto')),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Wert per Kamera erkennen')),
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
                    ),
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,))
                        : const Icon(Icons.save),
                    label: const Text('Speichern'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}