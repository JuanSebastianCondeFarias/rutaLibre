// apps/mobile/lib/features/community_routes/providers/community_routes_provider.dart
// Provider ChangeNotifier para el estado del feed de rutas de la comunidad

import 'package:flutter/foundation.dart';

import '../../../core/services/api_service.dart';
import '../models/community_route_model.dart';

/// Estado y lógica de negocio para el listado de rutas de la comunidad.
class CommunityRoutesProvider extends ChangeNotifier {
  final ApiService _api;

  CommunityRoutesProvider(this._api);

  List<CommunityRouteModel> _rutas = [];
  bool _cargando = false;
  String? _error;
  String? _filtroDificultad; // null = todas

  List<CommunityRouteModel> get rutas => _rutas;
  bool get cargando => _cargando;
  String? get error => _error;
  String? get filtroDificultad => _filtroDificultad;

  /// Carga el feed de rutas para la ciudad indicada.
  Future<void> cargarRutas(String city) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _rutas = await _api.listarRutasComunidad(
        city,
        dificultad: _filtroDificultad,
      );
    } catch (e) {
      _error = 'No se pudieron cargar las rutas: $e';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Cambia el filtro de dificultad y recarga el feed.
  Future<void> cambiarFiltro(String city, String? dificultad) async {
    _filtroDificultad = dificultad;
    await cargarRutas(city);
  }

  /// Actualiza el rating de una ruta localmente después de calificar.
  void actualizarRatingLocal(int routeId, double nuevoRating, int nuevoTotal) {
    _rutas = _rutas.map((r) {
      if (r.id == routeId) {
        return CommunityRouteModel(
          id: r.id,
          citySlug: r.citySlug,
          title: r.title,
          description: r.description,
          authorName: r.authorName,
          authorPhotoUrl: r.authorPhotoUrl,
          distanceKm: r.distanceKm,
          durationMinutes: r.durationMinutes,
          elevationGainM: r.elevationGainM,
          difficulty: r.difficulty,
          rating: nuevoRating,
          totalRatings: nuevoTotal,
          points: r.points,
          photoUrls: r.photoUrls,
          createdAt: r.createdAt,
        );
      }
      return r;
    }).toList();
    notifyListeners();
  }
}
