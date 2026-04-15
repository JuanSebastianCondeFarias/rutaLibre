// apps/mobile/lib/features/challenges/widgets/challenge_card_widget.dart
// Widget de tarjeta de reto diario con barra de progreso

import 'package:flutter/material.dart';

/// Tarjeta que muestra un reto diario con su progreso.
class ChallengeCardWidget extends StatelessWidget {
  final Map<String, dynamic> reto;

  const ChallengeCardWidget({super.key, required this.reto});

  // Colores por dificultad
  Color _colorDificultad(BuildContext context, String dificultad) {
    switch (dificultad) {
      case 'facil':
        return Colors.green;
      case 'medio':
        return Colors.orange;
      case 'dificil':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _labelDificultad(String dificultad) {
    switch (dificultad) {
      case 'facil':
        return 'Fácil';
      case 'medio':
        return 'Medio';
      case 'dificil':
        return 'Difícil';
      default:
        return dificultad;
    }
  }

  // Ícono descriptivo según el tipo de reto
  IconData _iconTipo(String tipo) {
    switch (tipo) {
      case 'distancia':
        return Icons.directions_bike;
      case 'velocidad':
        return Icons.speed;
      case 'desnivel':
        return Icons.terrain;
      case 'puntos_de_interes':
        return Icons.place;
      default:
        return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completado = reto['completado'] as bool? ?? false;
    final progreso = (reto['mi_progreso'] as num?)?.toDouble() ?? 0;
    final meta = (reto['meta_valor'] as num).toDouble();
    final porcentaje = (progreso / meta).clamp(0.0, 1.0);
    final dificultad = reto['dificultad'] as String? ?? 'facil';
    final colorDif = _colorDificultad(context, dificultad);
    // tipo de reto para el ícono descriptivo
    final tipo = reto['tipo'] as String? ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: título y estado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícono descriptivo del tipo de reto
                Container(
                  margin: const EdgeInsets.only(right: 10, top: 2),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colorDif.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_iconTipo(tipo), size: 20, color: colorDif),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chip dificultad
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorDif.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _labelDificultad(dificultad),
                          style: TextStyle(
                            color: colorDif,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        reto['titulo'] as String? ?? '',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                // Badge "¡Completado!" en verde cuando el reto está terminado
                if (completado)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          '¡Completado!',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Descripción
            const SizedBox(height: 8),
            Text(
              reto['descripcion'] as String? ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),

            // Barra de progreso
            if (reto['mi_progreso'] != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$progreso / $meta ${reto['meta_unidad']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${(porcentaje * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: porcentaje,
                  backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completado ? theme.colorScheme.primary : theme.colorScheme.secondary,
                  ),
                  minHeight: 8,
                ),
              ),
            ],

            // Puntos
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
                const SizedBox(width: 4),
                Text(
                  '+${reto['puntos_recompensa']} puntos',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF59E0B),
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
