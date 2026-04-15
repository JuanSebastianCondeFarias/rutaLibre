// apps/mobile/lib/app.dart
// MaterialApp principal con router y tema dinámico

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

class RutaLibreApp extends StatelessWidget {
  const RutaLibreApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios de tema
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp.router(
      title: 'RutaLibre',
      debugShowCheckedModeBanner: false,

      // Tema claro y oscuro
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,

      // Router
      routerConfig: AppRouter.router,

      // Localización
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'CO'),
        Locale('en', 'US'),
      ],
      locale: const Locale('es', 'CO'),
    );
  }
}
