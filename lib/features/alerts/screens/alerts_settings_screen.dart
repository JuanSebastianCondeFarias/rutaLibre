// apps/mobile/lib/features/alerts/screens/alerts_settings_screen.dart
// Pantalla de configuración de alertas personalizadas (peligros y ciclovía)

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../../core/services/location_service.dart';
import '../models/user_zone_model.dart';
import '../providers/alerts_provider.dart';

/// Pantalla principal de configuración de alertas.
/// Accesible desde el perfil del usuario.
class AlertsSettingsScreen extends StatelessWidget {
  const AlertsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas personalizadas'),
      ),
      body: Consumer<AlertsProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _SeccionNotificaciones(provider: provider),
              const SizedBox(height: 8),
              _SeccionZonas(provider: provider),
            ],
          );
        },
      ),
    );
  }
}

// ─── Sección: Notificaciones ────────────────────────────────────

class _SeccionNotificaciones extends StatelessWidget {
  final AlertsProvider provider;
  const _SeccionNotificaciones({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Notificaciones',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              SwitchListTile(
                value: provider.peligrosActivos,
                onChanged: (_) => provider.togglePeligros(),
                title: const Text(
                  'Peligros en mis zonas',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Recibe alertas de huecos, obras y zonas inseguras cerca de tus zonas guardadas.',
                ),
                secondary: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                value: provider.cicloviaActiva,
                onChanged: (_) => provider.toggleCiclovia(),
                title: const Text(
                  'Ciclovía dominical',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Aviso cada domingo a las 7 AM cuando la Ciclovía esté activa.',
                ),
                secondary: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.directions_bike,
                    color: Color(0xFF16A34A),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Sección: Zonas de alerta ───────────────────────────────────

class _SeccionZonas extends StatelessWidget {
  final AlertsProvider provider;
  const _SeccionZonas({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zonas = provider.zonas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mis zonas de alerta',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${zonas.length}/${AlertsProvider.maxZonas}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),

        // Estado vacío
        if (zonas.isEmpty) _EstadoVacioZonas(theme: theme),

        // Lista de zonas
        if (zonas.isNotEmpty)
          ...zonas.map(
            (zona) => _ZonaCard(
              zona: zona,
              onEliminar: () => provider.eliminarZona(zona.id),
            ),
          ),

        // Botón agregar zona
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: provider.puedeAgregarZona
                  ? () => _mostrarBottomSheetAgregar(context, provider)
                  : null,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(
                provider.puedeAgregarZona
                    ? 'Agregar zona'
                    : 'Máximo ${AlertsProvider.maxZonas} zonas alcanzado',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: provider.puedeAgregarZona
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _mostrarBottomSheetAgregar(BuildContext context, AlertsProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: const _BottomSheetAgregarZona(),
      ),
    );
  }
}

// ─── Widget: Estado vacío ───────────────────────────────────────

class _EstadoVacioZonas extends StatelessWidget {
  final ThemeData theme;
  const _EstadoVacioZonas({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sin zonas de alerta',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Agrega lugares importantes para ti (tu casa, el trabajo, tu ruta habitual) '
                    'y te avisaremos cuando haya un peligro cerca.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widget: Tarjeta de zona ────────────────────────────────────

class _ZonaCard extends StatelessWidget {
  final UserZoneModel zona;
  final VoidCallback onEliminar;

  const _ZonaCard({required this.zona, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.location_on,
            color: Color(0xFF16A34A),
            size: 20,
          ),
        ),
        title: Text(
          zona.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Radio: ${zona.radiusLabel}',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: IconButton(
          onPressed: () => _confirmarEliminacion(context),
          icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
          tooltip: 'Eliminar zona',
        ),
      ),
    );
  }

  void _confirmarEliminacion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar zona'),
        content: Text('¿Eliminar la zona "${zona.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onEliminar();
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom Sheet: Agregar zona ─────────────────────────────────

class _BottomSheetAgregarZona extends StatefulWidget {
  const _BottomSheetAgregarZona();

  @override
  State<_BottomSheetAgregarZona> createState() => _BottomSheetAgregarZonaState();
}

class _BottomSheetAgregarZonaState extends State<_BottomSheetAgregarZona> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _locationService = LocationService();

  /// Radios disponibles en kilómetros.
  static const List<double> _radiosDisponibles = [0.5, 1.0, 2.0, 5.0];

  double _radioSeleccionado = 1.0;
  double? _lat;
  double? _lng;
  bool _cargandoUbicacion = false;
  bool _guardando = false;
  String? _errorUbicacion;

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _usarUbicacionActual() async {
    setState(() {
      _cargandoUbicacion = true;
      _errorUbicacion = null;
    });

    try {
      final Position posicion = await _locationService.obtenerUbicacionActual();
      setState(() {
        _lat = posicion.latitude;
        _lng = posicion.longitude;
      });
    } on LocationException catch (e) {
      setState(() => _errorUbicacion = e.mensaje);
    } catch (e) {
      setState(() => _errorUbicacion = 'No se pudo obtener la ubicación.');
    } finally {
      setState(() => _cargandoUbicacion = false);
    }
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_lat == null || _lng == null) {
      setState(() => _errorUbicacion = 'Debes seleccionar una ubicación.');
      return;
    }

    setState(() => _guardando = true);

    final zona = UserZoneModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nombreController.text.trim(),
      lat: _lat!,
      lng: _lng!,
      radiusKm: _radioSeleccionado,
    );

    final provider = context.read<AlertsProvider>();
    await provider.agregarZona(zona);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle del bottom sheet
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Nueva zona de alerta',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            // Campo: nombre
            TextFormField(
              controller: _nombreController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre de la zona',
                hintText: 'Ej: Mi casa, El trabajo...',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Ingresa un nombre para la zona';
                }
                if (val.trim().length > 40) {
                  return 'Máximo 40 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Selector de radio
            Text(
              'Radio de alerta',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _radiosDisponibles.map((radio) {
                final seleccionado = radio == _radioSeleccionado;
                final etiqueta = radio < 1.0
                    ? '${(radio * 1000).round()} m'
                    : '${radio.toString().replaceAll(RegExp(r'\.0$'), '')} km';

                return ChoiceChip(
                  label: Text(etiqueta),
                  selected: seleccionado,
                  onSelected: (_) => setState(() => _radioSeleccionado = radio),
                  selectedColor: theme.colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: seleccionado
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                    fontWeight: seleccionado ? FontWeight.w700 : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Botón: usar ubicación actual
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cargandoUbicacion ? null : _usarUbicacionActual,
                icon: _cargandoUbicacion
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  _lat != null
                      ? 'Ubicación capturada \u2713'
                      : 'Usar mi ubicación actual',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  foregroundColor: _lat != null
                      ? const Color(0xFF16A34A)
                      : theme.colorScheme.primary,
                  side: BorderSide(
                    color: _lat != null
                        ? const Color(0xFF16A34A)
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
            ),

            // Error de ubicación
            if (_errorUbicacion != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.error_outline, size: 14, color: Color(0xFFEF4444)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _errorUbicacion!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Botón confirmar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Guardar zona'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
