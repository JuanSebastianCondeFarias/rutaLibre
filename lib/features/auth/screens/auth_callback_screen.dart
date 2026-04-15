// apps/mobile/lib/features/auth/screens/auth_callback_screen.dart
// Pantalla intermediaria que captura el callback OAuth y guarda los tokens

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/api_service.dart';

/// Pantalla de callback OAuth — captura access_token y refresh_token de la URL.
class AuthCallbackScreen extends StatefulWidget {
  final String? accessToken;
  final String? refreshToken;
  final String? error;

  const AuthCallbackScreen({
    super.key,
    this.accessToken,
    this.refreshToken,
    this.error,
  });

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  @override
  void initState() {
    super.initState();
    _procesarCallback();
  }

  Future<void> _procesarCallback() async {
    if (widget.accessToken != null && widget.refreshToken != null) {
      final apiService = ApiService(const FlutterSecureStorage());
      await apiService.guardarTokens(widget.accessToken!, widget.refreshToken!);
    }
    // Redirigir al perfil en ambos casos (éxito o error)
    if (mounted) context.go('/perfil');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hayError = widget.error != null;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hayError) ...[
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('Error al iniciar sesión', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(widget.error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
            ] else ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Iniciando sesión...'),
            ],
          ],
        ),
      ),
    );
  }
}
