// apps/mobile/lib/features/profile/widgets/rank_widget.dart
// Widget que muestra el rango y nivel del usuario

import 'package:flutter/material.dart';

/// Widget de rango con badge visual y barra de progreso hacia el siguiente nivel.
class RankWidget extends StatelessWidget {
  final int nivel;
  final String rango;
  final int puntos;
  final int? puntosParaSubir;

  const RankWidget({
    super.key,
    required this.nivel,
    required this.rango,
    required this.puntos,
    this.puntosParaSubir,
  });

  static const _emojis = {
    1: '🚲',
    2: '🟢',
    3: '🔵',
    4: '🟣',
    5: '🔴',
    6: '⭐',
    7: '🏆',
  };

  static const _colores = {
    1: Color(0xFF64748B),
    2: Color(0xFF16A34A),
    3: Color(0xFF2563EB),
    4: Color(0xFF7C3AED),
    5: Color(0xFFEA580C),
    6: Color(0xFFDC2626),
    7: Color(0xFFD97706),
  };

  Color get _color => _colores[nivel] ?? _colores[1]!;
  String get _emoji => _emojis[nivel] ?? '🚲';

  double get _progresoBarra {
    if (puntosParaSubir == null || nivel >= 7) return 1.0;
    // Calcular progreso dentro del nivel actual
    const rangos = [
      (0, 499),
      (500, 1499),
      (1500, 3999),
      (4000, 7999),
      (8000, 14999),
      (15000, 29999),
      (30000, 99999),
    ];
    if (nivel <= 0 || nivel > rangos.length) return 0;
    final (min, max) = rangos[nivel - 1];
    return ((puntos - min) / (max - min)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Badge de nivel
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nivel $nivel — $rango',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: _color,
                    ),
                  ),
                  Text(
                    '${puntos.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} puntos',
                    style: TextStyle(
                      fontSize: 12,
                      color: _color.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Barra de progreso al siguiente nivel
          if (nivel < 7 && puntosParaSubir != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progresoBarra,
                backgroundColor: _color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(_color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Faltan $puntosParaSubir pts para nivel ${nivel + 1}',
              style: TextStyle(fontSize: 11, color: _color.withOpacity(0.6)),
            ),
          ] else if (nivel >= 7) ...[
            const SizedBox(height: 8),
            Text(
              '¡Nivel máximo alcanzado!',
              style: TextStyle(fontSize: 12, color: _color.withOpacity(0.7), fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}
