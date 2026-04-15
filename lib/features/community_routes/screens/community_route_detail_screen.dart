// apps/mobile/lib/features/community_routes/screens/community_route_detail_screen.dart
// Detalle de una ruta de la comunidad: mapa, estadísticas, fotos y sistema de rating

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../models/community_route_model.dart';

/// Pantalla de detalle de una ruta de la comunidad.
class CommunityRouteDetailScreen extends StatefulWidget {
  final CommunityRouteModel ruta;

  const CommunityRouteDetailScreen({super.key, required this.ruta});

  @override
  State<CommunityRouteDetailScreen> createState() =>
      _CommunityRouteDetailScreenState();
}

class _CommunityRouteDetailScreenState
    extends State<CommunityRouteDetailScreen> {
  // Rating temporal mientras el usuario selecciona
  double _ratingSeleccionado = 0;
  bool _calificando = false;
  bool _yaCalificado = false;

  late double _ratingActual;
  late int _totalRatings;

  @override
  void initState() {
    super.initState();
    _ratingActual = widget.ruta.rating;
    _totalRatings = widget.ruta.totalRatings;
  }

  /// Convierte la lista de puntos [lng, lat] a LatLng para flutter_map.
  List<LatLng> get _puntosMapa => widget.ruta.points
      .map((p) => LatLng(p[1], p[0])) // OSM: lat,lng — el modelo guarda [lng,lat]
      .toList();

  /// Centro del mapa: promedio de los puntos o Bogotá como fallback.
  LatLng get _centroMapa {
    if (_puntosMapa.isEmpty) return const LatLng(4.7110, -74.0721);
    final latPromedio =
        _puntosMapa.map((p) => p.latitude).reduce((a, b) => a + b) /
            _puntosMapa.length;
    final lngPromedio =
        _puntosMapa.map((p) => p.longitude).reduce((a, b) => a + b) /
            _puntosMapa.length;
    return LatLng(latPromedio, lngPromedio);
  }

  Future<void> _calificar(double rating) async {
    if (_yaCalificado || _calificando) return;

    final api = ApiService(const FlutterSecureStorage());
    final autenticado = await api.estaAutenticado;
    if (!mounted) return;

    if (!autenticado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inicia sesión para calificar esta ruta'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _ratingSeleccionado = rating;
      _calificando = true;
    });

    try {
      final city = context.read<StorageService>().ciudadSeleccionada;
      await api.calificarRuta(city, widget.ruta.id, rating);

      if (!mounted) return;
      // Calcular nuevo promedio de forma optimista
      final nuevoTotal = _totalRatings + 1;
      final nuevoRating =
          ((_ratingActual * _totalRatings) + rating) / nuevoTotal;

      setState(() {
        _ratingActual = nuevoRating;
        _totalRatings = nuevoTotal;
        _yaCalificado = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calificación enviada — gracias!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _ratingSeleccionado = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar la calificación'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _calificando = false);
    }
  }

  void _pedalearEstaRuta() {
    final primer = widget.ruta.primerPunto;
    final ultimo = widget.ruta.ultimoPunto;
    if (primer == null || ultimo == null) return;

    // Navegar a la calculadora de rutas pasando origen y destino como queryParams
    context.go(
      '/rutas'
      '?orig_lat=${primer[1]}&orig_lng=${primer[0]}'
      '&dest_lat=${ultimo[1]}&dest_lng=${ultimo[0]}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ruta = widget.ruta;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── AppBar con mapa de la ruta ──────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _puntosMapa.length >= 2
                  ? _MapaRuta(puntos: _puntosMapa, centro: _centroMapa)
                  : _FotoPortadaGrande(
                      url: ruta.photoUrls.isNotEmpty ? ruta.photoUrls.first : null,
                    ),
            ),
          ),

          // ─── Panel de contenido scrolleable ──────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título y chip de dificultad
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          ruta.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ChipDificultad(dificultad: ruta.difficulty),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Autor y fecha
                  Row(
                    children: [
                      _AvatarAutor(
                        nombre: ruta.authorName,
                        fotoUrl: ruta.authorPhotoUrl,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Por ${ruta.authorName}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatearFecha(ruta.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Panel de estadísticas
                  _PanelStats(ruta: ruta),

                  // Descripción
                  if (ruta.description != null && ruta.description!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Descripción',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(ruta.description!, style: theme.textTheme.bodyMedium),
                  ],

                  // Galería de fotos
                  if (ruta.photoUrls.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Fotos',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    _GaleriaFotos(urls: ruta.photoUrls),
                  ],

                  const SizedBox(height: 24),

                  // Sistema de rating interactivo
                  _SistemaRating(
                    ratingActual: _ratingActual,
                    totalRatings: _totalRatings,
                    ratingSeleccionado: _ratingSeleccionado,
                    yaCalificado: _yaCalificado,
                    calificando: _calificando,
                    onCalificar: _calificar,
                  ),

                  // Espacio extra para que el botón inferior no tape contenido
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),

      // Botón prominente "Pedalear esta ruta" fijo en la parte inferior
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            onPressed: widget.ruta.points.length >= 2 ? _pedalearEstaRuta : null,
            icon: const Icon(Icons.directions_bike),
            label: const Text(
              'Pedalear esta ruta',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFF16A34A),
            ),
          ),
        ),
      ),
    );
  }

  String _formatearFecha(DateTime fecha) =>
      '${fecha.day}/${fecha.month}/${fecha.year}';
}

// ─── Mapa de la ruta ─────────────────────────────────────────────────────────

class _MapaRuta extends StatelessWidget {
  final List<LatLng> puntos;
  final LatLng centro;

  const _MapaRuta({required this.puntos, required this.centro});

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: centro,
        initialZoom: 13,
        // Solo visual: sin interacción para que no interfiera con el scroll
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'app.rutalibre.mobile',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: puntos,
              color: const Color(0xFF16A34A),
              strokeWidth: 4,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            if (puntos.isNotEmpty)
              Marker(
                point: puntos.first,
                child: const Icon(
                  Icons.trip_origin,
                  color: Color(0xFF16A34A),
                  size: 24,
                ),
              ),
            if (puntos.length > 1)
              Marker(
                point: puntos.last,
                child: const Icon(
                  Icons.location_on,
                  color: Color(0xFFDC2626),
                  size: 28,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ─── Foto portada grande (cuando no hay puntos de ruta) ───────────────────────

class _FotoPortadaGrande extends StatelessWidget {
  final String? url;
  const _FotoPortadaGrande({this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (url != null && url!.isNotEmpty) {
      return CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover);
    }
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.route,
          size: 64,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

// ─── Panel de estadísticas ────────────────────────────────────────────────────

class _PanelStats extends StatelessWidget {
  final CommunityRouteModel ruta;
  const _PanelStats({required this.ruta});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCol(
              icono: Icons.straighten,
              valor: ruta.distanciaFormateada,
              etiqueta: 'Distancia',
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
          Expanded(
            child: _StatCol(
              icono: Icons.schedule,
              valor: ruta.duracionFormateada,
              etiqueta: 'Duración',
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
          Expanded(
            child: _StatCol(
              icono: Icons.trending_up,
              valor: '+${ruta.elevationGainM} m',
              etiqueta: 'Desnivel',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String etiqueta;

  const _StatCol({
    required this.icono,
    required this.valor,
    required this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icono, size: 20, color: const Color(0xFF16A34A)),
        const SizedBox(height: 4),
        Text(
          valor,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          etiqueta,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

// ─── Chip de dificultad ───────────────────────────────────────────────────────

class _ChipDificultad extends StatelessWidget {
  final String dificultad;
  const _ChipDificultad({required this.dificultad});

  Color get _color {
    switch (dificultad) {
      case 'facil':
        return const Color(0xFF16A34A);
      case 'moderado':
        return const Color(0xFFF97316);
      case 'dificil':
        return const Color(0xFFDC2626);
      default:
        return Colors.grey;
    }
  }

  String get _label {
    switch (dificultad) {
      case 'facil':
        return 'Fácil';
      case 'moderado':
        return 'Moderado';
      case 'dificil':
        return 'Difícil';
      default:
        return dificultad;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ─── Avatar del autor ─────────────────────────────────────────────────────────

class _AvatarAutor extends StatelessWidget {
  final String nombre;
  final String? fotoUrl;
  const _AvatarAutor({required this.nombre, this.fotoUrl});

  @override
  Widget build(BuildContext context) {
    if (fotoUrl != null && fotoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: CachedNetworkImageProvider(fotoUrl!),
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.2),
      child: Text(
        nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF16A34A),
        ),
      ),
    );
  }
}

// ─── Galería de fotos ─────────────────────────────────────────────────────────

class _GaleriaFotos extends StatelessWidget {
  final List<String> urls;
  const _GaleriaFotos({required this.urls});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: urls[i],
            width: 120,
            height: 120,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

// ─── Sistema de rating interactivo ────────────────────────────────────────────

class _SistemaRating extends StatelessWidget {
  final double ratingActual;
  final int totalRatings;
  final double ratingSeleccionado;
  final bool yaCalificado;
  final bool calificando;
  final void Function(double) onCalificar;

  const _SistemaRating({
    required this.ratingActual,
    required this.totalRatings,
    required this.ratingSeleccionado,
    required this.yaCalificado,
    required this.calificando,
    required this.onCalificar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado con promedio actual
          Row(
            children: [
              Text(
                'Calificaciones',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              const Icon(
                Icons.star_rounded,
                size: 16,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(width: 3),
              Text(
                '${ratingActual.toStringAsFixed(1)} ($totalRatings)',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (yaCalificado)
            Text(
              'Ya calificaste esta ruta con ${ratingSeleccionado.toInt()}'
              ' estrella${ratingSeleccionado > 1 ? 's' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            Text(
              '¿Qué te pareció esta ruta?',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            // Estrellas interactivas (1 a 5)
            Row(
              children: List.generate(5, (i) {
                final estrella = (i + 1).toDouble();
                final activa = estrella <= ratingSeleccionado;
                return GestureDetector(
                  onTap: calificando ? null : () => onCalificar(estrella),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: calificando && estrella <= ratingSeleccionado
                        ? const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            activa
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 32,
                            color: activa
                                ? const Color(0xFFF59E0B)
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.3),
                          ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}
