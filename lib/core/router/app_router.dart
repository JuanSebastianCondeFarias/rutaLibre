// apps/mobile/lib/core/router/app_router.dart
// Configuración del router usando GoRouter

import 'dart:ui';

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../../features/alerts/screens/alerts_settings_screen.dart';
import '../../features/auth/screens/auth_callback_screen.dart';
import '../../features/challenges/screens/challenges_screen.dart';
import '../../features/community_routes/models/community_route_model.dart';
import '../../features/community_routes/screens/community_route_detail_screen.dart';
import '../../features/community_routes/screens/community_routes_screen.dart';
import '../../features/community_routes/screens/publish_route_screen.dart';
import '../../features/contributions/screens/contribution_screen.dart';
import '../../features/map/screens/map_screen.dart';
import '../../features/pois/screens/pois_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/routes/screens/route_calculator_screen.dart';
import '../../features/stats/screens/stats_screen.dart';
import '../../features/tracking/screens/activity_history_screen.dart';
import '../../features/tracking/screens/tracking_screen.dart';

/// Router principal de la aplicación con navegación en shell (bottom nav).
class AppRouter {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    routes: [
      // Ruta de callback OAuth — fuera del shell (sin bottom nav)
      GoRoute(
        path: '/auth/callback',
        builder: (context, state) => AuthCallbackScreen(
          accessToken: state.uri.queryParameters['access_token'],
          refreshToken: state.uri.queryParameters['refresh_token'],
          error: state.uri.queryParameters['error'],
        ),
      ),
      // Detalle de ruta de la comunidad — fuera del shell para pantalla completa
      GoRoute(
        path: '/comunidad/:id',
        builder: (context, state) {
          final ruta = state.extra as CommunityRouteModel;
          return CommunityRouteDetailScreen(ruta: ruta);
        },
      ),
      // Publicar ruta de la comunidad — fuera del shell
      GoRoute(
        path: '/comunidad/publicar',
        builder: (context, state) => const PublishRouteScreen(),
      ),
      // Configuración de alertas — fuera del shell (accesible desde perfil)
      GoRoute(
        path: '/alertas',
        builder: (context, state) => const AlertsSettingsScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => _MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const MapScreen(),
          ),
          GoRoute(
            path: '/rutas',
            builder: (context, state) => const RouteCalculatorScreen(),
          ),
          GoRoute(
            path: '/grabar',
            builder: (context, state) => const TrackingScreen(),
          ),
          GoRoute(
            path: '/actividades',
            builder: (context, state) => const ActivityHistoryScreen(),
          ),
          GoRoute(
            path: '/comunidad',
            builder: (context, state) => const CommunityRoutesScreen(),
          ),
          GoRoute(
            path: '/estadisticas',
            builder: (context, state) => const StatsScreen(),
          ),
          GoRoute(
            path: '/retos',
            builder: (context, state) => const ChallengesScreen(),
          ),
          GoRoute(
            path: '/contribuciones',
            builder: (context, state) => const ContributionScreen(),
          ),
          GoRoute(
            path: '/pois',
            builder: (context, state) => const PoisScreen(),
          ),
          GoRoute(
            path: '/perfil',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
}

/// Shell de navegación principal con BottomNavigationBar.
class _MainShell extends StatefulWidget {
  final Widget child;
  const _MainShell({required this.child});

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _indiceActual = 0;

  // Tabs principales del bottom nav — /comunidad, /estadisticas y /actividades siguen en el router pero no en el nav
  static const _rutas = ['/', '/retos', '/grabar', '/pois', '/perfil'];

  static const _items = [
    BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Mapa'),
    BottomNavigationBarItem(icon: Icon(Icons.emoji_events_outlined), activeIcon: Icon(Icons.emoji_events), label: 'Retos'),
    BottomNavigationBarItem(icon: Icon(Icons.fiber_manual_record_outlined), activeIcon: Icon(Icons.fiber_manual_record), label: 'Grabar'),
    BottomNavigationBarItem(icon: Icon(Icons.place_outlined), activeIcon: Icon(Icons.place), label: 'POIs'),
    BottomNavigationBarItem(icon: Icon(Icons.person_outlined), activeIcon: Icon(Icons.person), label: 'Perfil'),
  ];

  void _navegar(int indice) {
    setState(() => _indiceActual = indice);
    context.go(_rutas[indice]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBody: true, // contenido pasa por detrás del nav translúcido
      body: widget.child,
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: BottomNavigationBar(
            backgroundColor: isDark
                ? const Color(0xFF1E293B).withOpacity(0.85)
                : Colors.white.withOpacity(0.85),
            currentIndex: _indiceActual,
            onTap: _navegar,
            items: _items,
          ),
        ),
      ),
    );
  }
}
