import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/ponto_service.dart';
import '../services/export_service.dart'; // <--- IMPORTADO
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
        stream: ref.watch(pontoServiceProvider).streamTodosUsuarios(admin.empresaId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final lista = snapshot.data ?? [];
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
    final user = UserModel(
      uid: u['uid'], 
      nome: u['nome'] ?? '', 
      email: u['email'] ?? '', 
      cargo: u['cargo'] ?? '', 
      empresaId: u['empresaId'] ?? '',
      empresaNome: u['empresaNome'] ?? '',
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

            // 1. NOVA OPÇÃO: EXPORTAR PLANILHA
            _itemMenu(
              context,
              label: 'Exportar Planilha (Excel/CSV)',
              icon: Icons.table_chart,
              cor: Colors.green,
              onTap: () async {
                // Feedback visual de carregamento
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gerando planilha... aguarde.')),
                );

                final service = PontoService();
                final pontos = await service.obterPontosMes(
                  user.uid, 
                  DateTime.now().month, 
                  DateTime.now().year
                );
                
                await ExportService().exportarPontosCSV(user, pontos);
              },
            ),

            // 2. OPÇÃO EXISTENTE: HISTÓRICO
            _itemMenu(
              context,
              label: 'Espelho de Ponto (Lista)',
              icon: Icons.history,
              cor: Colors.blue,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoricoPage(user: user))),
            ),

            // 3. OPÇÃO EXISTENTE: MAPA
            _itemMenu(
              context,
              label: 'Mapa de Trajeto GPS',
              icon: Icons.map_outlined,
              cor: Colors.orange,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapaPontosPage(user: user))),
            ),

            // 4. OPÇÃO EXISTENTE: BANCO DE HORAS
            _itemMenu(
              context,
              label: 'Cálculo de Banco de Horas',
              icon: Icons.access_time,
              cor: Colors.teal,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BancoHorasPage(user: user))),
            ),

            // 5. OPÇÃO EXISTENTE: PDF
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
        Navigator.pop(context); // Fecha o modal
        onTap(); // Executa a ação
      },
    );
  }
}