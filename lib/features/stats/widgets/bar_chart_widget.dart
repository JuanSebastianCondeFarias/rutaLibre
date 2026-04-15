// apps/mobile/lib/features/stats/widgets/bar_chart_widget.dart
// Gráfica de barras de km diarios usando fl_chart — reutilizable por ciudad

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/stats_model.dart';

/// Gráfica de barras con los km de los últimos 7 días.
/// El día actual se resalta en verde primario; días sin actividad en gris claro.
class BarChartWidget extends StatefulWidget {
  final List<DayStatModel> dias;

  const BarChartWidget({super.key, required this.dias});

  @override
  State<BarChartWidget> createState() => _BarChartWidgetState();
}

class _BarChartWidgetState extends State<BarChartWidget> {
  int? _indiceTouch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorPrimario = theme.colorScheme.primary;
    final colorGris = theme.colorScheme.onSurface.withValues(alpha: 0.15);

    // Valor máximo para escalar el eje Y con algo de margen
    final maxKm = widget.dias.isEmpty
        ? 10.0
        : widget.dias.map((d) => d.km).reduce((a, b) => a > b ? a : b);
    final maxY = maxKm < 5 ? 10.0 : maxKm * 1.25;

    final hoy = DateTime.now();

    return BarChart(
      BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(
          touchCallback: (event, response) {
            if (event is FlTapUpEvent || event is FlPanEndEvent) {
              setState(() {
                _indiceTouch = response?.spot?.touchedBarGroupIndex;
              });
            }
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex >= widget.dias.length) return null;
              final dia = widget.dias[groupIndex];
              final fecha = '${dia.fecha.day}/${dia.fecha.month}';
              final km = dia.km.toStringAsFixed(1);
              final min = dia.minutos;
              return BarTooltipItem(
                '$fecha\n$km km · ${min}min',
                TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            tooltipMargin: 6,
            tooltipBgColor: colorPrimario,
          ),
        ),
        titlesData: FlTitlesData(
          // Eje inferior: nombre corto del día
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= widget.dias.length) {
                  return const SizedBox.shrink();
                }
                final dia = widget.dias[index];
                final esHoy = dia.fecha.year == hoy.year &&
                    dia.fecha.month == hoy.month &&
                    dia.fecha.day == hoy.day;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    dia.nombreCorto,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: esHoy ? FontWeight.w700 : FontWeight.w400,
                      color: esHoy
                          ? colorPrimario
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                );
              },
            ),
          ),
          // Eje izquierdo: km
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: maxY / 4,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  '${value.round()}',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                );
              },
            ),
          ),
          // Ocultar ejes superior y derecho
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(widget.dias.length, (index) {
          final dia = widget.dias[index];
          final esHoy = dia.fecha.year == hoy.year &&
              dia.fecha.month == hoy.month &&
              dia.fecha.day == hoy.day;
          final sinActividad = dia.km == 0;
          final seleccionado = _indiceTouch == index;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: sinActividad ? 0 : dia.km,
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                color: sinActividad
                    ? colorGris
                    : esHoy
                        ? colorPrimario
                        : colorPrimario.withValues(alpha: seleccionado ? 1.0 : 0.55),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: colorGris.withValues(alpha: 0.3),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
