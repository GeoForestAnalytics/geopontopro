import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/ponto_service.dart';

class AdminFuncionariosPage extends ConsumerStatefulWidget {
  const AdminFuncionariosPage({super.key});
  @override
  ConsumerState<AdminFuncionariosPage> createState() => _AdminFuncionariosPageState();
}

class _AdminFuncionariosPageState extends ConsumerState<AdminFuncionariosPage> {
  bool _criando = false;
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _cargoCtrl = TextEditingController();
  bool _novoEhGerente = false;
  String? _erro;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _cargoCtrl.dispose();
    super.dispose();
  }

  // Lógica para criar usuário passando a empresa do Admin logado
  Future<void> _criarUsuario(String empresaAdmin) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _criando = true; _erro = null; });
    try {
      await ref.read(authServiceProvider).criarUsuario(
        nome: _nomeCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        senha: _senhaCtrl.text,
        cargo: _cargoCtrl.text.trim(),
        empresa: empresaAdmin, // Vincula automaticamente à mesma empresa
        isGerente: _novoEhGerente,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário criado com sucesso!'), backgroundColor: Colors.green),
        );
        _nomeCtrl.clear(); _emailCtrl.clear(); _senhaCtrl.clear(); _cargoCtrl.clear();
      }
    } catch (e) {
      setState(() => _erro = "Erro: E-mail já existe ou senha fraca.");
    } finally {
      if (mounted) setState(() => _criando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pegamos o perfil do Admin logado para saber a empresa dele
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar perfil: $e')),
      data: (admin) {
        if (admin == null) return const Center(child: Text('Admin não encontrado'));

        return Scaffold(
          backgroundColor: const Color(0xFFF0FDF4),
          body: StreamBuilder<List<Map<String, dynamic>>>(
            // CORREÇÃO DO ERRO: Passamos admin.empresa como argumento
            stream: PontoService().streamTodosUsuarios(admin.empresa),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final lista = snapshot.data ?? [];

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${lista.length} Colaboradores', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text(admin.empresa, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _abrirModal(admin.empresa),
                            icon: const Icon(Icons.add),
                            label: const Text('Novo'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  lista.isEmpty
                      ? const SliverFillRemaining(child: Center(child: Text('Nenhum funcionário cadastrado.')))
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) {
                                final u = lista[i];
                                final bool isGer = u['isAdmin'] == true;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isGer ? Colors.purple[50] : Colors.blue[50],
                                      child: Icon(isGer ? Icons.admin_panel_settings : Icons.person, color: isGer ? Colors.purple : Colors.blue),
                                    ),
                                    title: Text(u['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(u['cargo']),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isGer ? Colors.purple[100] : Colors.blue[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(isGer ? 'GERENTE' : 'COLABORADOR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isGer ? Colors.purple[900] : Colors.blue[900])),
                                    ),
                                  ),
                                );
                              },
                              childCount: lista.length,
                            ),
                          ),
                        ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _abrirModal(String empresaAdmin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Cadastrar na Equipe', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  // Seletor de Perfil
                  Row(
                    children: [
                      Expanded(
                        child: _perfilCard(
                          selecionado: !_novoEhGerente,
                          titulo: 'Colaborador',
                          icone: Icons.person,
                          cor: Colors.blue,
                          onTap: () => setModal(() => _novoEhGerente = false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _perfilCard(
                          selecionado: _novoEhGerente,
                          titulo: 'Gerente',
                          icone: Icons.admin_panel_settings,
                          cor: Colors.purple,
                          onTap: () => setModal(() => _novoEhGerente = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _campo(_nomeCtrl, 'Nome Completo', Icons.badge_outlined),
                  const SizedBox(height: 12),
                  _campo(_emailCtrl, 'E-mail de Acesso', Icons.email_outlined, keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _campo(_senhaCtrl, 'Senha Temporária', Icons.lock_outline, obscure: true),
                  const SizedBox(height: 12),
                  _campo(_cargoCtrl, 'Cargo/Função', Icons.work_outline),
                  if (_erro != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _criando ? null : () => _criarUsuario(empresaAdmin),
                      child: _criando ? const CircularProgressIndicator(color: Colors.white) : const Text('CONCLUIR CADASTRO'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _perfilCard({required bool selecionado, required String titulo, required IconData icone, required Color cor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selecionado ? cor.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selecionado ? cor : Colors.grey[300]!, width: 2),
        ),
        child: Column(
          children: [
            Icon(icone, color: selecionado ? cor : Colors.grey),
            const SizedBox(height: 4),
            Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: selecionado ? cor : Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label, IconData icon, {bool obscure = false, TextInputType keyboard = TextInputType.text}) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
    );
  }
}