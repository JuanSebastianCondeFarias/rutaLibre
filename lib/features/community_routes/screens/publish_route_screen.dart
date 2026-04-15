// apps/mobile/lib/features/community_routes/screens/publish_route_screen.dart
// Formulario para publicar una ruta grabada por el usuario

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';

/// Pantalla de publicación de una nueva ruta de la comunidad.
class PublishRouteScreen extends StatefulWidget {
  const PublishRouteScreen({super.key});

  @override
  State<PublishRouteScreen> createState() => _PublishRouteScreenState();
}

class _PublishRouteScreenState extends State<PublishRouteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  String _dificultad = 'moderado';
  bool _enviando = false;
  String? _error;

  static const _opcionesDificultad = [
    (value: 'facil', label: 'Fácil', descripcion: 'Terreno plano, ideal para principiantes', color: Color(0xFF16A34A)),
    (value: 'moderado', label: 'Moderado', descripcion: 'Algunas pendientes, nivel intermedio', color: Color(0xFFF97316)),
    (value: 'dificil', label: 'Difícil', descripcion: 'Pendientes pronunciadas, ciclistas experimentados', color: Color(0xFFDC2626)),
  ];

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      final api = ApiService(const FlutterSecureStorage());
      final city = context.read<StorageService>().ciudadSeleccionada;

      await api.publicarRutaComunidad(
        city: city,
        data: {
          'title': _tituloCtrl.text.trim(),
          'description': _descripcionCtrl.text.trim().isEmpty
              ? null
              : _descripcionCtrl.text.trim(),
          'difficulty': _dificultad,
          // TODO: adjuntar puntos de la actividad grabada cuando el módulo de
          // tracking esté implementado (ver features/tracking)
          'points': [],
          'photo_urls': [],
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ruta publicada exitosamente'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Regresar al feed de la comunidad
      context.pop();
    } catch (e) {
      setState(() => _error = 'Error al publicar la ruta: $e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicar ruta'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ─── Sección: actividad grabada ────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.route,
                        size: 20,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Actividad grabada',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'La importación de actividad grabada estará disponible '
                    'cuando el módulo de seguimiento (tracking) esté '
                    'implementado.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    // TODO: conectar con el módulo de tracking cuando esté disponible
                    onPressed: null,
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Importar actividad (próximamente)'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── Sección: información de la ruta ───────────────
            Text(
              'Información de la ruta',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 16),

            // Campo título
            TextFormField(
              controller: _tituloCtrl,
              decoration: const InputDecoration(
                labelText: 'Título *',
                hintText: 'Ej: Ciclovía Séptima — Parque Nacional',
                prefixIcon: Icon(Icons.title),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 100,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'El título es obligatorio';
                if (v.trim().length < 5) return 'Mínimo 5 caracteres';
                return null;
              },
            ),

            const SizedBox(height: 12),

            // Campo descripción
            TextFormField(
              controller: _descripcionCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText:
                    'Cuenta cómo es la ruta, qué ver en el camino, '
                    'consejos para otros ciclistas...',
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              maxLength: 500,
            ),

            const SizedBox(height: 20),

            // ─── Selector de dificultad ────────────────────────
            Text(
              'Dificultad',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            ..._opcionesDificultad.map((opcion) {
              final sel = _dificultad == opcion.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => setState(() => _dificultad = opcion.value),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: sel
                          ? opcion.color.withValues(alpha: 0.08)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel
                            ? opcion.color
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: opcion.color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opcion.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: sel ? opcion.color : null,
                                ),
                              ),
                              Text(
                                opcion.descripcion,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (sel)
                          Icon(Icons.check_circle, color: opcion.color, size: 20),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 12),

            // Mensaje de error
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                    fontSize: 13,
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Botón de envío
            FilledButton.icon(
              onPressed: _enviando ? null : _enviar,
              icon: _enviando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.publish),
              label: Text(
                _enviando ? 'Publicando...' : 'Publicar ruta',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFF16A34A),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
