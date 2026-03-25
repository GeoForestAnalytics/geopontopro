import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
        if (admin == null) return const Scaffold(body: Center(child: Text('Acesso negado')));

        return Scaffold(
          backgroundColor: const Color(0xFFF0FDF4),
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Painel Gerencial', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(admin.empresaNome, style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout), 
                onPressed: () => ref.read(authServiceProvider).logout(),
                tooltip: 'Sair',
              )
            ],
          ),
          body: IndexedStack(
            index: _tabIndex,
            children: [
              _TabMonitor(admin: admin),
              const AdminFuncionariosPage(),
              const AdminRelatorioPage(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (i) => setState(() => _tabIndex = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Monitor'),
              NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Equipe'),
              NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Relatórios'),
            ],
          ),
        );
      },
    );
  }
}

class _TabMonitor extends ConsumerWidget {
  final UserModel admin;
  const _TabMonitor({required this.admin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pontosAsync = ref.watch(monitorPontosProvider(admin.empresaId));
    final now = DateTime.now();

    return pontosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar monitor: $e')),
      data: (pontos) {
        final equipeAtiva = pontos.map((p) => p.usuarioId).toSet().length;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    _card('Batidas Hoje', '${pontos.length}', Colors.green),
                    const SizedBox(width: 10),
                    _card('Equipe Ativa', '$equipeAtiva', Colors.blue),
                  ],
                ),
              ),
            ),
            if (pontos.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('Nenhuma atividade registrada hoje.', style: TextStyle(color: Colors.grey))),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final p = pontos[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), 
                        // CORREÇÃO: No RoundedRectangleBorder usamos 'side' e não 'border'
                        side: BorderSide(color: Colors.grey[200]!)
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getCor(p.tipo).withOpacity(0.1),
                          child: Icon(_getIcon(p.tipo), color: _getCor(p.tipo), size: 20),
                        ),
                        title: Text(p.usuarioNome, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${p.tipo.label} • ${DateFormat('HH:mm').format(p.timestamp)}'),
                        trailing: const Icon(Icons.gps_fixed, size: 14, color: Colors.grey),
                      ),
                    );
                  },
                  childCount: pontos.length,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _card(String label, String valor, Color cor) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        // No BoxDecoration o nome CORRETO é 'border'
        border: Border.all(color: cor.withOpacity(0.2))
      ),
      child: Column(
        children: [
          Text(valor, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cor)), 
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey))
        ]
      ),
    ),
  );

  Color _getCor(TipoBatida t) {
    if (t == TipoBatida.entrada || t == TipoBatida.retornoAlmoco) return Colors.green;
    return Colors.orange;
  }

  IconData _getIcon(TipoBatida t) {
    if (t == TipoBatida.entrada) return Icons.login;
    if (t == TipoBatida.saida) return Icons.logout;
    return Icons.timer_outlined;
  }
}