import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/meter.dart';
import '../models/meter_type.dart';
import '../models/reading.dart';
import '../models/reminder.dart';
import '../models/tariff.dart';

class AppDb {
  static final AppDb instance = AppDb._();
  AppDb._();
  Database? _db;

  static const _dbVersion = 10;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasePath();
    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE meter_types(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon_name TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0
      );
    ''');
    await db.execute('''
      CREATE TABLE meters(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        meter_type_id INTEGER,
        number TEXT,
        active INTEGER,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (meter_type_id) REFERENCES meter_types(id)
      );
    ''');
    await db.execute('''
      CREATE TABLE readings(
        id INTEGER PRIMARY KEY AUTOINCREMENT, meter_id INTEGER, date TEXT,
        value REAL, ht REAL, nt REAL, image_path TEXT, tariff_id INTEGER
      );
    ''');
    await db.execute('''
      CREATE TABLE reminders(
        id INTEGER PRIMARY KEY AUTOINCREMENT, meter_id INTEGER,
        base_date TEXT, repeat TEXT, notification_id INTEGER
      );
    ''');
    await db.execute('''
      CREATE TABLE tariffs(
        id INTEGER PRIMARY KEY AUTOINCREMENT, meter_id INTEGER,
        cost_per_unit REAL, base_fee REAL NOT NULL DEFAULT 0.0
      );
    ''');
    await _seedMeterTypes(db);
    await _seedInitialMeters(db);
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 9) {
      await db.execute('ALTER TABLE meters RENAME TO meters_old;').catchError((e) {});
      
      await db.execute('''
        CREATE TABLE meter_types(
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
          icon_name TEXT NOT NULL, is_default INTEGER NOT NULL DEFAULT 0
        );
      ''');
      await db.execute('''
        CREATE TABLE meters(
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, meter_type_id INTEGER,
          number TEXT, active INTEGER, is_favorite INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (meter_type_id) REFERENCES meter_types(id)
        );
      ''');
      
      await _seedMeterTypes(db);
      
      try {
        final oldMeters = await db.query('meters_old');
        for (final oldMeter in oldMeters) {
          final oldType = oldMeter['type'] as String?;
          int newTypeId;
          switch (oldType) {
              case 'stromDual': newTypeId = 2; break;
              case 'wasser': newTypeId = 1; break;
              case 'schmutzwasser': newTypeId = 6; break;
              case 'gas': newTypeId = 3; break;
              default: newTypeId = 1;
          }
          await db.insert('meters', {
            'id': oldMeter['id'], 'name': oldMeter['name'], 'number': oldMeter['number'],
            'active': oldMeter['active'], 'meter_type_id': newTypeId,
            'is_favorite': 1
          });
        }
        await db.execute('DROP TABLE meters_old;');
      } catch (e) { /* ignore */ }
    }
    if (oldV < 10) {
      await db.execute('ALTER TABLE meters ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0;').catchError((e) {});
      await db.rawUpdate('UPDATE meters SET is_favorite = 1 WHERE id IN (SELECT id FROM meters ORDER BY id LIMIT 4);');
    }
  }

  Future<void> _seedMeterTypes(Database db) async {
    final types = [
      const MeterType(id: 1, name: 'Wasser', iconName: 'water_drop', isDefault: true),
      const MeterType(id: 2, name: 'Strom', iconName: 'bolt', isDefault: true),
      const MeterType(id: 3, name: 'Gas', iconName: 'local_fire_department', isDefault: true),
      const MeterType(id: 4, name: 'Heizung', iconName: 'thermostat', isDefault: true),
      const MeterType(id: 5, name: 'Solar', iconName: 'solar_power', isDefault: true),
      const MeterType(id: 6, name: 'Abwasser', iconName: 'waves', isDefault: true),
      const MeterType(id: 7, name: 'Wärmepumpe', iconName: 'heat_pump', isDefault: true),
    ];
    for (final type in types) {
      await db.insert('meter_types', type.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _seedInitialMeters(Database db) async {
    final meters = [
      const Meter(name: 'Strom HT/NT', meterTypeId: 2, number: '538500-5003305', isFavorite: true),
      const Meter(name: 'Wasser', meterTypeId: 1, number: 'GB22A3-1600204', isFavorite: true),
      const Meter(name: 'Schmutzwasser', meterTypeId: 6, number: '32046368', isFavorite: true),
      const Meter(name: 'Gas', meterTypeId: 3, number: 'C21202-0501782', isFavorite: true),
    ];
    for (final meter in meters) {
      await db.insert('meters', meter.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<String> getDatabasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, 'verbrauchswerte.db');
  }

  Future<void> deleteDatabaseFile() async {
    final dbPath = await getDatabasePath();
    await close();
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }
    _db = null;
  }

  Future<void> close() async {
    final d = _db;
    if(d != null) {
      await d.close();
      _db = null;
    }
  }
  
  Future<List<MeterType>> fetchMeterTypes({bool? isDefault}) async {
    final d = await db;
    final rows = await d.query('meter_types', where: isDefault == null ? null : 'is_default = ?', whereArgs: isDefault == null ? null : [isDefault ? 1 : 0]);
    return rows.map(MeterType.fromMap).toList();
  }

  Future<int> insertMeterType(MeterType type) async {
    final d = await db;
    return d.insert('meter_types', type.toMap());
  }

  Future<MeterType?> getMeterTypeById(int id) async {
    final d = await db;
    final rows = await d.query('meter_types', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      return MeterType.fromMap(rows.first);
    }
    return null;
  }

  Future<List<Meter>> fetchMeters({bool onlyActive = true, bool? onlyFavorites}) async {
    final d = await db;
    String? where = onlyActive ? 'active=1' : null;
    if (onlyFavorites != null) {
      final favClause = 'is_favorite=${onlyFavorites ? 1 : 0}';
      where = where == null ? favClause : '$where AND $favClause';
    }
    final rows = await d.query('meters', where: where, orderBy: 'name ASC');
    return rows.map(Meter.fromMap).toList();
  }

  Future<int> insertMeter(Meter m) async {
    final d = await db;
    return d.insert('meters', m.toMap());
  }

  Future<void> updateMeterFavoriteStatus(int meterId, bool isFavorite) async {
    final d = await db;
    await d.update('meters', {'is_favorite': isFavorite ? 1 : 0}, where: 'id = ?', whereArgs: [meterId]);
  }

  Future<void> deactivateMeter(int id) async {
    final d = await db;
    await d.update('meters', {'active': 0}, where: 'id=?', whereArgs: [id]);
  }

  Future<int> insertReading(Reading r) async {
    final d = await db;
    return d.insert('readings', r.toMap());
  }

  Future<void> updateReading(Reading r) async {
    final d = await db;
    await d.update('readings', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
  }

  Future<void> deleteReading(int readingId) async {
    final d = await db;
    await d.delete('readings', where: 'id = ?', whereArgs: [readingId]);
  }
  
  Future<List<Reading>> fetchReadingsForMeter(int meterId) async {
    final d = await db;
    final rows = await d.query('readings', where: 'meter_id=?', whereArgs: [meterId], orderBy: 'date DESC');
    return rows.map(Reading.fromMap).toList();
  }

  Future<void> deleteReadingsForMeter(int meterId) async {
    final d = await db;
    await d.delete('readings', where: 'meter_id=?', whereArgs: [meterId]);
  }

  Future<int> insertReminder(Reminder r) async {
    final d = await db;
    return d.insert('reminders', r.toMap());
  }

  Future<void> updateReminder(Reminder r) async {
    final d = await db;
    await d.update('reminders', r.toMap(), where: 'id=?', whereArgs: [r.id]);
  }

  Future<void> deleteReminder(int id) async {
    final d = await db;
    await d.delete('reminders', where: 'id=?', whereArgs: [id]);
  }
  
  Future<Reminder?> fetchReminderById(int id) async {
     final d = await db;
    final rows = await d.query('reminders', where: 'id=?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Reminder.fromMap(rows.first);
  }

  Future<List<Reminder>> fetchReminders(int meterId) async {
    final d = await db;
    final rows = await d.query('reminders', where: 'meter_id=?', whereArgs: [meterId], orderBy: 'base_date ASC');
    return rows.map(Reminder.fromMap).toList();
  }
  
  Future<int> insertTariff(Tariff t) async {
    final d = await db;
    await d.delete('tariffs', where: 'meter_id=?', whereArgs: [t.meterId]);
    return d.insert('tariffs', t.toMap());
  }

  Future<void> deleteTariffForMeter(int meterId) async {
    final d = await db;
    await d.delete('tariffs', where: 'meter_id=?', whereArgs: [meterId]);
  }

  Future<Tariff?> getTariff(int meterId) async {
    final d = await db;
    final rows = await d.query('tariffs', where: 'meter_id=?', whereArgs: [meterId], orderBy: 'id DESC', limit: 1);
    if (rows.isEmpty) return null;
    return Tariff.fromMap(rows.first);
  }
}
