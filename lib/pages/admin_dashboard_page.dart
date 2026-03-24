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
        if (admin == null) return const Scaffold(body: Center(child: Text('Erro de acesso')));

        return Scaffold(
          backgroundColor: const Color(0xFFF0FDF4),
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Painel Gerencial', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(admin.empresa, style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout), 
                onPressed: () => ref.read(authServiceProvider).logout()
              )
            ],
          ),
          body: IndexedStack(
            index: _tabIndex,
            children: [
              _TabMonitoramento(admin: admin), // Tela de monitoramento
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

class _TabMonitoramento extends ConsumerWidget {
  final UserModel admin;
  const _TabMonitoramento({required this.admin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Usamos o provider em vez de criar um novo PontoService() para evitar o piscar
    final pontoService = ref.watch(pontoServiceProvider);
    final now = DateTime.now();

    return StreamBuilder<List<PontoModel>>(
      stream: pontoService.streamTodosPontosHoje(admin.empresa),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final pontos = snapshot.data ?? [];
        final equipeAtiva = pontos.map((p) => p.usuarioId).toSet().length;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(now).toUpperCase(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        _cardResumo('Total de Batidas', '${pontos.length}', Colors.green),
                        const SizedBox(width: 10),
                        _cardResumo('Colaboradores', '$equipeAtiva', Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 25),
                    const Text('Atividade Recente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _cardResumo(String label, String valor, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cor.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(valor, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cor)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

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