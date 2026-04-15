// apps/mobile/lib/features/stats/screens/stats_screen.dart
// Pantalla de estadísticas personales: resumen semanal, gráficas y logros del mes

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'package:universal_html/html.dart' as html;

import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../models/stats_model.dart';
import '../widgets/bar_chart_widget.dart';
import '../widgets/line_chart_widget.dart';

/// Pantalla principal de estadísticas personales del ciclista.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _apiService = ApiService(const FlutterSecureStorage());

  bool _cargando = true;
  bool _autenticado = false;
  String? _error;

  WeeklyStatsModel? _semana;
  MonthlyStatsModel? _mes;

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    final autenticado = await _apiService.estaAutenticado;
    if (!autenticado) {
      if (mounted) setState(() { _cargando = false; _autenticado = false; });
      return;
    }

    setState(() => _autenticado = true);

    final city = context.read<StorageService>().ciudadSeleccionada;

    try {
      // TODO: reemplazar con API real cuando el endpoint esté disponible
      final resultadoSemana = await _apiService.get<Map<String, dynamic>>(
        '/users/stats',
        queryParams: {'city': city, 'periodo': 'semana'},
      );
      final resultadoMes = await _apiService.get<Map<String, dynamic>>(
        '/users/stats',
        queryParams: {'city': city, 'periodo': 'mes'},
      );

      if (mounted) {
        setState(() {
          _semana = WeeklyStatsModel.fromJson(resultadoSemana.data!);
          _mes = MonthlyStatsModel.fromJson(resultadoMes.data!);
        });
      }
    } catch (_) {
      // API aún no disponible — usar datos de ejemplo
      if (mounted) {
        setState(() {
          _semana = _datosEjemploSemana();
          _mes = _datosEjemploMes();
        });
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ─── Datos de ejemplo ────────────────────────────────────────
  // TODO: reemplazar con API real cuando el endpoint /users/stats esté disponible

  WeeklyStatsModel _datosEjemploSemana() {
    final hoy = DateTime.now();
    final dias = List.generate(7, (i) {
      final fecha = hoy.subtract(Duration(days: 6 - i));
      // Simulamos actividad irregular
      final km = [0.0, 12.4, 0.0, 8.7, 15.2, 0.0, 6.5][i];
      final min = [0, 42, 0, 31, 55, 0, 24][i];
      return DayStatModel(fecha: fecha, km: km, minutos: min);
    });
    return WeeklyStatsModel(
      dias: dias,
      kmSemana: 42.8,
      kmSemanaAnterior: 35.1,
      rachaActual: 3,
      rachaMaxima: 7,
      velocidadPromedio: 18.5,
      desnivel: 320,
    );
  }

  MonthlyStatsModel _datosEjemploMes() {
    return const MonthlyStatsModel(
      kmPorSemana: [38.0, 52.5, 35.0, 42.8],
      kmMes: 168.3,
      rutasCompletadas: 12,
      contribuciones: 3,
    );
  }

  // ─── Utilidades ──────────────────────────────────────────────

  Future<void> _loginGoogle() async {
    if (kIsWeb) {
      html.window.location.href = _apiService.urlAuthGoogle;
      return;
    }
    final uri = Uri.parse('${_apiService.urlAuthGoogle}?platform=mobile');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el navegador para el login.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis estadísticas'),
        actions: [
          if (!_cargando)
            IconButton(
              onPressed: _cargarEstadisticas,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_cargando) return _buildShimmer(theme);
    if (!_autenticado) return _buildLoginPrompt(theme);
    if (_error != null) return _buildError(theme);
    return _buildContenido(theme);
  }

  // ─── Estado: no autenticado ──────────────────────────────────

  Widget _buildLoginPrompt(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart_rounded, size: 64, color: Color(0xFF16A34A)),
            const SizedBox(height: 16),
            Text(
              'Inicia sesión para ver tus estadísticas',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Registra tus km, rachas y progreso semanal como ciclista en Colombia.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loginGoogle,
                icon: const Icon(Icons.login),
                label: const Text('Entrar con Google'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Estado: error ───────────────────────────────────────────

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: theme.colorScheme.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _cargarEstadisticas,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  // ─── Estado: cargando (shimmer) ──────────────────────────────

  Widget _buildShimmer(ThemeData theme) {
    final base = theme.colorScheme.surfaceVariant;
    final highlight = theme.colorScheme.surface;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _shimmerBox(height: 110, borderRadius: 16),
          const SizedBox(height: 16),
          _shimmerBox(height: 56, borderRadius: 12),
          const SizedBox(height: 16),
          _shimmerBox(height: 200, borderRadius: 16),
          const SizedBox(height: 16),
          _shimmerBox(height: 200, borderRadius: 16),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _shimmerBox(height: 90, borderRadius: 12)),
              const SizedBox(width: 12),
              Expanded(child: _shimmerBox(height: 90, borderRadius: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _shimmerBox(height: 90, borderRadius: 12)),
              const SizedBox(width: 12),
              Expanded(child: _shimmerBox(height: 90, borderRadius: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox({required double height, double borderRadius = 8}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  // ─── Contenido principal ─────────────────────────────────────

  Widget _buildContenido(ThemeData theme) {
    final semana = _semana!;
    final mes = _mes!;
    final mejorDia = semana.mejorDia;

    return RefreshIndicator(
      onRefresh: _cargarEstadisticas,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sección 1: Resumen semanal
          _buildResumenSemana(theme, semana),
          const SizedBox(height: 16),

          // Chips: velocidad y desnivel
          _buildChipsDetalle(theme, semana),
          const SizedBox(height: 20),

          // Sección 2: Gráfica de barras (km diarios)
          _buildTarjetaGrafica(
            theme,
            titulo: 'Esta semana — km por día',
            subtitulo: 'Toca una barra para ver el detalle',
            child: SizedBox(
              height: 190,
              child: BarChartWidget(dias: semana.dias),
            ),
          ),
          const SizedBox(height: 16),

          // Sección 3: Gráfica de línea (km mensuales)
          _buildTarjetaGrafica(
            theme,
            titulo: 'Este mes — km por semana',
            subtitulo: 'Total: ${mes.kmMes.toStringAsFixed(1)} km',
            child: SizedBox(
              height: 190,
              child: LineChartWidget(kmPorSemana: mes.kmPorSemana),
            ),
          ),
          const SizedBox(height: 16),

          // Sección 4: Logros del mes (grid 2x2)
          _buildTituloSeccion(theme, 'Logros del mes'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _LogroCard(
                emoji: '🛣️',
                valor: '${mes.kmMes.toStringAsFixed(1)} km',
                label: 'Kilómetros totales',
                color: theme.colorScheme.primary,
              ),
              _LogroCard(
                emoji: '🗺️',
                valor: '${mes.rutasCompletadas}',
                label: 'Rutas completadas',
                color: const Color(0xFF0EA5E9),
              ),
              _LogroCard(
                emoji: '✅',
                valor: '${mes.contribuciones}',
                label: 'Contribuciones aprobadas',
                color: const Color(0xFF8B5CF6),
              ),
              _LogroCard(
                emoji: '⭐',
                valor: mejorDia != null
                    ? '${mejorDia.km.toStringAsFixed(1)} km'
                    : '—',
                label: 'Mejor día de la semana',
                color: const Color(0xFFF97316),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Sección 1: resumen semanal ──────────────────────────────

  Widget _buildResumenSemana(ThemeData theme, WeeklyStatsModel semana) {
    final diff = semana.diferenciaPorcentual;
    final mejora = diff >= 0;
    final colorDiff = mejora ? const Color(0xFF16A34A) : const Color(0xFFEF4444);
    final iconoDiff = mejora ? Icons.arrow_upward : Icons.arrow_downward;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Km grandes + comparativa
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Esta semana',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        semana.kmSemana.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'km',
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Comparativa vs semana anterior
                  Row(
                    children: [
                      Icon(iconoDiff, size: 14, color: colorDiff),
                      const SizedBox(width: 3),
                      Text(
                        '${diff.abs().toStringAsFixed(1)}% vs semana anterior',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorDiff,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Racha
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 4),
                    Text(
                      '${semana.rachaActual}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFF97316),
                      ),
                    ),
                  ],
                ),
                Text(
                  'días de racha',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Máx: ${semana.rachaMaxima} días',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Chips de detalle ────────────────────────────────────────

  Widget _buildChipsDetalle(ThemeData theme, WeeklyStatsModel semana) {
    return Row(
      children: [
        _Chip(
          icono: Icons.speed,
          texto: '${semana.velocidadPromedio.toStringAsFixed(1)} km/h',
          label: 'Velocidad prom.',
          theme: theme,
        ),
        const SizedBox(width: 8),
        _Chip(
          icono: Icons.landscape_outlined,
          texto: '+${semana.desnivel} m',
          label: 'Desnivel',
          theme: theme,
        ),
      ],
    );
  }

  // ─── Tarjeta gráfica ─────────────────────────────────────────

  Widget _buildTarjetaGrafica(
    ThemeData theme, {
    required String titulo,
    required String subtitulo,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              subtitulo,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  // ─── Título sección ──────────────────────────────────────────

  Widget _buildTituloSeccion(ThemeData theme, String texto) {
    return Text(
      texto,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

// ─── Widgets auxiliares ──────────────────────────────────────────────────────

/// Chip de estadística rápida (velocidad, desnivel, etc.).
class _Chip extends StatelessWidget {
  final IconData icono;
  final String texto;
  final String label;
  final ThemeData theme;

  const _Chip({
    required this.icono,
    required this.texto,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Icon(icono, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de logro mensual.
class _LogroCard extends StatelessWidget {
  final String emoji;
  final String valor;
  final String label;
  final Color color;

  const _LogroCard({
    required this.emoji,
    required this.valor,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const Spacer(),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              valor,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
