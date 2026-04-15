// apps/mobile/lib/features/challenges/widgets/leaderboard_widget.dart
// Tabla de clasificación de ciclistas por ciudad

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/services/api_service.dart';

/// Widget que muestra el leaderboard (top 20) de una ciudad.
class LeaderboardWidget extends StatefulWidget {
  final String city;

  const LeaderboardWidget({super.key, required this.city});

  @override
  State<LeaderboardWidget> createState() => _LeaderboardWidgetState();
}

class _LeaderboardWidgetState extends State<LeaderboardWidget> {
  List<dynamic> _entries = [];
  int? _miPosicion;
  int _totalUsuarios = 0;
  bool _cargando = true;
  String? _error;

  static const _posicionEmojis = {1: '🥇', 2: '🥈', 3: '🥉'};

  @override
  void initState() {
    super.initState();
    _cargarLeaderboard();
  }

  @override
  void didUpdateWidget(LeaderboardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.city != widget.city) _cargarLeaderboard();
  }

  Future<void> _cargarLeaderboard() async {
    setState(() => _cargando = true);
    try {
      final apiService = ApiService(const FlutterSecureStorage());
      final data = await apiService.leaderboard(widget.city);
      if (mounted) {
        setState(() {
          _entries = (data['entries'] as List?) ?? [];
          _miPosicion = data['mi_posicion'] as int?;
          _totalUsuarios = (data['total_usuarios'] as num?)?.toInt() ?? 0;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error cargando clasificación');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_cargando) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _cargarLeaderboard, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Posición actual del usuario
        if (_miPosicion != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Tu posición actual: #$_miPosicion de $_totalUsuarios ciclistas',
              style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
            ),
          ),

        // Lista de usuarios
        ..._entries.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value as Map<String, dynamic>;
          final posicion = (e['posicion'] as num?)?.toInt() ?? (i + 1);
          final nombre = e['nombre'] as String? ?? 'Anónimo';
          final fotoUrl = e['foto_url'] as String?;
          final puntos = (e['puntos'] as num?)?.toInt() ?? 0;
          final nivel = (e['nivel'] as num?)?.toInt() ?? 1;
          final rango = e['rango'] as String? ?? '';
          final kmTotales = (e['km_totales'] as num?)?.toDouble() ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // Posición
                SizedBox(
                  width: 32,
                  child: Text(
                    _posicionEmojis[posicion] ?? '#$posicion',
                    style: TextStyle(
                      fontSize: posicion <= 3 ? 20 : 14,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),

                // Avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary,
                  backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                  child: fotoUrl == null
                      ? Text(nombre[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))
                      : null,
                ),
                const SizedBox(width: 12),

                // Nombre y rango
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(
                        'Nivel $nivel · $rango',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),

                // Puntos y km
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$puntos pts', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      '${kmTotales.round()} km',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
