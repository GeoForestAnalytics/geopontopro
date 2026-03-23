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
  final _nomeCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _senhaCtrl    = TextEditingController();
  final _cargoCtrl    = TextEditingController();
  final _empresaCtrl  = TextEditingController();
  String? _erro;

  @override
  void dispose() {
    _nomeCtrl.dispose(); _emailCtrl.dispose(); _senhaCtrl.dispose();
    _cargoCtrl.dispose(); _empresaCtrl.dispose();
    super.dispose();
  }

  Future<void> _criarFuncionario() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _criando = true; _erro = null; });
    try {
      await ref.read(authServiceProvider).criarFuncionario(
        nome: _nomeCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        senha: _senhaCtrl.text,
        cargo: _cargoCtrl.text.trim(),
        empresa: _empresaCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Funcionário ${_nomeCtrl.text} criado!'),
              backgroundColor: const Color(0xFF15803D),
              behavior: SnackBarBehavior.floating),
        );
        _nomeCtrl.clear(); _emailCtrl.clear(); _senhaCtrl.clear();
        _cargoCtrl.clear(); _empresaCtrl.clear();
      }
    } catch (e) {
      setState(() => _erro = e.toString());
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
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Novo Funcionário',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _campo('Nome completo', _nomeCtrl, Icons.person),
                const SizedBox(height: 12),
                _campo('Email', _emailCtrl, Icons.email,
                    keyboard: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _campo('Senha temporária', _senhaCtrl, Icons.lock,
                    obscure: true),
                const SizedBox(height: 12),
                _campo('Cargo', _cargoCtrl, Icons.badge),
                const SizedBox(height: 12),
                _campo('Empresa', _empresaCtrl, Icons.business),
                if (_erro != null) ...[
                  const SizedBox(height: 8),
                  Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _criando ? null : _criarFuncionario,
                    child: _criando
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Criar Funcionário'),
                  ),
                ),
              ],
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
        stream: PontoService().streamFuncionarios(),
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
                    children: [
                      Text('${lista.length} funcionário(s)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _abrirModal,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Adicionar'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        Text('Nenhum funcionário cadastrado',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final f = lista[i];
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
                              backgroundColor: const Color(0xFFDCFCE7),
                              child: Text((f['nome'] ?? '?')[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: Color(0xFF15803D), fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f['nome'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(f['cargo'] ?? '',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                  Text(f['email'] ?? '',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      );
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

  Widget _campo(String label, TextEditingController ctrl, IconData icon,
      {TextInputType keyboard = TextInputType.text, bool obscure = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF15803D), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
    );
  }
}
