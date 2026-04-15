// apps/mobile/lib/features/profile/screens/profile_screen.dart
// Perfil del usuario con auth OAuth, nivel y estadísticas

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
// ignore: avoid_web_libraries_in_flutter
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/api_service.dart';
import '../../../core/widgets/gradient_button.dart';
import '../widgets/rank_widget.dart';

/// Pantalla de perfil del usuario con estadísticas y rango.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _apiService = ApiService(const FlutterSecureStorage());
  Map<String, dynamic>? _perfil;
  bool _cargando = true;
  bool _autenticado = false;
  bool _esDemo = false;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    setState(() => _cargando = true);

    final autenticado = await _apiService.estaAutenticado;
    if (!autenticado) {
      if (mounted) setState(() { _cargando = false; _autenticado = false; });
      return;
    }

    try {
      final esDemo = await _apiService.esModoDemo;
      final perfil = await _apiService.miPerfil();
      if (mounted) {
        setState(() {
          _perfil = perfil;
          _autenticado = true;
          _esDemo = esDemo;
        });
      }
    } catch (_) {
      // Token inválido o API caída
      if (mounted) setState(() => _autenticado = false);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _loginDemo() async {
    await _apiService.loginComoDemo();
    await _cargarPerfil();
  }

  Future<void> _loginGoogle() async {
    if (kIsWeb) {
      html.window.location.href = _apiService.urlAuthGoogle;
      return;
    }
    // En mobile: abrir el navegador con platform=mobile para que el backend
    // redirija a co.rutalibre://auth/callback en lugar de la web
    final uri = Uri.parse('${_apiService.urlAuthGoogle}?platform=mobile');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el navegador para el login.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _logout() async {
    await _apiService.cerrarSesion();
    if (mounted) {
      setState(() {
        _perfil = null;
        _autenticado = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Mi perfil'),
            if (_esDemo) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFD761A).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFD761A).withOpacity(0.4)),
                ),
                child: const Text(
                  'DEMO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Color(0xFFFD761A),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_autenticado)
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar sesión',
            ),
          IconButton(
            onPressed: () => context.push('/alertas'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Alertas y configuración',
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : !_autenticado || _perfil == null
              ? _buildLoginPrompt(theme)
              : _buildPerfilContent(theme),
    );
  }

  Widget _buildLoginPrompt(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF006B2C), Color(0xFF00873A)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.directions_bike, size: 44, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              'Tu ruta empieza aquí',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Acumula puntos, sube de nivel y contribuye al mapa ciclista de Colombia.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            // Botón Google
            GradientButton(
              label: 'Entrar con Google',
              leading: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const _GoogleLogo(),
              ),
              onPressed: _loginGoogle,
            ),
            const SizedBox(height: 12),
            // Separador
            Row(
              children: [
                Expanded(child: Divider(color: theme.colorScheme.outline.withValues(alpha: 0.4))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'o',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                Expanded(child: Divider(color: theme.colorScheme.outline.withValues(alpha: 0.4))),
              ],
            ),
            const SizedBox(height: 12),
            // Botón demo
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loginDemo,
                icon: const Icon(Icons.science_outlined, size: 18),
                label: const Text(
                  'Probar sin cuenta',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: theme.colorScheme.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerfilContent(ThemeData theme) {
    final nombre = _perfil!['nombre'] as String? ?? '';
    final email = _perfil!['email'] as String? ?? '';
    final fotoUrl = _perfil!['foto_url'] as String?;
    final nivel = (_perfil!['nivel'] as num?)?.toInt() ?? 1;
    final rango = _perfil!['rango'] as String? ?? 'Ciclista Novato';
    final puntos = (_perfil!['puntos'] as num?)?.toInt() ?? 0;
    final puntosParaSubir = (_perfil!['puntos_para_subir'] as num?)?.toInt();
    final kmTotales = (_perfil!['km_totales'] as num?)?.toDouble() ?? 0;
    final rutasCompletadas = (_perfil!['rutas_completadas'] as num?)?.toInt() ?? 0;
    final retosCompletados = (_perfil!['retos_completados'] as num?)?.toInt() ?? 0;
    final contribucionesAprobadas = (_perfil!['contribuciones_aprobadas'] as num?)?.toInt() ?? 0;
    final createdAt = _perfil!['created_at'] as String?;

    return RefreshIndicator(
      onRefresh: _cargarPerfil,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cabecera con avatar y nombre
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.colorScheme.primary,
                  backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                  child: fotoUrl == null
                      ? Text(
                          nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(nombre, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(email, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 16),
                RankWidget(
                  nivel: nivel,
                  rango: rango,
                  puntos: puntos,
                  puntosParaSubir: puntosParaSubir,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Estadísticas
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _StatCard('🛣️', '${kmTotales.round()} km', 'Kilómetros totales'),
              _StatCard('🗺️', '$rutasCompletadas', 'Rutas completadas'),
              _StatCard('🏆', '$retosCompletados', 'Retos completados'),
              _StatCard('✅', '$contribucionesAprobadas', 'Contribuciones'),
            ],
          ),

          const SizedBox(height: 24),

          // Miembro desde
          if (createdAt != null)
            Center(
              child: Text(
                'Miembro desde ${_formatearFecha(createdAt)}',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ),
        ],
      ),
    );
  }

  String _formatearFecha(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      const meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
      return '${meses[dt.month - 1]} de ${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

/// Letra "G" estilizada para el botón de login con Google.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF4285F4),
        height: 1.0,
      ),
    );
  }
}

/// Tarjeta de estadística.
class _StatCard extends StatelessWidget {
  final String emoji;
  final String valor;
  final String label;

  const _StatCard(this.emoji, this.valor, this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              valor,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
