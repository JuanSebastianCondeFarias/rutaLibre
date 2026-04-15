// apps/mobile/lib/features/map/widgets/route_display_widget.dart
// Widget que dibuja una ruta con:
//   1. Animación de trazado inicial (origen → destino)
//   2. Efecto zebra/código de barras continuo que se desplaza a lo largo de la ruta
//   3. Ícono ciclista en origen, bandera roja en destino
//   4. Colores adaptativos: blanco en oscuro, negro en claro

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RouteDisplayWidget extends StatefulWidget {
  final Map<String, dynamic> rutaData;

  const RouteDisplayWidget({super.key, required this.rutaData});

  @override
  State<RouteDisplayWidget> createState() => _RouteDisplayWidgetState();
}

class _RouteDisplayWidgetState extends State<RouteDisplayWidget>
    with TickerProviderStateMixin {
  // Animación 1: trazado inicial — avanza una sola vez
  late AnimationController _drawCtrl;
  late Animation<double> _drawAnim;

  // Animación 2: desplazamiento zebra — ciclo infinito
  late AnimationController _zebraCtrl;

  late List<LatLng> _puntos;

  @override
  void initState() {
    super.initState();
    _puntos = _parsePuntos(widget.rutaData);

    _drawCtrl = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _drawAnim = CurvedAnimation(parent: _drawCtrl, curve: Curves.easeInOut);

    // La zebra empieza tras el trazado
    _zebraCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _drawCtrl.forward().then((_) => _zebraCtrl.repeat());
  }

  @override
  void didUpdateWidget(RouteDisplayWidget old) {
    super.didUpdateWidget(old);
    if (old.rutaData != widget.rutaData) {
      _puntos = _parsePuntos(widget.rutaData);
      _zebraCtrl.stop();
      _drawCtrl.forward(from: 0).then((_) => _zebraCtrl.repeat());
    }
  }

  @override
  void dispose() {
    _drawCtrl.dispose();
    _zebraCtrl.dispose();
    super.dispose();
  }

  List<LatLng> _parsePuntos(Map<String, dynamic> data) {
    final raw = data['puntos'] as List<dynamic>? ?? [];
    return raw.map((p) {
      final c = p as List<dynamic>;
      return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
    }).toList();
  }

  /// Genera sub-listas de puntos que forman los "rayas" del efecto zebra.
  /// [phase] 0→1 desplaza el patrón a lo largo de la línea.
  List<List<LatLng>> _dashSegments(List<LatLng> pts, double phase) {
    const int dash = 10; // puntos "on"
    const int gap  = 8;  // puntos "off"
    const int cycle = dash + gap;

    final int offset = (phase * cycle).round();
    final List<List<LatLng>> segments = [];
    List<LatLng> current = [];

    for (int i = 0; i < pts.length; i++) {
      // Resta en lugar de suma: el patrón avanza origen → destino
      final int pos = ((i - offset) % cycle + cycle) % cycle;
      if (pos < dash) {
        current.add(pts[i]);
      } else {
        if (current.length >= 2) segments.add(List.from(current));
        current = [];
      }
    }
    if (current.length >= 2) segments.add(current);
    return segments;
  }

  @override
  Widget build(BuildContext context) {
    if (_puntos.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lineColor   = isDark ? Colors.white : Colors.black87;
    final borderColor = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.85);

    final origen  = _puntos.first;
    final destino = _puntos.last;

    return AnimatedBuilder(
      animation: Listenable.merge([_drawAnim, _zebraCtrl]),
      builder: (context, _) {
        // ── Puntos visibles según trazado ─────────────────────
        final count = (_puntos.length * _drawAnim.value)
            .ceil()
            .clamp(2, _puntos.length);
        final visible = _puntos.sublist(0, count);

        final bool trazadoCompleto = _drawAnim.value >= 0.99;

        // ── Capas de la línea ─────────────────────────────────
        final List<Widget> layers = [];

        if (trazadoCompleto) {
          // Zebra: rayas que se desplazan
          final segs = _dashSegments(visible, _zebraCtrl.value);

          // Borde de contraste bajo cada raya
          layers.add(PolylineLayer(
            polylines: segs
                .map((s) => Polyline(points: s, color: borderColor, strokeWidth: 9))
                .toList(),
          ));
          // Rayas principales
          layers.add(PolylineLayer(
            polylines: segs
                .map((s) => Polyline(points: s, color: lineColor, strokeWidth: 5))
                .toList(),
          ));
        } else {
          // Durante el trazado: línea continua
          layers.add(PolylineLayer(polylines: [
            Polyline(points: visible, color: borderColor, strokeWidth: 9),
          ]));
          layers.add(PolylineLayer(polylines: [
            Polyline(points: visible, color: lineColor, strokeWidth: 5),
          ]));
        }

        // ── Marcadores (aparecen al final del trazado) ────────
        if (trazadoCompleto) {
          layers.add(MarkerLayer(markers: [
            // Origen: ciclista
            Marker(
              point: origen,
              width: 44,
              height: 44,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                  ],
                ),
                child: const Center(
                  child: Text('🚴', style: TextStyle(fontSize: 22)),
                ),
              ),
            ),
            // Destino: meta de carrera
            Marker(
              point: destino,
              width: 44,
              height: 50,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black87, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.sports_score,
                      color: Colors.black87,
                      size: 26,
                    ),
                  ),
                  Container(
                    width: 3,
                    height: 8,
                    color: Colors.black87,
                  ),
                ],
              ),
            ),
          ]));
        }

        return Stack(children: layers);
      },
    );
  }
}
