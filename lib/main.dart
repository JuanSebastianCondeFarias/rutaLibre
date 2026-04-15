// apps/mobile/lib/main.dart
// Punto de entrada de la aplicación móvil RutaLibre

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/tracking_service.dart';
import 'core/theme/theme_provider.dart';
import 'features/alerts/providers/alerts_provider.dart';

void main() async {
  // Asegurar que Flutter esté inicializado
  WidgetsFlutterBinding.ensureInitialized();

  // Orientación preferida: portrait y landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Estilo de la barra de estado
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  // Inicializar Hive para almacenamiento local de actividades
  await Hive.initFlutter();

  // Inicializar Firebase para push notifications
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // En desarrollo puede no estar configurado — continuar sin Firebase
    debugPrint('Firebase no inicializado: $e');
  }

  // Vincular navigatorKey para que las notificaciones push puedan navegar
  NotificationService.navigatorKey = AppRouter.navigatorKey;

  // Inicializar servicio de notificaciones (requiere Firebase)
  await NotificationService.instance.initialize();

  // Inicializar almacenamiento local
  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);

  // Inicializar ThemeProvider con el tema guardado
  final themeProvider = ThemeProvider(prefs);

  // AlertsProvider: ciudad inicial desde StorageService
  final alertsProvider = AlertsProvider(
    prefs,
    citySlug: storageService.ciudadSeleccionada,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: alertsProvider),
        Provider.value(value: storageService),
        // TrackingService: lazy es aceptable; se crea al primer uso
        ChangeNotifierProvider(create: (_) => TrackingService()),
      ],
      child: const RutaLibreApp(),
    ),
  );
}
