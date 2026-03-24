import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/ponto_service.dart';
import 'historico_page.dart';
import 'mapa_pontos_page.dart';
import 'banco_horas_page.dart';
import 'espelho_ponto_page.dart';

class AdminRelatorioPage extends ConsumerWidget {
  const AdminRelatorioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(userProfileProvider).value;
    if (admin == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // CORREÇÃO: Passando a empresa do Admin
        stream: ref.watch(pontoServiceProvider).streamTodosUsuarios(admin.empresa),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final lista = snapshot.data ?? [];
          final colaboradores = lista.where((u) => u['uid'] != admin.uid).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: colaboradores.length,
            itemBuilder: (ctx, i) {
              final u = colaboradores[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(u['nome'][0].toUpperCase())),
                  title: Text(u['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(u['cargo'] ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _abrirOpcoes(context, u),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _abrirOpcoes(BuildContext context, Map<String, dynamic> u) {
    final user = UserModel(uid: u['uid'], nome: u['nome'], email: u['email'], cargo: u['cargo'], empresa: u['empresa'], isAdmin: u['isAdmin'] ?? false, criadoEm: DateTime.now());

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(user.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            ListTile(leading: const Icon(Icons.history, color: Colors.blue), title: const Text('Histórico'), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => HistoricoPage(user: user))); }),
            ListTile(leading: const Icon(Icons.map, color: Colors.orange), title: const Text('Mapa'), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => MapaPontosPage(user: user))); }),
            ListTile(leading: const Icon(Icons.access_time, color: Colors.teal), title: const Text('Banco de Horas'), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => BancoHorasPage(user: user))); }),
            ListTile(leading: const Icon(Icons.picture_as_pdf, color: Colors.red), title: const Text('PDF'), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => EspelhoPontoPage(user: user, mes: DateTime.now().month, ano: DateTime.now().year))); }),
          ],
        ),
      ),
    );
  }
}