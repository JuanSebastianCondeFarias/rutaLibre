// apps/mobile/lib/features/community_routes/screens/community_routes_screen.dart
// Feed de rutas publicadas por la comunidad con filtros, shimmer y pull-to-refresh

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../models/community_route_model.dart';
import '../providers/community_routes_provider.dart';

// Colores de dificultad
const _colorFacil = Color(0xFF16A34A);
const _colorModerado = Color(0xFFF97316);
const _colorDificil = Color(0xFFDC2626);

/// Pantalla principal del feed de rutas de la comunidad.
class CommunityRoutesScreen extends StatefulWidget {
  const CommunityRoutesScreen({super.key});

  @override
  State<CommunityRoutesScreen> createState() => _CommunityRoutesScreenState();
}

class _CommunityRoutesScreenState extends State<CommunityRoutesScreen> {
  late final CommunityRoutesProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = CommunityRoutesProvider(ApiService(const FlutterSecureStorage()));
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  String get _ciudad => context.read<StorageService>().ciudadSeleccionada;

  Future<void> _cargar() => _provider.cargarRutas(_ciudad);

  Future<void> _onFiltro(String? dificultad) =>
      _provider.cambiarFiltro(_ciudad, dificultad);

  Future<void> _onPublicar() async {
    // Verificar autenticación antes de navegar al formulario
    final api = ApiService(const FlutterSecureStorage());
    final autenticado = await api.estaAutenticado;
    if (!mounted) return;

    if (!autenticado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inicia sesión para publicar una ruta'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    context.push('/comunidad/publicar');
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<CommunityRoutesProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Rutas de la comunidad'),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(50),
                child: _FiltroDificultad(
                  seleccionado: provider.filtroDificultad,
                  onSeleccionar: _onFiltro,
                ),
              ),
            ),
            body: _buildCuerpo(provider),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _onPublicar,
              icon: const Icon(Icons.add),
              label: const Text('Publicar ruta'),
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCuerpo(CommunityRoutesProvider provider) {
    if (provider.cargando) {
      return _ShimmerLista();
    }

    if (provider.error != null) {
      return _EstadoError(
        mensaje: provider.error!,
        onReintentar: _cargar,
      );
    }

    if (provider.rutas.isEmpty) {
      return const _EstadoVacio();
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: provider.rutas.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final ruta = provider.rutas[i];
          return _TarjetaRuta(
            ruta: ruta,
            onTap: () => context.push('/comunidad/${ruta.id}', extra: ruta),
          );
        },
      ),
    );
  }
}

// ─── Filtro de dificultad ───────────────────────────────────────────────────

class _FiltroDificultad extends StatelessWidget {
  final String? seleccionado;
  final void Function(String?) onSeleccionar;

  const _FiltroDificultad({
    required this.seleccionado,
    required this.onSeleccionar,
  });

  static const _opciones = [
    (value: null, label: 'Todas'),
    (value: 'facil', label: 'Fácil'),
    (value: 'moderado', label: 'Moderado'),
    (value: 'dificil', label: 'Difícil'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _opciones.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final opcion = _opciones[i];
          final sel = seleccionado == opcion.value;
          return FilterChip(
            label: Text(opcion.label, style: const TextStyle(fontSize: 12)),
            selected: sel,
            onSelected: (_) => onSeleccionar(opcion.value),
            selectedColor: theme.colorScheme.primaryContainer,
            checkmarkColor: theme.colorScheme.primary,
          );
        },
      ),
    );
  }
}

// ─── Tarjeta de ruta ────────────────────────────────────────────────────────

class _TarjetaRuta extends StatelessWidget {
  final CommunityRouteModel ruta;
  final VoidCallback onTap;

  const _TarjetaRuta({required this.ruta, required this.onTap});

  Color get _colorDificultad {
    switch (ruta.difficulty) {
      case 'facil':
        return _colorFacil;
      case 'moderado':
        return _colorModerado;
      case 'dificil':
        return _colorDificil;
      default:
        return Colors.grey;
    }
  }

  String get _labelDificultad {
    switch (ruta.difficulty) {
      case 'facil':
        return 'Fácil';
      case 'moderado':
        return 'Moderado';
      case 'dificil':
        return 'Difícil';
      default:
        return ruta.difficulty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorDif = _colorDificultad;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto de portada
            _FotoPortada(url: ruta.photoUrls.isNotEmpty ? ruta.photoUrls.first : null),

            Padding(
              padding: const EdgeInsets.all(12),
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorDif.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colorDif.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          _labelDificultad,
                          style: TextStyle(
                            color: colorDif,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Avatar y nombre del autor
                  Row(
                    children: [
                      _AvatarAutor(
                        nombre: ruta.authorName,
                        fotoUrl: ruta.authorPhotoUrl,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ruta.authorName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Rating con estrellas
                      _RatingCompacto(rating: ruta.rating, total: ruta.totalRatings),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Stats: km, tiempo, desnivel
                  Row(
                    children: [
                      _StatItem(icono: Icons.straighten, valor: ruta.distanciaFormateada),
                      const SizedBox(width: 16),
                      _StatItem(icono: Icons.schedule, valor: ruta.duracionFormateada),
                      const SizedBox(width: 16),
                      _StatItem(
                        icono: Icons.trending_up,
                        valor: '+${ruta.elevationGainM} m',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Foto de portada ────────────────────────────────────────────────────────

class _FotoPortada extends StatelessWidget {
  final String? url;
  const _FotoPortada({this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (url != null && url!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url!,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 160,
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        errorWidget: (_, __, ___) => _PlaceholderMapa(theme: theme),
      );
    }

    return _PlaceholderMapa(theme: theme);
  }
}

class _PlaceholderMapa extends StatelessWidget {
  final ThemeData theme;
  const _PlaceholderMapa({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.route,
              size: 40,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 4),
            Text(
              'Vista de ruta',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Avatar del autor ───────────────────────────────────────────────────────

class _AvatarAutor extends StatelessWidget {
  final String nombre;
  final String? fotoUrl;

  const _AvatarAutor({required this.nombre, this.fotoUrl});

  @override
  Widget build(BuildContext context) {
    if (fotoUrl != null && fotoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 12,
        backgroundImage: CachedNetworkImageProvider(fotoUrl!),
      );
    }
    return CircleAvatar(
      radius: 12,
      backgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.2),
      child: Text(
        nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF16A34A),
        ),
      ),
    );
  }
}

// ─── Rating compacto ─────────────────────────────────────────────────────────

class _RatingCompacto extends StatelessWidget {
  final double rating;
  final int total;

  const _RatingCompacto({required this.rating, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          ' ($total)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

// ─── Stat item ────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final IconData icono;
  final String valor;

  const _StatItem({required this.icono, required this.valor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 3),
        Text(
          valor,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Estados vacío y error ───────────────────────────────────────────────────

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pedal_bike_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no hay rutas en esta ciudad',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '¡Sé el primero en publicar una ruta!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoError extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;

  const _EstadoError({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              mensaje,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shimmer de carga ────────────────────────────────────────────────────────

class _ShimmerLista extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest;
    final highlightColor = theme.colorScheme.surface;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => _ShimmerTarjeta(),
      ),
    );
  }
}

class _ShimmerTarjeta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Foto placeholder
          Container(height: 160, color: Colors.white),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 16, width: double.infinity, color: Colors.white),
                const SizedBox(height: 8),
                Container(height: 12, width: 160, color: Colors.white),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(height: 12, width: 60, color: Colors.white),
                    const SizedBox(width: 16),
                    Container(height: 12, width: 60, color: Colors.white),
                    const SizedBox(width: 16),
                    Container(height: 12, width: 60, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
