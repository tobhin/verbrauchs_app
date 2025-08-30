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

  static const _dbVersion = 11; // ERHÖHT: Datenbank-Version
  
  static const int startwertTariffId = -1;

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
    // ANGEPASST: tariffs Tabelle mit neuen Spalten
    await db.execute('''
      CREATE TABLE tariffs(
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        meter_id INTEGER,
        cost_per_unit REAL, 
        base_fee REAL NOT NULL DEFAULT 0.0,
        gueltig_ab TEXT,
        grund TEXT
      );
    ''');
    await db.execute('CREATE INDEX idx_readings_meter_id ON readings(meter_id);');
    await _seedMeterTypes(db);
    await _seedInitialMeters(db);
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    // Migrationen für alte Versionen bleiben erhalten
    if (oldV < 10) {
      await db.execute('CREATE INDEX idx_readings_meter_id ON readings(meter_id);');
    }
    // NEUE MIGRATION: Erweitert die Tariftabelle für die Historie
    if (oldV < 11) {
      await db.execute('ALTER TABLE tariffs ADD COLUMN gueltig_ab TEXT;');
      await db.execute('ALTER TABLE tariffs ADD COLUMN grund TEXT;');
      // Setzt ein Standard-Datum für bestehende Tarife, damit die App nicht abstürzt
      await db.update('tariffs', {'gueltig_ab': DateTime(1970).toIso8601String()}, where: 'gueltig_ab IS NULL');
    }
  }

  Future<void> _seedMeterTypes(Database db) async {
    await db.insert('meter_types', {'name': 'Strom (HT/NT)', 'icon_name': 'bolt', 'is_default': 0});
    await db.insert('meter_types', {'name': 'Wasser', 'icon_name': 'water_drop', 'is_default': 1});
    await db.insert('meter_types', {'name': 'Schmutzwasser', 'icon_name': 'water', 'is_default': 0});
    await db.insert('meter_types', {'name': 'Gas', 'icon_name': 'local_gas_station', 'is_default': 0});
  }

  Future<void> _seedInitialMeters(Database db) async {
    await db.insert('meters', {'name': 'Stromzähler', 'meter_type_id': 1, 'number': 'STR001', 'active': 1, 'is_favorite': 1});
    await db.insert('meters', {'name': 'Wasserzähler', 'meter_type_id': 2, 'number': 'WAS001', 'active': 1, 'is_favorite': 1});
    await db.insert('meters', {'name': 'Schmutzwasserzähler', 'meter_type_id': 3, 'number': 'SCH001', 'active': 1, 'is_favorite': 1});
    await db.insert('meters', {'name': 'Gaszähler', 'meter_type_id': 4, 'number': 'GAS001', 'active': 1, 'is_favorite': 1});
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

  // --- METER ---
  Future<List<Meter>> fetchMeters({bool onlyActive = true, bool onlyFavorites = false}) async {
    final d = await db;
    String? where = onlyActive ? 'active = 1' : null;
    if (onlyFavorites) {
      where = where == null ? 'is_favorite = 1' : '$where AND is_favorite = 1';
    }
    final rows = await d.query('meters', where: where);
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

  Future<void> deleteMeter(int id) async {
    final d = await db;
    await d.update('meters', {'active': 0}, where: 'id = ?', whereArgs: [id]);
  }
  
  // --- READINGS ---
  Future<int> insertReading(Reading r) async {
    final d = await db;
    return d.insert('readings', r.toMap());
  }

  Future<void> deleteReading(int readingId) async {
    final d = await db;
    await d.delete('readings', where: 'id = ?', whereArgs: [readingId]);
  }

  Future<List<Reading>> fetchReadingsForMeter(int meterId) async {
    final d = await db;
    final rows = await d.query('readings', where: 'meter_id = ? AND (tariff_id IS NULL OR tariff_id != ?)', whereArgs: [meterId, startwertTariffId], orderBy: 'date DESC');
    return rows.map(Reading.fromMap).toList();
  }

  Future<Reading?> fetchStartwertForMeter(int meterId) async {
    final d = await db;
    final rows = await d.query('readings', where: 'meter_id = ? AND tariff_id = ?', whereArgs: [meterId, startwertTariffId], limit: 1);
    return rows.isNotEmpty ? Reading.fromMap(rows.first) : null;
  }

  Future<void> deleteStartwert(int meterId) async {
    final d = await db;
    await d.delete('readings', where: 'meter_id = ? AND tariff_id = ?', whereArgs: [meterId, startwertTariffId]);
  }

  Future<void> deleteAllReadingsForMeter(int meterId) async {
    final d = await db;
    await d.delete('readings', where: 'meter_id = ?', whereArgs: [meterId]);
  }
  
  // --- REMINDERS ---
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

  Future<List<Reminder>> fetchReminders(int meterId) async {
    final d = await db;
    final rows = await d.query('reminders', where: 'meter_id = ?', whereArgs: [meterId], orderBy: 'base_date ASC');
    return rows.map(Reminder.fromMap).toList();
  }
  
  // --- TARIFFS ---
  Future<int> insertTariff(Tariff t) async {
    final d = await db;
    return d.insert('tariffs', t.toMap());
  }

  Future<void> deleteTariff(int tariffId) async {
    final d = await db;
    await d.delete('tariffs', where: 'id = ?', whereArgs: [tariffId]);
  }

  Future<Tariff?> getTariff(int meterId) async {
    final d = await db;
    final rows = await d.query('tariffs', where: 'meter_id = ?', whereArgs: [meterId], orderBy: 'gueltig_ab DESC', limit: 1);
    if (rows.isEmpty) return null;
    return Tariff.fromMap(rows.first);
  }

  Future<List<Tariff>> fetchAllTariffsForMeter(int meterId) async {
    final d = await db;
    final rows = await d.query(
      'tariffs',
      where: 'meter_id = ?',
      whereArgs: [meterId],
      orderBy: 'gueltig_ab DESC',
    );
    return rows.map(Tariff.fromMap).toList();
  }
  
  // --- METER TYPES ---
  Future<List<MeterType>> fetchMeterTypes() async {
    final d = await db;
    final rows = await d.query('meter_types');
    return rows.map(MeterType.fromMap).toList();
  }

  Future<MeterType?> fetchMeterTypeById(int id) async {
    final d = await db;
    final rows = await d.query('meter_types', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return MeterType.fromMap(rows.first);
  }
}