import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ponto_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/ponto_service.dart';
import 'admin_funcionarios_page.dart';
import 'admin_relatorio_page.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erro: $e'))),
      data: (admin) {
        if (admin == null) return const Scaffold(body: Center(child: Text('Erro')));

        return Scaffold(
          backgroundColor: const Color(0xFFF0FDF4),
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('GeoPonto Pro — Admin', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text(admin.empresa, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => ref.read(authServiceProvider).logout(),
                tooltip: 'Sair',
              ),
            ],
          ),
          body: IndexedStack(
            index: _tabIndex,
            children: [
              _TabPontoHoje(),
              const AdminFuncionariosPage(),
              const AdminRelatorioPage(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (i) => setState(() => _tabIndex = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.today), label: 'Hoje'),
              NavigationDestination(icon: Icon(Icons.people), label: 'Funcionários'),
              NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Relatórios'),
            ],
          ),
        );
      },
    );
  }
}

// ─── Tab: Pontos de hoje ──────────────────────────────────────────────────────

class _TabPontoHoje extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final service = PontoService();
    final now = DateTime.now();

    return StreamBuilder<List<PontoModel>>(
      stream: service.streamTodosPontosHoje(),
      builder: (context, snapshot) {
        final pontos = snapshot.data ?? [];
        final funcionarios = <String, List<PontoModel>>{};
        for (final p in pontos) {
          funcionarios.putIfAbsent(p.usuarioId, () => []).add(p);
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(now).capitalize(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('${funcionarios.length} funcionário(s) com registros hoje',
                        style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 16),

                    // Cards resumo
                    Row(
                      children: [
                        _resumoCard('Total batidas', '${pontos.length}', Icons.touch_app, const Color(0xFF15803D)),
                        const SizedBox(width: 10),
                        _resumoCard('Trabalhando', '${_contarPresentes(funcionarios)}', Icons.work, const Color(0xFF3B82F6)),
                        const SizedBox(width: 10),
                        _resumoCard('Offline', '${pontos.where((p) => p.offline).length}', Icons.cloud_off, const Color(0xFFF59E0B)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('Funcionários', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            if (funcionarios.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Nenhum registro hoje ainda', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, idx) {
                    final uid = funcionarios.keys.elementAt(idx);
                    final pts = funcionarios[uid]!;
                    final nome = pts.first.usuarioNome;
                    final ultimaBatida = pts.last;
                    final presente = pts.any((p) => p.tipo == TipoBatida.entrada) &&
                        !pts.any((p) => p.tipo == TipoBatida.saida);

                    return Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: presente
                                    ? const Color(0xFFDCFCE7)
                                    : Colors.grey[100],
                                child: Text(nome[0].toUpperCase(),
                                    style: TextStyle(
                                        color: presente ? const Color(0xFF15803D) : Colors.grey[600],
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text('${pts.length} registros hoje',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: presente ? const Color(0xFFDCFCE7) : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  presente ? 'PRESENTE' : 'AUSENTE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: presente ? const Color(0xFF15803D) : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          // Mini linha do tempo
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: TipoBatida.values.map((tipo) {
                              final batida = pts.cast<PontoModel?>()
                                  .firstWhere((p) => p?.tipo == tipo, orElse: () => null);
                              return Column(
                                children: [
                                  Icon(
                                    _icone(tipo),
                                    size: 18,
                                    color: batida != null ? _cor(tipo) : Colors.grey[300],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    batida != null
                                        ? DateFormat('HH:mm').format(batida.timestamp)
                                        : '--:--',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: batida != null ? _cor(tipo) : Colors.grey[300],
                                    ),
                                  ),
                                  Text(tipo.label.split(' ').first,
                                      style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: funcionarios.length,
                ),
              ),
          ],
        );
      },
    );
  }

  int _contarPresentes(Map<String, List<PontoModel>> f) {
    return f.values.where((pts) =>
        pts.any((p) => p.tipo == TipoBatida.entrada) &&
        !pts.any((p) => p.tipo == TipoBatida.saida)).length;
  }

  Widget _resumoCard(String label, String valor, IconData icon, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cor.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: cor, size: 22),
            const SizedBox(height: 4),
            Text(valor, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cor)),
            Text(label, style: TextStyle(fontSize: 10, color: cor.withOpacity(0.8)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Color _cor(TipoBatida t) {
    switch (t) {
      case TipoBatida.entrada:       return const Color(0xFF15803D);
      case TipoBatida.saidaAlmoco:   return const Color(0xFFF59E0B);
      case TipoBatida.retornoAlmoco: return const Color(0xFF3B82F6);
      case TipoBatida.saida:         return const Color(0xFFEF4444);
    }
  }

  IconData _icone(TipoBatida t) {
    switch (t) {
      case TipoBatida.entrada:       return Icons.login;
      case TipoBatida.saidaAlmoco:   return Icons.restaurant;
      case TipoBatida.retornoAlmoco: return Icons.replay;
      case TipoBatida.saida:         return Icons.logout;
    }
  }
}

extension StrCapExt on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
