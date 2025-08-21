import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class Logger {
  static File? _logFile;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _logFile = File('${dir.path}/app_log.txt');
    if (!await _logFile!.exists()) {
      await _logFile!.create();
    }
  }

  static Future<void> log(String message) async {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message\n';
    debugPrint(logMessage.trim());
    if (_logFile != null) {
      await _logFile!.writeAsString(logMessage, mode: FileMode.append);
    }
  }

  static Future<File?> getLogFile() async {
    if (_logFile == null || !await _logFile!.exists()) {
      return null;
    }
    return _logFile;
  }
}