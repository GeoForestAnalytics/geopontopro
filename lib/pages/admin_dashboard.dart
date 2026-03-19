import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importação Firebase
import 'package:cloud_firestore/cloud_firestore.dart'; // Importação Firestore
import 'login_page.dart';
import 'cadastro_funcionario_page.dart';
import 'monitoramento_page.dart';
import 'relatorio_pontos_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _funcionarios = [];
  bool _carregando = true; 
  String _nomeEmpresa = "Carregando..."; 

  @override
  void initState() {
    super.initState();
    _inicializarDashboard();
  }

  Future<void> _inicializarDashboard() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // 1. Busca os dados do gerente logado para saber qual a empresa
      final userDoc = await _firestore.collection('usuarios').doc(user.uid).get();

      if (userDoc.exists) {
        final dadosGerente = userDoc.data() as Map<String, dynamic>;
        final empresaNome = dadosGerente['empresa'] ?? "Minha Empresa";

        // 2. Busca todos os usuários que pertencem à mesma empresa e são colaboradores
        final querySnapshot = await _firestore
            .collection('usuarios')
            .where('empresa', isEqualTo: empresaNome)
            .where('cargo', isEqualTo: 'colaborador') // Filtra para não mostrar o próprio gerente na lista
            .get();

        if (mounted) {
          setState(() {
            _nomeEmpresa = empresaNome;
            // Converte os documentos para uma lista de Maps
            _funcionarios = querySnapshot.docs.map((doc) => doc.data()).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Erro ao carregar dashboard: $e");
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _sair() async {
    await _auth.signOut();
    if (!mounted) return;
    // O AuthWrapper no main.dart já perceberia a saída, mas forçamos para garantir
    Navigator.pushAndRemoveUntil(
      context, 
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_nomeEmpresa.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(onPressed: _sair, icon: const Icon(Icons.logout))
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _inicializarDashboard,
        color: Colors.green[800],
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // CABEÇALHO COM AÇÕES RÁPIDAS
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green[800],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildQuickActionCard(context, 'Monitorar Mapa', Icons.map_outlined, () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const MonitoramentoPage()));
                          }),
                          _buildQuickActionCard(context, 'Histórico Pontos', Icons.assignment_outlined, () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const RelatorioPontosPage()));
                          }),
                          _buildQuickActionCard(context, 'Adicionar Membro', Icons.person_add_alt_1_outlined, () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (context) => const CadastroFuncionarioPage()));
                            _inicializarDashboard(); // Atualiza a lista ao voltar
                          }),
                        ],
                      ),
                    ),
                  ),

                  // TÍTULO DA LISTA
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 30, 20, 10),
                      child: Text(
                        'Equipe de Colaboradores', 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
                      ),
                    ),
                  ),

                  // LISTA DE FUNCIONÁRIOS
                  _funcionarios.isEmpty 
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Text("Nenhum colaborador cadastrado.", style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final f = _funcionarios[index];
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey[200]!)
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green[50],
                                  child: Icon(Icons.person, color: Colors.green[700]),
                                ),
                                title: Text(f['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(f['email'] ?? ''),
                                trailing: const Icon(Icons.chevron_right, size: 18),
                                onTap: () {
                                  // Ver detalhes ou histórico individual
                                },
                              ),
                            );
                          },
                          childCount: _funcionarios.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 30)),
                ],
              ),
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: (MediaQuery.of(context).size.width / 3) - 22,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(
              title, 
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: Colors.white)
            ),
          ],
        ),
      ),
    );
  }
}