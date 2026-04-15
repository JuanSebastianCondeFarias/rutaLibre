// apps/mobile/lib/features/stats/models/stats_model.dart
// Modelos de datos para estadísticas personales del usuario (semanal y mensual)

/// Estadística de un día individual.
class DayStatModel {
  final DateTime fecha;
  final double km;
  final int minutos;

  const DayStatModel({
    required this.fecha,
    required this.km,
    required this.minutos,
  });

  factory DayStatModel.fromJson(Map<String, dynamic> json) {
    return DayStatModel(
      fecha: DateTime.parse(json['fecha'] as String),
      km: (json['km'] as num).toDouble(),
      minutos: (json['minutos'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'fecha': fecha.toIso8601String(),
        'km': km,
        'minutos': minutos,
      };

  /// Nombre corto del día para etiquetas del gráfico.
  String get nombreCorto {
    const dias = ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sa', 'Do'];
    // weekday: 1=lunes, 7=domingo
    return dias[fecha.weekday - 1];
  }
}

/// Estadísticas de la semana actual con comparativa vs semana anterior.
class WeeklyStatsModel {
  /// Últimos 7 días ordenados del más antiguo al más reciente.
  final List<DayStatModel> dias;
  final double kmSemana;
  final double kmSemanaAnterior;
  final int rachaActual;
  final int rachaMaxima;
  final double velocidadPromedio;
  final int desnivel;

  const WeeklyStatsModel({
    required this.dias,
    required this.kmSemana,
    required this.kmSemanaAnterior,
    required this.rachaActual,
    required this.rachaMaxima,
    required this.velocidadPromedio,
    required this.desnivel,
  });

  factory WeeklyStatsModel.fromJson(Map<String, dynamic> json) {
    final diasJson = json['dias'] as List<dynamic>? ?? [];
    return WeeklyStatsModel(
      dias: diasJson
          .map((d) => DayStatModel.fromJson(d as Map<String, dynamic>))
          .toList(),
      kmSemana: (json['km_semana'] as num).toDouble(),
      kmSemanaAnterior: (json['km_semana_anterior'] as num).toDouble(),
      rachaActual: (json['racha_actual'] as num).toInt(),
      rachaMaxima: (json['racha_maxima'] as num).toInt(),
      velocidadPromedio: (json['velocidad_promedio'] as num).toDouble(),
      desnivel: (json['desnivel'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'dias': dias.map((d) => d.toJson()).toList(),
        'km_semana': kmSemana,
        'km_semana_anterior': kmSemanaAnterior,
        'racha_actual': rachaActual,
        'racha_maxima': rachaMaxima,
        'velocidad_promedio': velocidadPromedio,
        'desnivel': desnivel,
      };

  /// Diferencia porcentual vs semana anterior (positivo = mejora).
  double get diferenciaPorcentual {
    if (kmSemanaAnterior == 0) return 0;
    return ((kmSemana - kmSemanaAnterior) / kmSemanaAnterior) * 100;
  }

  /// Mejor día (máximo km) de la semana.
  DayStatModel? get mejorDia {
    if (dias.isEmpty) return null;
    return dias.reduce((a, b) => a.km > b.km ? a : b);
  }
}

/// Estadísticas del mes actual agrupadas por semana.
class MonthlyStatsModel {
  /// Km por semana — índice 0 = primera semana del mes, hasta 4 semanas.
  final List<double> kmPorSemana;
  final double kmMes;
  final int rutasCompletadas;
  final int contribuciones;

  const MonthlyStatsModel({
    required this.kmPorSemana,
    required this.kmMes,
    required this.rutasCompletadas,
    required this.contribuciones,
  });

  factory MonthlyStatsModel.fromJson(Map<String, dynamic> json) {
    final semanas = json['km_por_semana'] as List<dynamic>? ?? [];
    return MonthlyStatsModel(
      kmPorSemana: semanas.map((v) => (v as num).toDouble()).toList(),
      kmMes: (json['km_mes'] as num).toDouble(),
      rutasCompletadas: (json['rutas_completadas'] as num).toInt(),
      contribuciones: (json['contribuciones'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'km_por_semana': kmPorSemana,
        'km_mes': kmMes,
        'rutas_completadas': rutasCompletadas,
        'contribuciones': contribuciones,
      };
}
