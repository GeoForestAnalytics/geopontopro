import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user_model.dart';

// Provider que observa a sessão do Firebase Auth
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Provider que busca o perfil do usuário logado no Firestore
final userProfileProvider = FutureProvider<UserModel?>((ref) async {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return null;
  final doc = await FirebaseFirestore.instance
      .collection('usuarios')
      .doc(auth.uid)
      .get();
  return doc.exists ? UserModel.fromFirestore(doc) : null;
});

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  // ─── LOGIN ────────────────────────────────────────────────────────────────
  Future<UserModel?> login(String email, String senha) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: senha);
    final doc = await _db.collection('usuarios').doc(cred.user!.uid).get();
    return doc.exists ? UserModel.fromFirestore(doc) : null;
  }

  // ─── LOGOUT ───────────────────────────────────────────────────────────────
  Future<void> logout() => _auth.signOut();

  // ─── REGISTRO DE NOVA EMPRESA (SAAS) ──────────────────────────────────────
  // Este método cria a empresa na coleção 'empresas' e o usuário mestre 
  // na coleção 'usuarios', vinculando ambos pelo empresaId (CNPJ).
  Future<void> registrarNovaEmpresa({
    required String nomeAdmin,
    required String email,
    required String senha,
    required String nomeEmpresa,
    required String cnpj,
  }) async {
    // 1. O ID da empresa será o CNPJ limpo (apenas números)
    final String empresaId = cnpj.replaceAll(RegExp(r'[^0-9]'), '');

    // 2. Cria o usuário mestre no Firebase Auth
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email, 
      password: senha
    );

    final String uid = cred.user!.uid;

    // 3. Cria o documento da EMPRESA para gestão administrativa
    await _db.collection('empresas').doc(empresaId).set({
      'nome': nomeEmpresa,
      'cnpj': cnpj,
      'donoUid': uid,
      'status': 'ativo', // Permite que você bloqueie a empresa inteira aqui
      'criadoEm': FieldValue.serverTimestamp(),
    });

    // 4. Cria o perfil do USUÁRIO MASTER vinculado a essa empresa
    final user = UserModel(
      uid: uid,
      nome: nomeAdmin,
      email: email,
      cargo: 'Gerente Master',
      empresaId: empresaId,     // <--- Vínculo para isolamento de dados
      empresaNome: nomeEmpresa,  // <--- Cache do nome para exibição
      isAdmin: true,            // <--- Tem acesso ao painel admin
      criadoEm: DateTime.now(),
    );

    await _db.collection('usuarios').doc(uid).set(user.toMap());
  }

  // ─── CRIAR USUÁRIO DA EQUIPE (GERENTE ADICIONANDO PESSOAS) ────────────────
  // Usa uma instância secundária para não deslogar o gerente durante o processo.
  Future<void> criarUsuarioEquipe({
    required String nome,
    required String email,
    required String senha,
    required String cargo,
    required String empresaId,
    required String empresaNome,
    required bool isGerente,
  }) async {
    
    // 1. Inicializa app temporário para criar a conta do funcionário
    FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryApp',
      options: Firebase.app().options,
    );

    try {
      // 2. Cria a conta no Auth do app secundário
      UserCredential cred = await FirebaseAuth.instanceFor(app: secondaryApp)
          .createUserWithEmailAndPassword(email: email, password: senha);

      final String novoUid = cred.user!.uid;

      // 3. Salva no Firestore do app principal
      final user = UserModel(
        uid: novoUid,
        nome: nome,
        email: email,
        cargo: cargo,
        empresaId: empresaId,     // <--- Herda a empresa do gerente
        empresaNome: empresaNome,
        isAdmin: isGerente,
        criadoEm: DateTime.now(),
      );

      await _db.collection('usuarios').doc(novoUid).set(user.toMap());
      
      // 4. Limpa a instância temporária
      await secondaryApp.delete();
      
    } catch (e) {
      // Em caso de erro, garante que o app secundário seja deletado da memória
      await secondaryApp.delete();
      rethrow;
    }
  }
}

// Provider do serviço para injeção de dependência com Riverpod
final authServiceProvider = Provider((ref) => AuthService());