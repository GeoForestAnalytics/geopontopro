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
  final _cargoCtrl   = TextEditingController();
  final _empresaCtrl = TextEditingController();

  bool _loading = false;
  bool _senhaVisivel = false;
  bool _confirmaVisivel = false;
  String? _erro;

  // Cálculo de força da senha
  double get _forcaSenha {
    final s = _senhaCtrl.text;
    if (s.isEmpty) return 0;
    double score = 0;
    if (s.length >= 6)  score += 0.25;
    if (s.length >= 10) score += 0.25;
    if (s.contains(RegExp(r'[A-Z]'))) score += 0.25;
    if (s.contains(RegExp(r'[0-9!@#\$%&*]'))) score += 0.25;
    return score;
  }

  Color get _corForca {
    final f = _forcaSenha;
    if (f <= 0.25) return Colors.red;
    if (f <= 0.50) return Colors.orange;
    if (f <= 0.75) return Colors.amber;
    return const Color(0xFF15803D);
  }

  String get _labelForca {
    final f = _forcaSenha;
    if (f <= 0.25) return 'Fraca';
    if (f <= 0.50) return 'Regular';
    if (f <= 0.75) return 'Boa';
    return 'Forte';
  }

  @override
  void dispose() {
    _nomeCtrl.dispose(); 
    _emailCtrl.dispose(); 
    _senhaCtrl.dispose();
    _confirmaCtrl.dispose(); 
    _cargoCtrl.dispose(); 
    _empresaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() { 
      _loading = true; 
      _erro = null; 
    });

    try {
      // Chama o método unificado no AuthService
      await ref.read(authServiceProvider).criarUsuario(
        nome:    _nomeCtrl.text.trim(),
        email:   _emailCtrl.text.trim(),
        senha:   _senhaCtrl.text,
        cargo:   _cargoCtrl.text.trim(),
        empresa: _empresaCtrl.text.trim(),
        isGerente: true, // Cadastro público sempre cria um Gerente Master
      );
      
      // Nota: O AuthWrapper no main.dart cuidará de mudar a tela automaticamente
    } catch (e) {
      String msg = 'Erro ao criar conta. Tente novamente.';
      if (e.toString().contains('email-already-in-use')) {
        msg = 'Este email já está cadastrado.';
      } else if (e.toString().contains('weak-password')) {
        msg = 'Senha muito fraca. Use ao menos 6 caracteres.';
      } else if (e.toString().contains('invalid-email')) {
        msg = 'Email inválido.';
      }
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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text('Criar conta master',
                        style: TextStyle(color: Colors.white, fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_add, color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Card principal
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
                        const Text('Seus dados',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Preencha para configurar sua empresa no GeoPonto',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        const SizedBox(height: 24),

                        _secaoLabel('DADOS PESSOAIS', Icons.person_outline),
                        const SizedBox(height: 10),
                        _campo(
                          ctrl: _nomeCtrl,
                          label: 'Nome completo',
                          icon: Icons.badge_outlined,
                          validator: (v) => v!.trim().split(' ').length < 2
                              ? 'Informe nome e sobrenome'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _campo(
                          ctrl: _emailCtrl,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboard: TextInputType.emailAddress,
                          validator: (v) =>
                              v!.contains('@') ? null : 'Email inválido',
                        ),
                        const SizedBox(height: 24),

                        _secaoLabel('DADOS PROFISSIONAIS', Icons.business_outlined),
                        const SizedBox(height: 10),
                        _campo(
                          ctrl: _cargoCtrl,
                          label: 'Seu Cargo',
                          icon: Icons.work_outline,
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Informe seu cargo' : null,
                        ),
                        const SizedBox(height: 14),
                        _campo(
                          ctrl: _empresaCtrl,
                          label: 'Nome da Empresa',
                          icon: Icons.apartment_outlined,
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Informe a empresa' : null,
                        ),
                        const SizedBox(height: 24),

                        _secaoLabel('SEGURANÇA', Icons.lock_outline),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _senhaCtrl,
                          obscureText: !_senhaVisivel,
                          onChanged: (_) => setState(() {}),
                          decoration: _inputDeco('Senha', Icons.lock_outline).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(_senhaVisivel ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                            ),
                          ),
                          validator: (v) => v!.length >= 6 ? null : 'Mínimo 6 caracteres',
                        ),
                        if (_senhaCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _forcaSenha,
                                    backgroundColor: Colors.grey[200],
                                    color: _corForca,
                                    minHeight: 5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(_labelForca, style: TextStyle(color: _corForca, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmaCtrl,
                          obscureText: !_confirmaVisivel,
                          decoration: _inputDeco('Confirmar senha', Icons.lock_outline).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(_confirmaVisivel ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _confirmaVisivel = !_confirmaVisivel),
                            ),
                          ),
                          validator: (v) => v == _senhaCtrl.text ? null : 'As senhas não coincidem',
                        ),

                        if (_erro != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                          ),
                        ],

                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _cadastrar,
                            child: _loading 
                              ? const SizedBox(
                                  height: 20, width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                              : const Text('CRIAR CONTA E ACESSAR', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Já tenho conta? Entrar', style: TextStyle(color: Color(0xFF15803D))),
                          ),
                        ),
                        const SizedBox(height: 20),
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

  Widget _secaoLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500])),
      ],
    );
  }

  Widget _campo({required TextEditingController ctrl, required String label, required IconData icon, TextInputType keyboard = TextInputType.text, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: _inputDeco(label, icon),
      validator: validator,
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF15803D), size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      );
}