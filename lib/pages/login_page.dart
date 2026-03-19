import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importação do Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Importação do Firestore
import 'home_page.dart'; 
import 'admin_dashboard.dart'; 
import 'registro_empresa_page.dart'; 

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _estaCarregando = false;

  Future<void> _fazerLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _mostrarErro("Por favor, preencha e-mail e senha.");
      return;
    }

    setState(() => _estaCarregando = true);

    try {
      // 1. AUTENTICAÇÃO NO FIREBASE AUTH
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final User? user = userCredential.user;

      if (user != null) {
        // 2. BUSCA O CARGO E EMPRESA NO FIRESTORE (Substitui os Metadados do Supabase)
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .get();

        if (!mounted) return;

        if (userDoc.exists) {
          final dados = userDoc.data() as Map<String, dynamic>;
          final String cargo = dados['cargo'] ?? 'colaborador';
          final String empresa = dados['empresa'] ?? 'Geo Forest';

          debugPrint("LOGIN SUCESSO: ${user.email} | Cargo: $cargo | Empresa: $empresa");

          // 3. DIRECIONAMENTO DINÂMICO
          if (cargo == 'gerente') {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const AdminDashboard()),
              (route) => false,
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false,
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bem-vindo ao GeoPonto!'), backgroundColor: Colors.green),
          );
        } else {
          // Caso o usuário exista no Auth mas não no banco (erro de integridade)
          await FirebaseAuth.instance.signOut();
          _mostrarErro("Erro: Perfil não encontrado. Contate o administrador.");
        }
      }
    } on FirebaseAuthException catch (e) {
      // Tratamento de erros específicos do Firebase
      String mensagem = "Erro ao entrar.";
      if (e.code == 'user-not-found') mensagem = "E-mail não cadastrado.";
      if (e.code == 'wrong-password') mensagem = "Senha incorreta.";
      if (e.code == 'invalid-email') mensagem = "E-mail inválido.";
      if (e.code == 'user-disabled') mensagem = "Este usuário foi desativado.";
      
      _mostrarErro(mensagem);
    } catch (e) {
      _mostrarErro("Ocorreu um erro inesperado: $e");
    } finally {
      if (mounted) setState(() => _estaCarregando = false);
    }
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg), 
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mantive exatamente a mesma interface visual (UI) que você gosta
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_on, size: 60, color: Colors.green[700]),
              ),
              const SizedBox(height: 24),
              Text(
                'Geo Ponto Pro', 
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green[900])
              ),
              const SizedBox(height: 8),
              const Text('Acesse sua conta para registrar o ponto', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-mail', 
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Senha', 
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _estaCarregando ? null : _fazerLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700], 
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _estaCarregando 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text('ENTRAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistroEmpresaPage())),
                child: Text.rich(
                  TextSpan(
                    text: 'Sua empresa não tem conta? ',
                    style: const TextStyle(color: Colors.grey),
                    children: [
                      TextSpan(
                        text: 'Cadastre-se',
                        style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}