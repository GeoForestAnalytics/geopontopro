import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  bool _loading = false;
  bool _senhaVisivel = false;
  String? _erro;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _erro = null; });
    try {
      await ref.read(authServiceProvider).login(_emailCtrl.text.trim(), _senhaCtrl.text);
    } catch (e) {
      setState(() => _erro = 'Email ou senha incorretos.');
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
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.location_on, size: 44, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text('GeoPonto Pro',
                        style: TextStyle(color: Colors.white, fontSize: 32,
                            fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                    const SizedBox(height: 6),
                    Text('Registro de ponto inteligente',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15)),
                  ],
                ),
              ),
            ),

            // Card de login
            Expanded(
              flex: 3,
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
                        const SizedBox(height: 8),
                        const Text('Entrar', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Acesse sua conta para registrar o ponto',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        const SizedBox(height: 28),

                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDeco('Email', Icons.email_outlined),
                          validator: (v) => v!.contains('@') ? null : 'Email inválido',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _senhaCtrl,
                          obscureText: !_senhaVisivel,
                          decoration: _inputDeco('Senha', Icons.lock_outline).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(_senhaVisivel ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                            ),
                          ),
                          validator: (v) => v!.length >= 6 ? null : 'Mínimo 6 caracteres',
                        ),

                        if (_erro != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red[700], size: 18),
                                const SizedBox(width: 8),
                                Text(_erro!, style: TextStyle(color: Colors.red[700], fontSize: 13)),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const SizedBox(height: 20, width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: const Color(0xFF15803D)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF15803D), width: 2),
    ),
    filled: true,
    fillColor: Colors.grey[50],
  );
}
