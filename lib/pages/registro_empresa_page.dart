import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importação do Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Importação do Firestore

class RegistroEmpresaPage extends StatefulWidget {
  const RegistroEmpresaPage({super.key});

  @override
  State<RegistroEmpresaPage> createState() => _RegistroEmpresaPageState();
}

class _RegistroEmpresaPageState extends State<RegistroEmpresaPage> {
  final _nomeEmpresa = TextEditingController();
  final _cnpj = TextEditingController();
  final _nomeAdmin = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _carregando = false;

  Future<void> _registrarTudo() async {
    // 1. Validações Iniciais
    if (_email.text.isEmpty || _senha.text.length < 6 || _nomeEmpresa.text.isEmpty) {
      _mostrarErro("Preencha todos os campos. Senha mínima de 6 caracteres.");
      return;
    }

    setState(() => _carregando = true);
    
    try {
      // 2. CRIA O LOGIN NO FIREBASE AUTH
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _senha.text.trim(),
      );

      final String uid = userCredential.user!.uid;

      // 3. SALVA OS DADOS NO FIRESTORE (Coleção usuarios)
      // Aqui definimos que este usuário é o 'gerente' e criamos o vínculo com a empresa
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'uid': uid,
        'nome': _nomeAdmin.text.trim(),
        'email': _email.text.trim(),
        'cnpj': _cnpj.text.trim(),
        'empresa': _nomeEmpresa.text.trim(), // Nome da empresa para o seu SaaS
        'cargo': 'gerente', // Identificador de nível de acesso
        'status': 'ativo',
        'criado_em': FieldValue.serverTimestamp(),
      });

      // 4. (OPCIONAL) CRIAR UM REGISTRO NA COLEÇÃO DE EMPRESAS
      // Útil para você ter uma lista de todos os seus clientes (SaaS)
      await FirebaseFirestore.instance.collection('empresas').doc(_nomeEmpresa.text.trim()).set({
        'nome_fantasia': _nomeEmpresa.text.trim(),
        'cnpj': _cnpj.text.trim(),
        'dono_uid': uid,
        'data_cadastro': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      
      // 5. DESLOGA POR SEGURANÇA (Para o fluxo de login ser limpo como você pediu)
      await FirebaseAuth.instance.signOut();

      _mostrarMensagem('Conta mestre criada com sucesso!', Colors.green);
      
      // Retorna para a tela de login
      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      String msg = "Erro ao cadastrar.";
      if (e.code == 'email-already-in-use') msg = "Este e-mail já está em uso.";
      if (e.code == 'invalid-email') msg = "E-mail inválido.";
      if (e.code == 'weak-password') msg = "Senha muito fraca.";
      _mostrarErro(msg);
    } catch (e) {
      _mostrarErro("Erro inesperado ao registrar empresa: $e");
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _mostrarMensagem(String msg, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: cor, behavior: SnackBarBehavior.floating)
    );
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating)
    );
  }

  @override
  void dispose() {
    _nomeEmpresa.dispose(); _cnpj.dispose(); _nomeAdmin.dispose(); _email.dispose(); _senha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Cadastrar Nova Empresa'), 
        backgroundColor: Colors.green[800], 
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Dados da Empresa",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 16),
            _buildTextField(_nomeEmpresa, 'Nome Fantasia', Icons.business),
            const SizedBox(height: 12),
            _buildTextField(_cnpj, 'CNPJ (apenas números)', Icons.description, keyboard: TextInputType.number),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Divider(),
            ),
            
            const Text(
              "Seus Dados (Gerente)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 16),
            _buildTextField(_nomeAdmin, 'Seu Nome Completo', Icons.person),
            const SizedBox(height: 12),
            _buildTextField(_email, 'E-mail de Acesso', Icons.email, keyboard: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _buildTextField(_senha, 'Crie uma Senha', Icons.lock, obscure: true),
            
            const SizedBox(height: 40),
            _carregando 
              ? const Center(child: CircularProgressIndicator()) 
              : SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800], 
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    onPressed: _registrarTudo, 
                    child: const Text('FINALIZAR CADASTRO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false, TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}