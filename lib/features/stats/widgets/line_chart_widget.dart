// apps/mobile/lib/features/stats/widgets/line_chart_widget.dart
// Gráfica de línea mensual con gradiente verde — km por semana del mes actual

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Gráfica de línea con área rellena en gradiente verde.
/// Recibe una lista de km por semana (hasta 4 semanas del mes).
class LineChartWidget extends StatefulWidget {
  final List<double> kmPorSemana;

  const LineChartWidget({super.key, required this.kmPorSemana});

  @override
  State<LineChartWidget> createState() => _LineChartWidgetState();
}

class _LineChartWidgetState extends State<LineChartWidget> {
  List<int> _tocados = [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorPrimario = theme.colorScheme.primary;

    final datos = widget.kmPorSemana.isEmpty ? [0.0] : widget.kmPorSemana;
    final maxKm = datos.reduce((a, b) => a > b ? a : b);
    final maxY = maxKm < 5 ? 10.0 : maxKm * 1.3;

    final spots = List.generate(
      datos.length,
      (i) => FlSpot(i.toDouble(), datos[i]),
    );

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (datos.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchCallback: (event, response) {
            if (event is FlTapUpEvent || event is FlPanEndEvent) {
              setState(() {
                _tocados = response?.lineBarSpots
                        ?.map((s) => s.spotIndex)
                        .toList() ??
                    [];
              });
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) {
              return spots.map((spot) {
                return LineTooltipItem(
                  'S${spot.x.toInt() + 1}\n${spot.y.toStringAsFixed(1)} km',
                  TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
            tooltipBgColor: colorPrimario,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          handleBuiltInTouches: true,
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final semana = value.toInt() + 1;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'S$semana',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                );
              },
            ),
          ),
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
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: colorPrimario,
            barWidth: 3,
            isStrokeCapRound: true,
            // Puntos interactivos en la línea
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                final seleccionado = _tocados.contains(index);
                return FlDotCirclePainter(
                  radius: seleccionado ? 7 : 5,
                  color: seleccionado ? colorPrimario : Colors.white,
                  strokeColor: colorPrimario,
                  strokeWidth: 2.5,
                );
              },
            ),
            // Gradiente verde semitransparente bajo la línea
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  colorPrimario.withValues(alpha: 0.35),
                  colorPrimario.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
