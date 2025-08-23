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
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        meter_id INTEGER, 
        date TEXT,
        value REAL, 
        ht REAL, 
        nt REAL, 
        image_path TEXT, 
        tariff_id INTEGER
      );
    ''');
    await db.execute('''
      CREATE TABLE reminders(
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        meter_id INTEGER,
        base_date TEXT, 
        repeat TEXT, 
        notification_id INTEGER
      );
    ''');
    await db.execute('''
      CREATE TABLE tariffs(
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        meter_id INTEGER,
        cost_per_unit REAL, 
        base_fee REAL NOT NULL DEFAULT 0.0
      );
    ''');
    await db.execute('CREATE INDEX idx_readings_meter_id ON readings(meter_id);'); // HINZUGEFÜGT: Index für Performance
    await _seedMeterTypes(db);
    await _seedInitialMeters(db);
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 9) {
      await db.execute('ALTER TABLE meters RENAME TO meters_old;').catchError((e) {});
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
      // Weitere Migrationslogik hier, falls abgeschnitten
    }
    if (oldV < 10) {
      await db.execute('CREATE INDEX idx_readings_meter_id ON readings(meter_id);');
    }
  }

  Future<void> _seedMeterTypes(Database db) async {
    await db.insert('meter_types', {'name': 'Strom (HT/NT)', 'icon_name': 'bolt', 'is_default': 0});
    await db.insert('meter_types', {'name': 'Wasser', 'icon_name': 'water_drop', 'is_default': 1});
    await db.insert('meter_types', {'name': 'Schmutzwasser', 'icon_name': 'water', 'is_default': 0});
    await db.insert('meter_types', {'name': 'Gas', 'icon_name': 'local_gas_station', 'is_default': 0});
  }

  Future<void> _seedInitialMeters(Database db) async {
    // Beispielhafte Initialdaten, falls nötig
  }

  Future<String> getDatabasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, 'verbrauchs_app.db');
  }

  Future<void> deleteDatabaseFile() async {
    final path = await getDatabasePath();
    await databaseFactory.deleteDatabase(path);
    _db = null;
  }

  Future<List<Meter>> fetchMeters({bool onlyActive = true}) async {
    final d = await db;
    final rows = await d.query('meters', where: onlyActive ? 'active = 1' : null);
    return rows.map(Meter.fromMap).toList();
  }

  Future<int> insertMeter(Meter m) async {
    final d = await db;
    return d.insert('meters', m.toMap());
  }

  Future<void> updateMeter(Meter m) async {
    final d = await db;
    await d.update('meters', m.toMap(), where: 'id = ?', whereArgs: [m.id]);
  }

  Future<void> updateMeterFavoriteStatus(int id, bool isFavorite) async {
    final d = await db;
    await d.update('meters', {'is_favorite': isFavorite ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteMeter(int id) async {
    final d = await db;
    await d.update('meters', {'active': 0}, where: 'id = ?', whereArgs: [id]);
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
    final rows = await d.query('readings', where: 'meter_id = ?', whereArgs: [meterId], orderBy: 'date DESC');
    return rows.map(Reading.fromMap).toList();
  }

  Future<void> deleteReadingsForMeter(int meterId) async {
    final d = await db;
    await d.delete('readings', where: 'meter_id = ?', whereArgs: [meterId]);
  }

  Future<int> insertReminder(Reminder r) async {
    final d = await db;
    return d.insert('reminders', r.toMap());
  }

  Future<void> updateReminder(Reminder r) async {
    final d = await db;
    await d.update('reminders', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
  }

  Future<void> deleteReminder(int id) async {
    final d = await db;
    await d.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  Future<Reminder?> fetchReminderById(int id) async {
    final d = await db;
    final rows = await d.query('reminders', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Reminder.fromMap(rows.first);
  }

  Future<List<Reminder>> fetchReminders(int meterId) async {
    final d = await db;
    final rows = await d.query('reminders', where: 'meter_id = ?', whereArgs: [meterId], orderBy: 'base_date ASC');
    return rows.map(Reminder.fromMap).toList();
  }

  Future<int> insertTariff(Tariff t) async {
    final d = await db;
    await d.delete('tariffs', where: 'meter_id = ?', whereArgs: [t.meterId]);
    return d.insert('tariffs', t.toMap());
  }

  Future<void> deleteTariffForMeter(int meterId) async {
    final d = await db;
    await d.delete('tariffs', where: 'meter_id = ?', whereArgs: [meterId]);
  }

  Future<Tariff?> getTariff(int meterId) async {
    final d = await db;
    final rows = await d.query('tariffs', where: 'meter_id = ?', whereArgs: [meterId], orderBy: 'id DESC', limit: 1);
    if (rows.isEmpty) return null;
    return Tariff.fromMap(rows.first);
  }

  Future<List<MeterType>> fetchMeterTypes() async {
    final d = await db;
    final rows = await d.query('meter_types');
    return rows.map(MeterType.fromMap).toList();
  }
}