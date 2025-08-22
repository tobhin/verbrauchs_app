import 'package:equatable/equatable.dart';

class Meter extends Equatable {
  final int? id;
  final String name;
  final int meterTypeId;
  final String? number;
  final bool active;
  final bool isFavorite;

  const Meter({
    this.id,
    required this.name,
    required this.meterTypeId,
    this.number,
    this.active = true,
    this.isFavorite = false,
  });

  // Equatable "weiß" jetzt, dass zwei Meter-Objekte gleich sind, wenn ihre IDs gleich sind.
  @override
  List<Object?> get props => [id];

  Meter copyWith({
    int? id,
    String? name,
    int? meterTypeId,
    String? number,
    bool? active,
    bool? isFavorite,
  }) {
    return Meter(
      id: id ?? this.id,
      name: name ?? this.name,
      meterTypeId: meterTypeId ?? this.meterTypeId,
      number: number ?? this.number,
      active: active ?? this.active,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'meter_type_id': meterTypeId,
      'number': number,
      'active': active ? 1 : 0,
      'is_favorite': isFavorite ? 1 : 0,
    };
  }

  factory Meter.fromMap(Map<String, dynamic> map) {
    return Meter(
      id: map['id'],
      name: map['name'] ?? '',
      meterTypeId: map['meter_type_id'],
      number: map['number'],
      active: map['active'] == 1,
      isFavorite: map['is_favorite'] == 1,
    );
  }
}