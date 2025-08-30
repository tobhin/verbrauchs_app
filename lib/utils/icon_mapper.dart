import 'package:flutter/material.dart';

// Eine einfache Klasse, die uns hilft, einen String in ein IconData-Objekt umzuwandeln.
class IconMapper {
  static final Map<String, IconData> _iconMap = {
    'water_drop': Icons.water_drop,
    'bolt': Icons.bolt,
    'local_fire_department': Icons.local_fire_department,
    'thermostat': Icons.thermostat,
    'solar_power': Icons.solar_power,
    'waves': Icons.waves,
    'heat_pump': Icons.heat_pump,
    'add': Icons.add,
    'question_mark': Icons.question_mark,
    // Hinzugefügt, um Icons aus der Datenbank-Seed-Funktion zu unterstützen
    'water': Icons.waves,
    'local_gas_station': Icons.local_gas_station,
  };

  static IconData getIcon(String iconName) {
    return _iconMap[iconName] ?? Icons.question_mark;
  }
}