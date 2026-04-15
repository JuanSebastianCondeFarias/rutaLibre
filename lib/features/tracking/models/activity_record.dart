// apps/mobile/lib/features/tracking/models/activity_record.dart
// Modelo de datos para una actividad ciclista grabada

/// Representa una actividad ciclista completa grabada por el usuario.
/// Los puntos se almacenan como List<List<double>> para compatibilidad con Hive/JSON.
class ActivityRecord {
  final String id;

  /// Slug de la ciudad donde se realizó la actividad (ej: 'bogota')
  final String citySlug;

  final DateTime startedAt;
  final DateTime endedAt;

  /// Distancia recorrida en kilómetros
  final double distanceKm;

  /// Duración total en segundos
  final int durationSeconds;

  /// Velocidad promedio en km/h
  final double avgSpeedKmh;

  /// Lista de puntos GPS: cada punto es [latitud, longitud]
  final List<List<double>> points;

  /// Nombre que el usuario asigna a la actividad
  final String title;

  const ActivityRecord({
    required this.id,
    required this.citySlug,
    required this.startedAt,
    required this.endedAt,
    required this.distanceKm,
    required this.durationSeconds,
    required this.avgSpeedKmh,
    required this.points,
    required this.title,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'citySlug': citySlug,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'distanceKm': distanceKm,
        'durationSeconds': durationSeconds,
        'avgSpeedKmh': avgSpeedKmh,
        // Convertir a lista plana JSON-serializable
        'points': points.map((p) => p.toList()).toList(),
        'title': title,
      };

  factory ActivityRecord.fromJson(Map<String, dynamic> json) {
    // Deserializar puntos desde JSON (pueden venir como List<dynamic>)
    final rawPoints = json['points'] as List<dynamic>? ?? [];
    final points = rawPoints.map<List<double>>((p) {
      final coords = p as List<dynamic>;
      return coords.map<double>((c) => (c as num).toDouble()).toList();
    }).toList();

    return ActivityRecord(
      id: json['id'] as String,
      citySlug: json['citySlug'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: DateTime.parse(json['endedAt'] as String),
      distanceKm: (json['distanceKm'] as num).toDouble(),
      durationSeconds: json['durationSeconds'] as int,
      avgSpeedKmh: (json['avgSpeedKmh'] as num).toDouble(),
      points: points,
      title: json['title'] as String,
    );
  }

  /// Formato legible de la duración (ej: "1h 23m 45s")
  String get duracionFormateada {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;

    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }
}
