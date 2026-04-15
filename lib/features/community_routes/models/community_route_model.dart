// apps/mobile/lib/features/community_routes/models/community_route_model.dart
// Modelo tipado para rutas publicadas por la comunidad

/// Representa una ruta ciclista publicada por un usuario de la comunidad.
class CommunityRouteModel {
  final int id;
  final String citySlug;
  final String title;
  final String? description;
  final String authorName;
  final String? authorPhotoUrl;
  final double distanceKm;
  final int durationMinutes;
  final int elevationGainM;

  /// Nivel de dificultad: 'facil' | 'moderado' | 'dificil'
  final String difficulty;

  /// Calificación promedio de 0.0 a 5.0
  final double rating;
  final int totalRatings;

  /// Lista de puntos de la ruta en formato [[lng, lat], ...]
  final List<List<double>> points;

  /// URLs de fotos asociadas a la ruta
  final List<String> photoUrls;

  final DateTime createdAt;

  const CommunityRouteModel({
    required this.id,
    required this.citySlug,
    required this.title,
    this.description,
    required this.authorName,
    this.authorPhotoUrl,
    required this.distanceKm,
    required this.durationMinutes,
    required this.elevationGainM,
    required this.difficulty,
    required this.rating,
    required this.totalRatings,
    required this.points,
    required this.photoUrls,
    required this.createdAt,
  });

  factory CommunityRouteModel.fromJson(Map<String, dynamic> json) {
    // Parsear puntos de ruta desde lista de listas
    final rawPoints = (json['points'] as List?)
            ?.map((p) => (p as List).map((v) => (v as num).toDouble()).toList())
            .toList() ??
        [];

    return CommunityRouteModel(
      id: (json['id'] as num).toInt(),
      citySlug: json['city_slug'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      authorName: json['author_name'] as String,
      authorPhotoUrl: json['author_photo_url'] as String?,
      distanceKm: (json['distance_km'] as num).toDouble(),
      durationMinutes: (json['duration_minutes'] as num).toInt(),
      elevationGainM: (json['elevation_gain_m'] as num).toInt(),
      difficulty: json['difficulty'] as String,
      rating: (json['rating'] as num? ?? 0).toDouble(),
      totalRatings: (json['total_ratings'] as num? ?? 0).toInt(),
      points: rawPoints,
      photoUrls: (json['photo_urls'] as List?)
              ?.map((u) => u as String)
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'city_slug': citySlug,
        'title': title,
        if (description != null) 'description': description,
        'author_name': authorName,
        if (authorPhotoUrl != null) 'author_photo_url': authorPhotoUrl,
        'distance_km': distanceKm,
        'duration_minutes': durationMinutes,
        'elevation_gain_m': elevationGainM,
        'difficulty': difficulty,
        'rating': rating,
        'total_ratings': totalRatings,
        'points': points,
        'photo_urls': photoUrls,
        'created_at': createdAt.toIso8601String(),
      };

  /// Devuelve el primer punto como [lng, lat] o null si no hay puntos.
  List<double>? get primerPunto => points.isNotEmpty ? points.first : null;

  /// Devuelve el último punto como [lng, lat] o null si no hay puntos.
  List<double>? get ultimoPunto => points.isNotEmpty ? points.last : null;

  /// Formatea la distancia con una cifra decimal.
  String get distanciaFormateada => '${distanceKm.toStringAsFixed(1)} km';

  /// Formatea la duración en horas y minutos.
  String get duracionFormateada {
    if (durationMinutes < 60) return '${durationMinutes} min';
    final horas = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    return mins > 0 ? '${horas}h ${mins}min' : '${horas}h';
  }
}
