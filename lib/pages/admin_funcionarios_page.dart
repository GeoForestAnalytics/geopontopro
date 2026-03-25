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
  // Controladores
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _cargoCtrl = TextEditingController();
  bool _novoEhGerente = false;
  bool _loading = false;
  String? _erro;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _cargoCtrl.dispose();
    super.dispose();
  }

  // Lógica de criação usando os novos campos empresaId e empresaNome
  Future<void> _processarCriacao(String empresaId, String empresaNome) async {
    if (_nomeCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _senhaCtrl.text.length < 6) {
      setState(() => _erro = "Preencha os campos (Senha mín. 6 chars)");
      return;
    }

    setState(() { _loading = true; _erro = null; });
    
    try {
      // CORREÇÃO: Usando o método correto 'criarUsuarioEquipe' do seu AuthService
      await ref.read(authServiceProvider).criarUsuarioEquipe(
        nome: _nomeCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        senha: _senhaCtrl.text,
        cargo: _cargoCtrl.text.trim(),
        empresaId: empresaId,     // <--- Passando o ID
        empresaNome: empresaNome, // <--- Passando o Nome
        isGerente: _novoEhGerente,
      );

      if (mounted) {
        _nomeCtrl.clear();
        _emailCtrl.clear();
        _senhaCtrl.clear();
        _cargoCtrl.clear();
        Navigator.pop(context); 
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Colaborador criado com sucesso!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) setState(() => _erro = "Erro: e-mail já existe ou falha na conexão.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pegamos o perfil do Admin logado
    final admin = ref.watch(userProfileProvider).value;
    if (admin == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      floatingActionButton: FloatingActionButton(
        // CORREÇÃO: Passando os dados da empresa do admin
        onPressed: () => _abrirModal(admin.empresaId, admin.empresaNome),
        child: const Icon(Icons.person_add),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // CORREÇÃO: Buscando usuários pelo empresaId
        stream: PontoService().streamTodosUsuarios(admin.empresaId),
        builder: (context, snapshot) {
          final lista = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (lista.isEmpty) return const Center(child: Text("Nenhum membro na equipe."));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lista.length,
            itemBuilder: (ctx, i) {
              final u = lista[i];
              final isGer = u['isAdmin'] == true;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isGer ? Colors.purple[100] : Colors.blue[100], 
                    child: Icon(isGer ? Icons.admin_panel_settings : Icons.person, color: isGer ? Colors.purple : Colors.blue)
                  ),
                  title: Text(u['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(u['cargo'] ?? 'Colaborador'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _abrirModal(String empresaId, String empresaNome) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Novo Colaborador', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _perfilCard(selecionado: !_novoEhGerente, titulo: 'Colaborador', icone: Icons.person, cor: Colors.blue, 
                    onTap: () { setModalState(() => _novoEhGerente = false); setState(() { _novoEhGerente = false; }); })),
                  const SizedBox(width: 12),
                  Expanded(child: _perfilCard(selecionado: _novoEhGerente, titulo: 'Gerente', icone: Icons.admin_panel_settings, cor: Colors.purple, 
                    onTap: () { setModalState(() => _novoEhGerente = true); setState(() { _novoEhGerente = true; }); })),
                ],
              ),
              const SizedBox(height: 20),
              TextField(controller: _nomeCtrl, decoration: const InputDecoration(labelText: 'Nome Completo')),
              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'E-mail')),
              TextField(controller: _senhaCtrl, decoration: const InputDecoration(labelText: 'Senha')),
              TextField(controller: _cargoCtrl, decoration: const InputDecoration(labelText: 'Cargo')),
              if (_erro != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 12))),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : () => _processarCriacao(empresaId, empresaNome),
                  child: _loading ? const CircularProgressIndicator() : const Text('CRIAR ACESSO'),
                ),
              ),
            ],
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
        decoration: BoxDecoration(color: selecionado ? cor.withOpacity(0.1) : Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: selecionado ? cor : Colors.grey[300]!, width: 2)),
        child: Column(children: [Icon(icone, color: selecionado ? cor : Colors.grey), Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: selecionado ? cor : Colors.grey))]),
      ),
    );
  }
}