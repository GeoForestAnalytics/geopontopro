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

  void _abrirOpcoesColaborador(BuildContext context, Map<String, dynamic> userData) {
    // Convertemos os dados do Map para o objeto UserModel
    final colaborador = UserModel(
      uid: userData['uid'],
      nome: userData['nome'],
      email: userData['email'],
      cargo: userData['cargo'],
      empresa: userData['empresa'],
      isAdmin: userData['isAdmin'] ?? false,
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
            Text(
              colaborador.nome,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              '${colaborador.cargo} • ${colaborador.email}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
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
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoricoPage(user: colaborador))),
            ),
            _itemMenu(
              context,
              label: 'Mapa de Trajeto GPS',
              icon: Icons.map_outlined,
              cor: Colors.orange,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapaPontosPage(user: colaborador))),
            ),
            _itemMenu(
              context,
              label: 'Cálculo de Banco de Horas',
              icon: Icons.access_time,
              cor: Colors.teal,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BancoHorasPage(user: colaborador))),
            ),
            _itemMenu(
              context,
              label: 'Gerar Documento PDF',
              icon: Icons.picture_as_pdf,
              cor: Colors.red,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EspelhoPontoPage(user: colaborador, mes: DateTime.now().month, ano: DateTime.now().year))),
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
        Navigator.pop(context); // Fecha o menu
        onTap(); // Abre a página escolhida
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pega os dados do Gerente para saber a empresa
    final admin = ref.watch(userProfileProvider).value;
    if (admin == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Portal de Relatórios',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Selecione um colaborador da ${admin.empresa} para gerenciar os dados.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              // Filtra usuários da mesma empresa do gerente
              stream: PontoService().streamTodosUsuarios(admin.empresa),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final lista = snapshot.data ?? [];
                // Filtra para não mostrar o próprio gerente na lista de relatórios
                final colaboradores = lista.where((u) => u['uid'] != admin.uid).toList();

                if (colaboradores.isEmpty) {
                  return const Center(child: Text('Nenhum colaborador cadastrado.'));
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[100],
                          child: Text(u['nome'][0].toUpperCase(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(u['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(u['cargo'] ?? 'Colaborador'),
                        trailing: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bar_chart, color: Colors.green),
                            Text('VER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                        onTap: () => _abrirOpcoesColaborador(context, u),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}