// apps/mobile/lib/core/services/location_service.dart
// Servicio de geolocalización con manejo de permisos

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Servicio de geolocalización para la app RutaLibre.
class LocationService {
  /// Verifica si el GPS está habilitado en el dispositivo.
  Future<bool> get gpsHabilitado => Geolocator.isLocationServiceEnabled();

  /// Solicita permiso de ubicación y retorna la posición actual.
  /// Lanza [LocationException] si no se puede obtener la ubicación.
  Future<Position> obtenerUbicacionActual() async {
    // Verificar que el GPS esté activo
    if (!await gpsHabilitado) {
      throw const LocationException('GPS desactivado. Actívalo en Configuración.');
    }

    // Verificar y solicitar permisos
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) {
        throw const LocationException('Permiso de ubicación denegado.');
      }
    }

    if (permiso == LocationPermission.deniedForever) {
      throw const LocationException(
        'Permiso de ubicación denegado permanentemente. '
        'Ve a Configuración > Aplicaciones > RutaLibre para activarlo.',
      );
    }

    // Obtener posición
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
  }

  /// Obtiene el stream de posición en tiempo real para tracking.
  Stream<Position> get streamUbicacion => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // actualizar cada 10 metros
        ),
      );

  /// Calcula la distancia en metros entre dos puntos.
  double calcularDistancia({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) =>
      Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
}

/// Excepción específica para errores de ubicación.
class LocationException implements Exception {
  final String mensaje;
  const LocationException(this.mensaje);

  @override
  String toString() => 'LocationException: $mensaje';
}
