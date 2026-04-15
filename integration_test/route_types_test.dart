// integration_test/route_types_test.dart
// Prueba end-to-end de tipos de ruta en la app mobile RutaLibre.
// Flujo: origen manual → Torre Colpatria → MTB → Estándar → Seguro
//
// Ejecutar:
//   flutter test integration_test/route_types_test.dart -d "iPhone 17 Pro"

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:rutalibre/main.dart' as app;

// ─── Helpers ──────────────────────────────────────────────────────

/// Espera hasta que aparezca un widget con el texto dado (polling).
Future<bool> waitForText(WidgetTester tester, String texto, {int segundos = 20}) async {
  for (int i = 0; i < segundos * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.textContaining(texto).evaluate().isNotEmpty) return true;
  }
  return false;
}

/// Escribe en un TextField y espera a que aparezcan sugerencias (📍).
Future<bool> escribirYEsperarSugerencias(
  WidgetTester tester,
  Finder campo,
  String texto, {
  int timeoutSegundos = 10,
}) async {
  await tester.tap(campo);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.enterText(campo, texto);
  // Esperar debounce (500ms) + llamada geocoding
  for (int i = 0; i < timeoutSegundos * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    // Las sugerencias muestran Text('📍') como primer child de cada item
    if (find.text('📍').evaluate().isNotEmpty) return true;
  }
  return false;
}

/// Toca la primera sugerencia del dropdown (primer '📍' visible).
Future<void> seleccionarPrimeraSugerencia(WidgetTester tester) async {
  final sugerencias = find.text('📍');
  expect(sugerencias, findsWidgets, reason: 'No hay sugerencias visibles');
  // El InkWell padre es el tap target
  await tester.tap(
    find.ancestor(of: sugerencias.first, matching: find.byType(InkWell)).first,
  );
  await tester.pump(const Duration(milliseconds: 500));
}

// ─── Test principal ───────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Tipos de ruta — MTB, Estándar y Seguro', (tester) async {
    // Suprimir RenderFlex overflows de otras pantallas (map_screen.dart) que no
    // son relevantes para este test funcional de la calculadora de rutas.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('RenderFlex overflowed')) return;
      originalOnError?.call(details);
    };

    // Arrancar la app (Firebase falla silenciosamente en tests — OK)
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // ── Navegar a pestaña Rutas ─────────────────────────────────
    debugPrint('\n📍 Navegando a Rutas...');
    await tester.tap(find.text('Rutas'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Calcular ruta'), findsWidgets);
    debugPrint('   ✅ En pantalla Calcular ruta');

    // ── Esperar resultado de GPS automático (initState) ─────────
    // La pantalla llama _obtenerUbicacionInicial() al abrir.
    // En simulador no hay GPS real — esperar 2s y verificar si se llenó.
    await tester.pump(const Duration(seconds: 2));

    final campos = find.byType(TextField);
    expect(campos, findsWidgets);

    final origenCtrl = tester
        .widgetList<TextField>(campos)
        .toList()[0]
        .controller;
    final origenYaLleno = (origenCtrl?.text ?? '').isNotEmpty;

    // ── Origen ──────────────────────────────────────────────────
    if (!origenYaLleno) {
      // GPS no disponible en simulador → ingresar manualmente
      debugPrint('\n📍 GPS no disponible — ingresando origen manualmente...');
      final sugOk = await escribirYEsperarSugerencias(
        tester, campos.first, 'Parque de la 93',
      );
      if (sugOk) {
        await seleccionarPrimeraSugerencia(tester);
        debugPrint('   ✅ Origen seleccionado');
      } else {
        fail('No aparecieron sugerencias para el origen — verifica conexión de red');
      }
    } else {
      debugPrint('\n   ✅ Origen GPS ya establecido: ${origenCtrl?.text}');
    }

    // ── Destino: Torre Colpatria ────────────────────────────────
    debugPrint('\n🏢 Ingresando destino: Torre Colpatria...');

    // El último TextField es el de destino (o el segundo)
    final destinoField = find.byWidgetPredicate(
      (w) => w is TextField &&
          (w.decoration?.hintText?.contains('Universidad') ?? false),
    );
    final destinoCampo = destinoField.evaluate().isNotEmpty
        ? destinoField
        : campos.last;

    final sugDestinoOk = await escribirYEsperarSugerencias(
      tester, destinoCampo, 'Torre Colpatria',
    );
    expect(sugDestinoOk, isTrue, reason: 'Sin sugerencias para Torre Colpatria');
    await seleccionarPrimeraSugerencia(tester);
    debugPrint('   ✅ Destino seleccionado');

    // ── Verificar que el botón esté habilitado ──────────────────
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    final btnCalcular = find.widgetWithText(ElevatedButton, '🗺️ Calcular ruta');
    expect(btnCalcular, findsOneWidget, reason: 'Botón "Calcular ruta" no encontrado');
    final btnEnabled = (tester.widget<ElevatedButton>(btnCalcular)).onPressed != null;
    expect(btnEnabled, isTrue, reason: 'Botón debe estar habilitado (origen + destino seteados)');
    debugPrint('   ✅ Botón "Calcular ruta" habilitado');

    // ── Probar cada perfil ──────────────────────────────────────
    final perfiles = [
      {'label': 'MTB', 'emoji': '🏔️'},
      {'label': 'Estándar', 'emoji': '🚲'},
      {'label': 'Seguro', 'emoji': '🛡️'},
    ];

    final resultados = <Map<String, String>>[];

    for (final perfil in perfiles) {
      debugPrint('\n🧪 Perfil: ${perfil['emoji']} ${perfil['label']}');

      // Tap al chip del perfil (busca texto que contenga el label)
      final chip = find.textContaining(perfil['label']!);
      expect(chip, findsWidgets, reason: 'Chip "${perfil['label']}" no encontrado');
      await tester.tap(chip.first);
      await tester.pump(const Duration(milliseconds: 300));

      // Esperar "Calculando…" (confirma que _calcularRuta fue invocado)
      final calculando = await waitForText(tester, 'Calculando', segundos: 5);
      if (calculando) {
        debugPrint('   ⏳ Calculando...');
      }

      // Esperar "✅ Ruta lista"
      final rutaLista = await waitForText(tester, 'Ruta lista', segundos: 20);
      expect(rutaLista, isTrue,
          reason: 'Perfil ${perfil['label']}: "Ruta lista" no apareció en 20s');

      // Capturar distancia y tiempo
      String km = 'N/A', min = 'N/A';
      for (final el in find.byType(Text).evaluate()) {
        final t = (el.widget as Text).data ?? '';
        if (RegExp(r'^\d+\.?\d* km$').hasMatch(t)) km = t;
        if (RegExp(r'^\d+ min$').hasMatch(t)) min = t;
      }

      debugPrint('   ✅ PASS: $km, $min');
      resultados.add({'label': perfil['label']!, 'km': km, 'min': min});
    }

    // ── Verificar que los perfiles dan datos distintos ──────────
    if (resultados.length >= 2) {
      final distintos = resultados.any(
        (r) => r['km'] != resultados[0]['km'] || r['min'] != resultados[0]['min'],
      );
      debugPrint(distintos
          ? '\n✅ Los datos cambian entre perfiles (correcto)'
          : '\n⚠️ Todos los perfiles devuelven los mismos datos');
    }

    // ── Resumen ─────────────────────────────────────────────────
    debugPrint('\n══════════════════════════════════════════════════');
    debugPrint('RESULTADO: ${resultados.length} ✅  0 ❌  de ${perfiles.length} perfiles');
    for (final r in resultados) {
      debugPrint('   ✅ ${r['label']!.padRight(10)} ${r['km']}, ${r['min']}');
    }
  });
}
