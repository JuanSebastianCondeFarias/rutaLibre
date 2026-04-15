// apps/mobile/lib/core/services/tracking_service.dart
// Servicio de tracking de actividades ciclistas — estado global con ChangeNotifier

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../features/tracking/models/activity_record.dart';

/// Estados posibles del grabador de actividad
enum TrackingEstado { idle, recording, paused }

/// Servicio principal de tracking ciclista.
///
/// Maneja el ciclo de vida completo de una grabación:
/// idle → recording → paused → recording → idle (al detener)
///
/// Usa [geolocator] para el stream GPS y [hive_flutter] para persistir actividades
/// en el box 'actividades'.
class TrackingService extends ChangeNotifier {
  // ─── Estado interno ──────────────────────────────────────────
  TrackingEstado _estado = TrackingEstado.idle;
  final List<LatLng> _puntos = [];
  Duration _tiempoTranscurrido = Duration.zero;
  double _distanciaTotalKm = 0.0;
  double _velocidadActualKmh = 0.0;
  DateTime? _inicioGrabacion;

  // ─── Control de timer y GPS ──────────────────────────────────
  Timer? _timer;
  StreamSubscription<Position>? _gpsSubscription;
  Position? _ultimaPosicion;

  // ─── Utilidades ──────────────────────────────────────────────
  static const _uuid = Uuid();
  static const String _boxActividades = 'actividades';

  // ─── Configuración GPS para tracking ─────────────────────────
  static const _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5, // actualizar cada 5 metros mínimo
  );

  // ─── Getters públicos ─────────────────────────────────────────

  TrackingEstado get estado => _estado;
  List<LatLng> get puntos => List.unmodifiable(_puntos);
  Duration get tiempoTranscurrido => _tiempoTranscurrido;
  double get distanciaTotalKm => _distanciaTotalKm;
  double get velocidadActualKmh => _velocidadActualKmh;
  bool get estaGrabando => _estado == TrackingEstado.recording;
  bool get estaPausado => _estado == TrackingEstado.paused;
  bool get estaInactivo => _estado == TrackingEstado.idle;

  /// Velocidad promedio calculada sobre toda la actividad
  double get velocidadPromedioKmh {
    final segundosTotales = _tiempoTranscurrido.inSeconds;
    if (segundosTotales <= 0) return 0.0;
    return (_distanciaTotalKm / segundosTotales) * 3600;
  }

  // ─── Métodos públicos ─────────────────────────────────────────

  /// Inicia una nueva grabación.
  /// Verifica permisos de ubicación antes de comenzar.
  Future<void> iniciarGrabacion() async {
    if (_estado != TrackingEstado.idle) return;

    // Verificar permiso de ubicación
    final tienePermiso = await _verificarPermiso();
    if (!tienePermiso) return;

    _limpiarEstado();
    _inicioGrabacion = DateTime.now();
    _estado = TrackingEstado.recording;

    _iniciarTimer();
    _iniciarGPS();

    notifyListeners();
  }

  /// Pausa la grabación sin perder los datos acumulados.
  void pausar() {
    if (_estado != TrackingEstado.recording) return;

    _estado = TrackingEstado.paused;
    _detenerTimer();
    _detenerGPS();

    notifyListeners();
  }

  /// Reanuda una grabación pausada.
  void reanudar() {
    if (_estado != TrackingEstado.paused) return;

    _estado = TrackingEstado.recording;
    _iniciarTimer();
    _iniciarGPS();

    notifyListeners();
  }

  /// Detiene la grabación y retorna el [ActivityRecord] completo.
  /// Guarda automáticamente en Hive con el [title] provisto.
  /// Retorna null si no hay puntos grabados o el estado es idle.
  Future<ActivityRecord?> detener({
    required String title,
    required String citySlug,
  }) async {
    if (_estado == TrackingEstado.idle) return null;
    if (_puntos.isEmpty) {
      _resetearATodo();
      return null;
    }

    _detenerTimer();
    _detenerGPS();

    final ahora = DateTime.now();
    final inicio = _inicioGrabacion ?? ahora;

    // Construir registro de actividad
    final record = ActivityRecord(
      id: _uuid.v4(),
      citySlug: citySlug,
      startedAt: inicio,
      endedAt: ahora,
      distanceKm: _distanciaTotalKm,
      durationSeconds: _tiempoTranscurrido.inSeconds,
      avgSpeedKmh: velocidadPromedioKmh,
      points: _puntos.map((p) => [p.latitude, p.longitude]).toList(),
      title: title.trim().isEmpty ? 'Actividad ciclista' : title.trim(),
    );

    // Persistir en Hive
    await _guardarActividad(record);

    _resetearATodo();
    notifyListeners();

    return record;
  }

  /// Retorna todas las actividades guardadas en Hive ordenadas por fecha descendente.
  Future<List<ActivityRecord>> cargarActividades() async {
    final box = await _abrirBox();
    final actividades = box.values
        .map((raw) {
          try {
            final map = Map<String, dynamic>.from(raw as Map);
            return ActivityRecord.fromJson(map);
          } catch (e) {
            debugPrint('Error deserializando actividad: $e');
            return null;
          }
        })
        .whereType<ActivityRecord>()
        .toList();

    // Ordenar por fecha de inicio descendente (más reciente primero)
    actividades.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return actividades;
  }

  /// Elimina una actividad de Hive por su [id].
  Future<void> eliminarActividad(String id) async {
    final box = await _abrirBox();
    await box.delete(id);
  }

  // ─── Métodos privados — GPS ───────────────────────────────────

  void _iniciarGPS() {
    _gpsSubscription = Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(
      _procesarPosicion,
      onError: (error) => debugPrint('Error GPS tracking: $error'),
    );
  }

  void _detenerGPS() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
  }

  void _procesarPosicion(Position posicion) {
    if (_estado != TrackingEstado.recording) return;

    final nuevoPunto = LatLng(posicion.latitude, posicion.longitude);

    // Calcular distancia incremental desde el último punto
    if (_ultimaPosicion != null) {
      final metros = Geolocator.distanceBetween(
        _ultimaPosicion!.latitude,
        _ultimaPosicion!.longitude,
        posicion.latitude,
        posicion.longitude,
      );
      _distanciaTotalKm += metros / 1000.0;
    }

    // Velocidad actual en km/h (geolocator la entrega en m/s)
    _velocidadActualKmh = math.max(0, posicion.speed * 3.6);

    _ultimaPosicion = posicion;
    _puntos.add(nuevoPunto);

    notifyListeners();
  }

  // ─── Métodos privados — Timer ─────────────────────────────────

  void _iniciarTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_estado == TrackingEstado.recording) {
        _tiempoTranscurrido += const Duration(seconds: 1);
        notifyListeners();
      }
    });
  }

  void _detenerTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // ─── Métodos privados — Estado ────────────────────────────────

  void _limpiarEstado() {
    _puntos.clear();
    _tiempoTranscurrido = Duration.zero;
    _distanciaTotalKm = 0.0;
    _velocidadActualKmh = 0.0;
    _ultimaPosicion = null;
    _inicioGrabacion = null;
  }

  void _resetearATodo() {
    _estado = TrackingEstado.idle;
    _limpiarEstado();
  }

  // ─── Métodos privados — Hive ──────────────────────────────────

  Future<Box> _abrirBox() async {
    if (Hive.isBoxOpen(_boxActividades)) {
      return Hive.box(_boxActividades);
    }
    return Hive.openBox(_boxActividades);
  }

  Future<void> _guardarActividad(ActivityRecord record) async {
    final box = await _abrirBox();
    // Usar el id como clave para facilitar eliminación
    await box.put(record.id, record.toJson());
  }

  // ─── Permisos ─────────────────────────────────────────────────

  Future<bool> _verificarPermiso() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      debugPrint('Tracking: GPS desactivado');
      return false;
    }

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }

    return permiso == LocationPermission.whileInUse ||
        permiso == LocationPermission.always;
  }

  @override
  void dispose() {
    _detenerTimer();
    _detenerGPS();
    super.dispose();
  }
}
