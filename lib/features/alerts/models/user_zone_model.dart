// apps/mobile/lib/features/alerts/models/user_zone_model.dart
// Modelo de zona de alerta personalizada del usuario

import 'dart:convert';

/// Representa una zona geográfica de interés para el usuario,
/// dentro de la cual quiere recibir alertas de peligro.
class UserZoneModel {
  /// Identificador único (UUID generado en cliente).
  final String id;

  /// Nombre descriptivo elegido por el usuario (ej. "Mi casa", "El trabajo").
  final String name;

  /// Latitud del centro de la zona.
  final double lat;

  /// Longitud del centro de la zona.
  final double lng;

  /// Radio en kilómetros. Valores permitidos: 0.5, 1.0, 2.0, 5.0
  final double radiusKm;

  const UserZoneModel({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusKm,
  });

  // ─── Serialización ──────────────────────────────────────────────

  /// Convierte el modelo a Map para persistir en SharedPreferences.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
        'radiusKm': radiusKm,
      };

  /// Crea un modelo desde un Map (leído de SharedPreferences).
  factory UserZoneModel.fromJson(Map<String, dynamic> json) => UserZoneModel(
        id: json['id'] as String,
        name: json['name'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        radiusKm: (json['radiusKm'] as num).toDouble(),
      );

  /// Serializa a String JSON para lista de SharedPreferences.
  String toJsonString() => jsonEncode(toJson());

  /// Crea desde String JSON (elemento de lista en SharedPreferences).
  factory UserZoneModel.fromJsonString(String jsonString) =>
      UserZoneModel.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  // ─── Utilidades ─────────────────────────────────────────────────

  /// Etiqueta legible del radio para mostrar en UI.
  String get radiusLabel {
    if (radiusKm < 1.0) return '${(radiusKm * 1000).round()} m';
    return '${radiusKm.toString().replaceAll(RegExp(r'\.0$'), '')} km';
  }

  /// Copia con campos modificados.
  UserZoneModel copyWith({
    String? id,
    String? name,
    double? lat,
    double? lng,
    double? radiusKm,
  }) =>
      UserZoneModel(
        id: id ?? this.id,
        name: name ?? this.name,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        radiusKm: radiusKm ?? this.radiusKm,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is UserZoneModel && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'UserZoneModel(id: $id, name: $name, radiusKm: $radiusKm)';
}
