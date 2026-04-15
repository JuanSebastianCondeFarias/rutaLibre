// apps/mobile/lib/features/challenges/screens/challenges_screen.dart
// Pantalla de retos diarios con tabs: Retos y Leaderboard

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../widgets/challenge_card_widget.dart';
import '../widgets/leaderboard_widget.dart';

/// Pantalla de retos diarios con leaderboard.
class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<dynamic> _retos = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarRetos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarRetos() async {
    final storage = context.read<StorageService>();
    final city = storage.ciudadSeleccionada;

    setState(() => _cargando = true);

    try {
      final apiService = ApiService(const FlutterSecureStorage());
      final retos = await apiService.listarRetos(city);
      setState(() {
        _retos = retos;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Error cargando retos: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storage = context.read<StorageService>();
    final city = storage.ciudadSeleccionada;
    final completados = _retos.where((r) => r['completado'] == true).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.emoji_events, size: 22),
            const SizedBox(width: 8),
            const Text('Retos diarios'),
            if (_retos.isNotEmpty) ...[
              const Spacer(),
              Text(
                '$completados/${_retos.length}',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(onPressed: _cargarRetos, icon: const Icon(Icons.refresh)),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '🏆 Retos'),
            Tab(text: '🏅 Clasificación'),
          ],
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab: Retos
          _buildRetosTab(theme),

          // Tab: Leaderboard
          LeaderboardWidget(city: city),
        ],
      ),
    );
  }

  Widget _buildRetosTab(ThemeData theme) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _cargarRetos, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarRetos,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner: inicia sesión
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Inicia sesión para guardar tu progreso y ganar puntos',
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
          ),

          // Lista de retos
          ...List.generate(
            _retos.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ChallengeCardWidget(reto: _retos[i] as Map<String, dynamic>),
            ),
          ),
        ],
      ),
    );
  }
}
