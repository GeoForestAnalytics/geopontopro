import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
// Certifique-se de que o firebase_options.dart está importado corretamente
import '../firebase_options.dart'; 

class CadastroFuncionarioPage extends StatefulWidget {
  const CadastroFuncionarioPage({super.key});

  @override
  State<CadastroFuncionarioPage> createState() => _CadastroFuncionarioPageState();
}

class _CadastroFuncionarioPageState extends State<CadastroFuncionarioPage> {
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _cpfController = TextEditingController();
  
  bool _estaCarregando = false;

  Future<void> _salvarFuncionario() async {
    if (_nomeController.text.trim().isEmpty || 
        _emailController.text.trim().isEmpty || 
        _senhaController.text.length < 6) {
      _mostrarMensagem('Preencha os campos obrigatórios (Senha mín. 6 caracteres)', Colors.orange);
      return;
    }

    setState(() => _estaCarregando = true);
    
    // Nome da instância temporária para não conflitar com a principal
    const String tempAppName = 'temp_registration';

    try {
      final managerAuth = FirebaseAuth.instance;
      final managerUser = managerAuth.currentUser;

      if (managerUser == null) throw 'Você precisa estar logado como gerente.';

      // 1. BUSCA O NOME DA EMPRESA DO GERENTE LOGADO
      final managerDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(managerUser.uid)
          .get();

      if (!managerDoc.exists) throw 'Perfil do gerente não encontrado.';
      final empresaNome = managerDoc.data()?['empresa'];

      // 2. CRIA UMA INSTÂNCIA TEMPORÁRIA DO FIREBASE
      // Isso é o que impede o logout do gerente!
      FirebaseApp tempApp;
      try {
        tempApp = await Firebase.initializeApp(
          name: tempAppName,
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        // Se a instância já existir por erro prévio, recupera ela
        tempApp = Firebase.app(tempAppName);
      }

      // 3. CRIA O LOGIN DO FUNCIONÁRIO NO AUTH DA INSTÂNCIA TEMPORÁRIA
      UserCredential res = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text.trim(),
      );

      final String novoUid = res.user!.uid;

      // 4. SALVA OS DADOS DO FUNCIONÁRIO NO FIRESTORE PRINCIPAL
      await FirebaseFirestore.instance.collection('usuarios').doc(novoUid).set({
        'uid': novoUid,
        'nome': _nomeController.text.trim(),
        'email': _emailController.text.trim(),
        'cpf': _cpfController.text.trim(),
        'empresa': empresaNome, // Vincula à mesma empresa do gerente
        'cargo': 'colaborador', // Nível de acesso do funcionário
        'status': 'ativo',
        'criado_em': FieldValue.serverTimestamp(),
      });

      // 5. ENCERRA A INSTÂNCIA TEMPORÁRIA
      await tempApp.delete();

      if (!mounted) return;
      _mostrarMensagem('Funcionário cadastrado com sucesso!', Colors.green);
      Navigator.pop(context); 

    } on FirebaseAuthException catch (e) {
      String msg = "Erro ao criar login.";
      if (e.code == 'email-already-in-use') msg = "Este e-mail já está sendo usado.";
      _mostrarMensagem(msg, Colors.red);
    } catch (e) {
      _mostrarMensagem('Erro inesperado: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _estaCarregando = false);
    }
  }

  void _mostrarMensagem(String msg, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: cor, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Novo Colaborador'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.green[800],
              padding: const EdgeInsets.only(bottom: 30),
              child: const Column(
                children: [
                  Icon(Icons.person_add_alt_1, size: 70, color: Colors.white),
                  SizedBox(height: 10),
                  Text('Cadastro de Equipe', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildInput(_nomeController, 'Nome Completo', Icons.person),
                  const SizedBox(height: 16),
                  _buildInput(_cpfController, 'CPF (apenas números)', Icons.badge, keyboard: TextInputType.number),
                  const SizedBox(height: 16),
                  _buildInput(_emailController, 'E-mail de Login', Icons.email, keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _buildInput(_senhaController, 'Senha Provisória', Icons.lock, obscure: true),
                  const SizedBox(height: 40),
                  if (_estaCarregando)
                    const CircularProgressIndicator(color: Colors.green)
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[800],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _salvarFuncionario, 
                        child: const Text('FINALIZAR E CRIAR LOGIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String label, IconData icon, {bool obscure = false, TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green[700]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}