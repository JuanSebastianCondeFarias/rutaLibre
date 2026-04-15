// apps/mobile/lib/core/services/tracking_service.dart
// Servicio de tracking de actividades ciclistas — estado global con ChangeNotifier

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  /// En modo demo devuelve actividades de prueba con rutas reales de Bogotá.
  Future<List<ActivityRecord>> cargarActividades() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (token == 'mock_demo_v1') return _actividadesDemo();

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

    actividades.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return actividades;
  }

  /// Actividades de prueba con trayectos reales en Bogotá.
  List<ActivityRecord> _actividadesDemo() {
    final ahora = DateTime.now();
    return [
      ActivityRecord(
        id: 'demo-act-001',
        citySlug: 'bogota',
        title: 'Rodada matutina',
        startedAt: ahora.subtract(const Duration(days: 3, hours: 7)),
        endedAt: ahora.subtract(const Duration(days: 3, hours: 6, minutes: 18)),
        distanceKm: 12.4,
        durationSeconds: 2520, // 42 min
        avgSpeedKmh: 17.7,
        // Ciclovía Carrera 7 — Calle 100 hacia el sur
        points: const [
          [4.6800, -74.0490], [4.6771, -74.0497], [4.6743, -74.0504],
          [4.6714, -74.0511], [4.6686, -74.0518], [4.6657, -74.0525],
          [4.6629, -74.0532], [4.6600, -74.0539], [4.6572, -74.0546],
          [4.6543, -74.0553], [4.6515, -74.0560], [4.6486, -74.0567],
          [4.6458, -74.0574], [4.6429, -74.0581],
        ],
      ),
      ActivityRecord(
        id: 'demo-act-002',
        citySlug: 'bogota',
        title: 'Vuelta al Simón Bolívar',
        startedAt: ahora.subtract(const Duration(days: 8, hours: 16)),
        endedAt: ahora.subtract(const Duration(days: 8, hours: 15, minutes: 30)),
        distanceKm: 8.1,
        durationSeconds: 1800, // 30 min
        avgSpeedKmh: 16.2,
        // Loop alrededor del Parque Simón Bolívar
        points: const [
          [4.6583, -74.0931], [4.6617, -74.0948], [4.6648, -74.0965],
          [4.6665, -74.0994], [4.6660, -74.1028], [4.6641, -74.1055],
          [4.6613, -74.1066], [4.6582, -74.1063], [4.6553, -74.1048],
          [4.6535, -74.1021], [4.6530, -74.0988], [4.6540, -74.0958],
          [4.6558, -74.0939], [4.6583, -74.0931],
        ],
      ),
      ActivityRecord(
        id: 'demo-act-003',
        citySlug: 'bogota',
        title: 'Rodada nocturna',
        startedAt: ahora.subtract(const Duration(days: 14, hours: 20)),
        endedAt: ahora.subtract(const Duration(days: 14, hours: 19, minutes: 40)),
        distanceKm: 5.5,
        durationSeconds: 1200, // 20 min
        avgSpeedKmh: 16.5,
        // Calle 26 — de Carrera 7 hacia occidente
        points: const [
          [4.6283, -74.0662], [4.6285, -74.0698], [4.6287, -74.0734],
          [4.6289, -74.0770], [4.6291, -74.0806], [4.6293, -74.0842],
          [4.6295, -74.0878], [4.6297, -74.0914], [4.6299, -74.0950],
          [4.6301, -74.0986],
        ],
      ),
      ActivityRecord(
        id: 'demo-act-004',
        citySlug: 'bogota',
        title: 'Rodada de la tarde',
        startedAt: ahora.subtract(const Duration(days: 21, hours: 15)),
        endedAt: ahora.subtract(const Duration(days: 21, hours: 14, minutes: 25)),
        distanceKm: 9.8,
        durationSeconds: 2100, // 35 min
        avgSpeedKmh: 16.8,
        // Av. NQS (Carrera 30) de norte a sur
        points: const [
          [4.6820, -74.0985], [4.6783, -74.0985], [4.6746, -74.0986],
          [4.6709, -74.0987], [4.6672, -74.0988], [4.6635, -74.0989],
          [4.6598, -74.0990], [4.6561, -74.0991], [4.6524, -74.0992],
          [4.6487, -74.0993], [4.6450, -74.0994],
        ],
      ),
    ];
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
