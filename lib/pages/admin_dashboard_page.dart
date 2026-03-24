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
        if (admin == null) return const Scaffold(body: Center(child: Text('Erro')));

        return Scaffold(
          backgroundColor: const Color(0xFFF0FDF4),
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('GeoPonto Pro — Painel Gerencial', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(admin.empresa, style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
            actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => ref.read(authServiceProvider).logout())],
          ),
          body: IndexedStack(
            index: _tabIndex,
            children: [
              _TabPontoHoje(admin: admin),
              const AdminFuncionariosPage(),
              const AdminRelatorioPage(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (i) => setState(() => _tabIndex = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.today), label: 'Hoje'),
              NavigationDestination(icon: Icon(Icons.people), label: 'Equipe'),
              NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Relatórios'),
            ],
          ),
        );
      },
    );
  }
}

class _TabPontoHoje extends StatelessWidget {
  final UserModel admin;
  const _TabPontoHoje({required this.admin});

  @override
  Widget build(BuildContext context) {
    final service = PontoService();
    return StreamBuilder<List<PontoModel>>(
      stream: service.streamTodosPontosHoje(admin.empresa),
      builder: (context, snapshot) {
        final pontos = snapshot.data ?? [];
        if (pontos.isEmpty) return const Center(child: Text('Nenhuma atividade hoje.'));
        
        return ListView.builder(
          itemCount: pontos.length,
          itemBuilder: (ctx, i) {
            final p = pontos[i];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: Icon(Icons.circle, color: p.tipo == TipoBatida.entrada ? Colors.green : Colors.red, size: 12),
                title: Text(p.usuarioNome),
                subtitle: Text('${p.tipo.label} às ${DateFormat('HH:mm').format(p.timestamp)}'),
                trailing: const Icon(Icons.gps_fixed, size: 14, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }
}