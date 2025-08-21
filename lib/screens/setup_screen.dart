import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  @override
  void initState() {
    super.initState();
    _performInitialCheck();
  }

  Future<void> _performInitialCheck() async {
    // Kurze Verzögerung, um ein Flackern zu vermeiden
    await Future.delayed(const Duration(milliseconds: 500));

    final prefs = await SharedPreferences.getInstance();
    final hasCompleted = prefs.getBool('hasCompletedSetup') ?? false;

    if (hasCompleted) {
      _completeSetupAndNavigate();
    } else {
      // Alte Logik für Neuinstallation/Wiederherstellung
      final dbPath = await AppDb.instance.getDatabasePath();
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        if (mounted) _showRestoreDialog();
      } else {
        _completeSetupAndNavigate();
      }
    }
  }

  Future<void> _showRestoreDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Vorhandene Daten gefunden'),
        content: const Text(
          'Es scheint, als wäre diese App bereits installiert gewesen. Möchtest du die alten Daten wiederherstellen?'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startCleanInstall();
            },
            child: const Text('Saubere Installation'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _useExistingData();
            },
            child: const Text('Vorhandene Daten nutzen'),
          ),
        ],
      ),
    );
  }

  Future<void> _useExistingData() async {
    await _completeSetupAndNavigate();
  }

  Future<void> _startCleanInstall() async {
    await AppDb.instance.deleteDatabaseFile();
    await _completeSetupAndNavigate();
  }

  Future<void> _completeSetupAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasCompletedSetup', true);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('App wird eingerichtet...'),
          ],
        ),
      ),
    );
  }
}
