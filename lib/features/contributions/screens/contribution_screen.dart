// apps/mobile/lib/features/contributions/screens/contribution_screen.dart
// Pantalla de contribuciones: listado con votación, filtros y formulario de reporte

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/storage_service.dart';

/// Pantalla de contribuciones comunitarias con listado, votación y creación.
class ContributionScreen extends StatefulWidget {
  const ContributionScreen({super.key});

  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends State<ContributionScreen> {
  List<dynamic> _contribuciones = [];
  bool _cargando = true;
  String _filtroEstado = '';
  bool _mostrarFormulario = false;

  static const _tipoLabels = {
    'route_update': '🗺️ Ciclorruta',
    'hazard': '⚠️ Peligro',
    'poi_add': '📍 Nuevo POI',
    'poi_update': '✏️ Actualizar POI',
    'road_closed': '🚧 Vía cerrada',
  };

  static const _statusColors = {
    'pending': Color(0xFFF59E0B),
    'approved': Color(0xFF16A34A),
    'rejected': Color(0xFFEF4444),
    'stale': Color(0xFF94A3B8),
  };

  static const _filtros = [
    {'value': '', 'label': 'Todos'},
    {'value': 'pending', 'label': 'Pendientes'},
    {'value': 'approved', 'label': 'Aprobados'},
    {'value': 'rejected', 'label': 'Rechazados'},
  ];

  @override
  void initState() {
    super.initState();
    _cargarContribuciones();
  }

  Future<void> _cargarContribuciones() async {
    final storage = context.read<StorageService>();
    final city = storage.ciudadSeleccionada;

    setState(() => _cargando = true);

    try {
      final apiService = ApiService(const FlutterSecureStorage());
      final data = await apiService.listarContribuciones(
        city,
        estado: _filtroEstado.isEmpty ? null : _filtroEstado,
      );
      if (mounted) {
        setState(() {
          _contribuciones = (data['items'] as List?) ?? [];
        });
      }
    } catch (e) {
      // Manejar error silenciosamente, lista vacía
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _votar(int id, bool esPositivo) async {
    final storage = context.read<StorageService>();
    final city = storage.ciudadSeleccionada;

    try {
      final apiService = ApiService(const FlutterSecureStorage());
      final actualizada = await apiService.votarContribucion(city, id, esPositivo);
      setState(() {
        _contribuciones = _contribuciones.map((c) {
          if ((c as Map<String, dynamic>)['id'] == id) return actualizada;
          return c;
        }).toList();
      });
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.contains('detail') ? 'Error al votar' : msg)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.flag, size: 22),
            SizedBox(width: 8),
            Text('Contribuciones'),
          ],
        ),
        actions: [
          if (!_mostrarFormulario)
            IconButton(
              onPressed: () => setState(() => _mostrarFormulario = true),
              icon: const Icon(Icons.add),
              tooltip: 'Nuevo reporte',
            ),
        ],
      ),
      body: Column(
        children: [
          // Filtros de estado
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filtros.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = _filtros[i];
                final sel = _filtroEstado == f['value'];
                return FilterChip(
                  label: Text(f['label']!, style: const TextStyle(fontSize: 12)),
                  selected: sel,
                  onSelected: (_) {
                    setState(() => _filtroEstado = f['value']!);
                    _cargarContribuciones();
                  },
                  selectedColor: theme.colorScheme.primaryContainer,
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Formulario de nuevo reporte (expandible)
          if (_mostrarFormulario)
            _FormularioReporte(
              onEnviado: () {
                setState(() => _mostrarFormulario = false);
                _cargarContribuciones();
              },
              onCancelar: () => setState(() => _mostrarFormulario = false),
            ),

          // Lista de contribuciones
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _contribuciones.isEmpty
                    ? Center(
                        child: Text(
                          'No hay contribuciones en este momento',
                          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _cargarContribuciones,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _contribuciones.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final c = _contribuciones[i] as Map<String, dynamic>;
                            return _ContribucionCard(
                              contribucion: c,
                              tipoLabels: _tipoLabels,
                              statusColors: _statusColors,
                              onVotar: (esPositivo) => _votar(c['id'] as int, esPositivo),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de contribución individual con votación.
class _ContribucionCard extends StatelessWidget {
  final Map<String, dynamic> contribucion;
  final Map<String, String> tipoLabels;
  final Map<String, Color> statusColors;
  final void Function(bool esPositivo) onVotar;

  const _ContribucionCard({
    required this.contribucion,
    required this.tipoLabels,
    required this.statusColors,
    required this.onVotar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tipo = contribucion['tipo'] as String? ?? '';
    final status = contribucion['status'] as String? ?? 'pending';
    final descripcion = contribucion['descripcion'] as String? ?? '';
    final autor = contribucion['autor_nombre'] as String? ?? 'Anónimo';
    final createdAt = contribucion['created_at'] as String?;
    final fotoUrl = contribucion['foto_url'] as String?;
    final lat = (contribucion['lat'] as num?)?.toDouble() ?? 0;
    final lng = (contribucion['lng'] as num?)?.toDouble() ?? 0;
    final upvotes = (contribucion['upvotes'] as num?)?.toInt() ?? 0;
    final downvotes = (contribucion['downvotes'] as num?)?.toInt() ?? 0;
    final miVoto = contribucion['mi_voto'];
    final statusColor = statusColors[status] ?? const Color(0xFF94A3B8);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: tipo + estado + foto
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(tipoLabels[tipo] ?? tipo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'por $autor · ${createdAt != null ? _formatearFecha(createdAt) : ''}',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),
                if (fotoUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(fotoUrl, width: 50, height: 50, fit: BoxFit.cover),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Descripción
            Text(descripcion, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),

            // Ubicación
            Text(
              '📍 ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),

            // Votación (solo si pendiente)
            if (status == 'pending') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  // Upvote
                  _VoteButton(
                    icon: Icons.thumb_up_outlined,
                    count: upvotes,
                    activo: miVoto == true,
                    color: theme.colorScheme.primary,
                    onTap: () => onVotar(true),
                  ),
                  const SizedBox(width: 12),
                  // Downvote
                  _VoteButton(
                    icon: Icons.thumb_down_outlined,
                    count: downvotes,
                    activo: miVoto == false,
                    color: theme.colorScheme.error,
                    onTap: () => onVotar(false),
                  ),
                  const Spacer(),
                  Text(
                    'Necesita ${10 - upvotes} votos más',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatearFecha(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

/// Botón de voto (upvote/downvote).
class _VoteButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool activo;
  final Color color;
  final VoidCallback onTap;

  const _VoteButton({
    required this.icon,
    required this.count,
    required this.activo,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: activo ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: activo ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: activo ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulario de creación de nueva contribución.
class _FormularioReporte extends StatefulWidget {
  final VoidCallback onEnviado;
  final VoidCallback onCancelar;

  const _FormularioReporte({required this.onEnviado, required this.onCancelar});

  @override
  State<_FormularioReporte> createState() => _FormularioReporteState();
}

class _FormularioReporteState extends State<_FormularioReporte> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  String _tipo = 'hazard';
  File? _foto;
  bool _enviando = false;
  String? _error;

  static const _tipos = [
    {'value': 'hazard', 'label': 'Peligro en vía', 'emoji': '⚠️'},
    {'value': 'road_closed', 'label': 'Vía cerrada', 'emoji': '🚧'},
    {'value': 'route_update', 'label': 'Ciclorruta desactualizada', 'emoji': '🗺️'},
    {'value': 'poi_add', 'label': 'Sugerir POI', 'emoji': '📍'},
    {'value': 'poi_update', 'label': 'Actualizar POI', 'emoji': '✏️'},
  ];

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _tomarFoto(ImageSource fuente) async {
    final picker = ImagePicker();
    final imagen = await picker.pickImage(source: fuente, maxWidth: 1920, imageQuality: 85);
    if (imagen != null) {
      setState(() => _foto = File(imagen.path));
    }
  }

  Future<void> _usarUbicacionActual() async {
    try {
      final pos = await LocationService().obtenerUbicacionActual();
      setState(() {
        _latCtrl.text = pos.latitude.toStringAsFixed(6);
        _lngCtrl.text = pos.longitude.toStringAsFixed(6);
      });
    } on LocationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.mensaje), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    final storage = context.read<StorageService>();

    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      final apiService = ApiService(const FlutterSecureStorage());
      await apiService.crearContribucion(
        city: storage.ciudadSeleccionada,
        tipo: _tipo,
        descripcion: _descripcionCtrl.text,
        lat: double.parse(_latCtrl.text),
        lng: double.parse(_lngCtrl.text),
        foto: _foto,
      );
      widget.onEnviado();
    } catch (e) {
      setState(() => _error = 'Error enviando reporte: $e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3))),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Nuevo reporte', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                IconButton(onPressed: widget.onCancelar, icon: const Icon(Icons.close, size: 20), padding: EdgeInsets.zero),
              ],
            ),
            const SizedBox(height: 8),

            // Tipo
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _tipos.map((t) {
                final sel = _tipo == t['value'];
                return FilterChip(
                  label: Text('${t['emoji']} ${t['label']}', style: const TextStyle(fontSize: 11)),
                  selected: sel,
                  onSelected: (_) => setState(() => _tipo = t['value']!),
                  selectedColor: theme.colorScheme.primaryContainer,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 8),

            // Descripción
            TextFormField(
              controller: _descripcionCtrl,
              decoration: const InputDecoration(hintText: 'Describe el problema...', isDense: true),
              maxLines: 2,
              validator: (v) => v!.length < 10 ? 'Mínimo 10 caracteres' : null,
            ),
            const SizedBox(height: 8),

            // Ubicación
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latCtrl,
                    decoration: const InputDecoration(labelText: 'Lat', isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (v) => v!.isEmpty ? 'Req.' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _lngCtrl,
                    decoration: const InputDecoration(labelText: 'Lng', isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (v) => v!.isEmpty ? 'Req.' : null,
                  ),
                ),
                IconButton(
                  onPressed: _usarUbicacionActual,
                  icon: const Icon(Icons.my_location, size: 20),
                  tooltip: 'Usar ubicación actual',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Foto
            if (_foto != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_foto!, height: 80, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4, right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _foto = null),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => _tomarFoto(ImageSource.camera), icon: const Icon(Icons.camera_alt, size: 16), label: const Text('Cámara', style: TextStyle(fontSize: 12)))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(onPressed: () => _tomarFoto(ImageSource.gallery), icon: const Icon(Icons.photo_library, size: 16), label: const Text('Galería', style: TextStyle(fontSize: 12)))),
                ],
              ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
              ),

            const SizedBox(height: 8),

            // Enviar
            ElevatedButton.icon(
              onPressed: _enviando ? null : _enviar,
              icon: _enviando
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, size: 16),
              label: Text(_enviando ? 'Enviando...' : 'Enviar reporte', style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
