// ============================================================
// pages/admin_funcionarios_page.dart  (ATUALIZADO)
// ============================================================
// Substitui o arquivo anterior. Agora o gerente escolhe o
// perfil (Colaborador ou Gerente) ao criar um novo usuário.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/ponto_service.dart';

class AdminFuncionariosPage extends ConsumerStatefulWidget {
  const AdminFuncionariosPage({super.key});
  @override
  ConsumerState<AdminFuncionariosPage> createState() =>
      _AdminFuncionariosPageState();
}

class _AdminFuncionariosPageState
    extends ConsumerState<AdminFuncionariosPage> {
  bool _criando = false;
  final _formKey     = GlobalKey<FormState>();
  final _nomeCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _senhaCtrl   = TextEditingController();
  final _cargoCtrl   = TextEditingController();
  final _empresaCtrl = TextEditingController();
  bool _novoEhGerente = false; // perfil do novo usuário
  String? _erro;

  @override
  void dispose() {
    _nomeCtrl.dispose();  _emailCtrl.dispose(); _senhaCtrl.dispose();
    _cargoCtrl.dispose(); _empresaCtrl.dispose();
    super.dispose();
  }

  Future<void> _criarUsuario() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _criando = true; _erro = null; });
    try {
      await ref.read(authServiceProvider).criarUsuario(
        nome:      _nomeCtrl.text.trim(),
        email:     _emailCtrl.text.trim(),
        senha:     _senhaCtrl.text,
        cargo:     _cargoCtrl.text.trim(),
        empresa:   _empresaCtrl.text.trim(),
        isGerente: _novoEhGerente,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${_nomeCtrl.text} criado como '
              '${_novoEhGerente ? 'Gerente' : 'Colaborador'}!'),
          backgroundColor: const Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        _nomeCtrl.clear(); _emailCtrl.clear(); _senhaCtrl.clear();
        _cargoCtrl.clear(); _empresaCtrl.clear();
        setState(() => _novoEhGerente = false);
      }
    } catch (e) {
      String msg = 'Erro ao criar usuário.';
      if (e.toString().contains('email-already-in-use'))
        msg = 'Este email já está cadastrado.';
      setState(() => _erro = msg);
    } finally {
      if (mounted) setState(() => _criando = false);
    }
  }

  void _abrirModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Novo usuário',
                            style: TextStyle(fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Seletor de perfil ──────────────────────────
                  const Text('PERFIL', style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w600, color: Colors.grey,
                      letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _perfilCard(
                          setModal: setModal,
                          selecionado: !_novoEhGerente,
                          icone: Icons.person,
                          titulo: 'Colaborador',
                          descricao: 'Registra o próprio ponto',
                          cor: const Color(0xFF3B82F6),
                          onTap: () => setModal(() => _novoEhGerente = false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _perfilCard(
                          setModal: setModal,
                          selecionado: _novoEhGerente,
                          icone: Icons.admin_panel_settings,
                          titulo: 'Gerente',
                          descricao: 'Visualiza todos os registros',
                          cor: const Color(0xFF8B5CF6),
                          onTap: () => setModal(() => _novoEhGerente = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Campos ────────────────────────────────────
                  _campo('Nome completo', _nomeCtrl, Icons.badge_outlined),
                  const SizedBox(height: 12),
                  _campo('Email', _emailCtrl, Icons.email_outlined,
                      keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _campo('Senha temporária', _senhaCtrl, Icons.lock_outline,
                      obscure: true),
                  const SizedBox(height: 12),
                  _campo('Cargo', _cargoCtrl, Icons.work_outline),
                  const SizedBox(height: 12),
                  _campo('Empresa', _empresaCtrl, Icons.apartment_outlined),

                  if (_erro != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 16),
                        const SizedBox(width: 6),
                        Text(_erro!, style: TextStyle(color: Colors.red[700], fontSize: 12)),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _criando ? null : _criarUsuario,
                      icon: _criando
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Icon(_novoEhGerente
                              ? Icons.admin_panel_settings
                              : Icons.person_add),
                      label: Text(
                        _criando
                            ? 'Criando...'
                            : 'Criar ${_novoEhGerente ? 'Gerente' : 'Colaborador'}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _novoEhGerente
                            ? const Color(0xFF8B5CF6)
                            : const Color(0xFF15803D),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: PontoService().streamTodosUsuarios(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snapshot.data ?? [];
          final gerentes     = lista.where((u) => u['isAdmin'] == true).toList();
          final colaboradores = lista.where((u) => u['isAdmin'] != true).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${lista.length} usuário(s)',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(
                            '${gerentes.length} gerente(s)  •  '
                            '${colaboradores.length} colaborador(es)',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _abrirModal,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Adicionar'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (lista.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Nenhum usuário cadastrado',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final u = lista[i];
                      final isGerente = u['isAdmin'] == true;
                      return _usuarioCard(u, isGerente);
                    },
                    childCount: lista.length,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _usuarioCard(Map<String, dynamic> u, bool isGerente) {
    final cor  = isGerente ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6);
    final bgCor = isGerente ? const Color(0xFFF5F3FF) : const Color(0xFFEFF6FF);
    final nome  = (u['nome'] ?? '?') as String;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: bgCor,
            child: Text(nome[0].toUpperCase(),
                style: TextStyle(color: cor, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(u['cargo'] ?? '',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                Text(u['email'] ?? '',
                    style: TextStyle(color: Colors.grey[400], fontSize: 11)),
              ],
            ),
          ),
          // Badge de perfil
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bgCor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isGerente ? Icons.admin_panel_settings : Icons.person,
                  size: 13, color: cor,
                ),
                const SizedBox(width: 4),
                Text(
                  isGerente ? 'Gerente' : 'Colaborador',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold, color: cor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _perfilCard({
    required StateSetter setModal,
    required bool selecionado,
    required IconData icone,
    required String titulo,
    required String descricao,
    required Color cor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selecionado ? cor.withOpacity(0.08) : Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selecionado ? cor : Colors.grey[300]!,
            width: selecionado ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icone, color: selecionado ? cor : Colors.grey, size: 28),
            const SizedBox(height: 6),
            Text(titulo,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selecionado ? cor : Colors.grey[700])),
            const SizedBox(height: 2),
            Text(descricao,
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _campo(String label, TextEditingController ctrl, IconData icon,
      {TextInputType keyboard = TextInputType.text, bool obscure = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF15803D)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF15803D), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
    );
  }
}
