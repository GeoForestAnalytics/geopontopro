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
    // Obtém os dados do administrador logado
    final admin = ref.watch(userProfileProvider).value;
    if (admin == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // CORREÇÃO: Agora passa o 'empresaId' para filtrar apenas colaboradores da mesma empresa
        stream: ref.watch(pontoServiceProvider).streamTodosUsuarios(admin.empresaId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final lista = snapshot.data ?? [];
          // Filtra para não mostrar o próprio admin na lista de relatórios
          final colaboradores = lista.where((u) => u['uid'] != admin.uid).toList();

          if (colaboradores.isEmpty) {
            return const Center(child: Text("Nenhum colaborador cadastrado."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: colaboradores.length,
            itemBuilder: (ctx, i) {
              final u = colaboradores[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: Text(
                      (u['nome'] ?? 'C')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(u['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(u['cargo'] ?? 'Colaborador'),
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
    // CORREÇÃO: Instanciando o UserModel com os novos campos empresaId e empresaNome
    final user = UserModel(
      uid: u['uid'], 
      nome: u['nome'] ?? '', 
      email: u['email'] ?? '', 
      cargo: u['cargo'] ?? '', 
      empresaId: u['empresaId'] ?? '',     // <--- NOVO
      empresaNome: u['empresaNome'] ?? '', // <--- NOVO
      isAdmin: u['isAdmin'] ?? false, 
      criadoEm: DateTime.now(),
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.nome, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('${user.cargo} • ${user.email}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 20),
            const Divider(),
            const Text(
              'RELATÓRIOS DISPONÍVEIS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            _itemMenu(
              context,
              label: 'Espelho de Ponto (Lista)',
              icon: Icons.history,
              cor: Colors.blue,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoricoPage(user: user))),
            ),
            _itemMenu(
              context,
              label: 'Mapa de Trajeto GPS',
              icon: Icons.map_outlined,
              cor: Colors.orange,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapaPontosPage(user: user))),
            ),
            _itemMenu(
              context,
              label: 'Cálculo de Banco de Horas',
              icon: Icons.access_time,
              cor: Colors.teal,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BancoHorasPage(user: user))),
            ),
            _itemMenu(
              context,
              label: 'Gerar Documento PDF',
              icon: Icons.picture_as_pdf,
              cor: Colors.red,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EspelhoPontoPage(user: user, mes: DateTime.now().month, ano: DateTime.now().year))),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _itemMenu(BuildContext context, {required String label, required IconData icon, required Color cor, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: cor, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () {
        Navigator.pop(context); // Fecha o menu lateral/inferior
        onTap(); // Abre a página escolhida
      },
    );
  }
}