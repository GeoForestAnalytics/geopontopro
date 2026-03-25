import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class CadastroPage extends ConsumerStatefulWidget {
  const CadastroPage({super.key});
  @override
  ConsumerState<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends ConsumerState<CadastroPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _senhaCtrl    = TextEditingController();
  final _confirmaCtrl = TextEditingController();
  final _cnpjCtrl    = TextEditingController(); // <--- NOVO
  final _empresaCtrl = TextEditingController();

  bool _loading = false;
  bool _senhaVisivel = false;
  String? _erro;

  @override
  void dispose() {
    _nomeCtrl.dispose(); _emailCtrl.dispose(); _senhaCtrl.dispose();
    _confirmaCtrl.dispose(); _cnpjCtrl.dispose(); _empresaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() { 
      _loading = true; 
      _erro = null; 
    });

    try {
      // CORREÇÃO: Chamando o método de registro de empresa SaaS
      await ref.read(authServiceProvider).registrarNovaEmpresa(
        nomeAdmin:   _nomeCtrl.text.trim(),
        email:       _emailCtrl.text.trim(),
        senha:       _senhaCtrl.text,
        nomeEmpresa: _empresaCtrl.text.trim(),
        cnpj:        _cnpjCtrl.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Empresa e Admin cadastrados com sucesso!')),
        );
      }
    } catch (e) {
      String msg = 'Erro ao criar conta. Verifique os dados.';
      if (e.toString().contains('email-already-in-use')) msg = 'E-mail já cadastrado.';
      setState(() => _erro = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF15803D),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('Nova Empresa',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Configuração Master',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Cadastre sua empresa e crie o acesso de administrador',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        const SizedBox(height: 24),

                        _campo(_empresaCtrl, 'Nome da Empresa', Icons.business),
                        const SizedBox(height: 12),
                        _campo(_cnpjCtrl, 'CNPJ (apenas números)', Icons.description, keyboard: TextInputType.number),
                        
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Divider(),
                        ),

                        _campo(_nomeCtrl, 'Seu Nome Completo', Icons.person_outline),
                        const SizedBox(height: 12),
                        _campo(_emailCtrl, 'E-mail de Acesso', Icons.email_outlined, keyboard: TextInputType.emailAddress),
                        const SizedBox(height: 12),
                        
                        TextFormField(
                          controller: _senhaCtrl,
                          obscureText: !_senhaVisivel,
                          decoration: _inputDeco('Crie uma Senha', Icons.lock_outline).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(_senhaVisivel ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                            ),
                          ),
                          validator: (v) => v!.length >= 6 ? null : 'Mínimo 6 caracteres',
                        ),
                        
                        if (_erro != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_erro!, style: const TextStyle(color: Colors.red))),

                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _cadastrar,
                            child: _loading 
                              ? const CircularProgressIndicator(color: Colors.white) 
                              : const Text('FINALIZAR CADASTRO MASTER', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label, IconData icon, {TextInputType keyboard = TextInputType.text}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: _inputDeco(label, icon),
      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF15803D), size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      );
}