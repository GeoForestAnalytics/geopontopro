import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user_model.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

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

  Future<UserModel?> login(String email, String senha) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: senha);
    final doc = await _db.collection('usuarios').doc(cred.user!.uid).get();
    return doc.exists ? UserModel.fromFirestore(doc) : null;
  }

  Future<void> logout() => _auth.signOut();

  // MÉTODO CORRIGIDO: Cria o usuário sem deslogar o Gerente
  Future<void> criarUsuario({
    required String nome,
    required String email,
    required String senha,
    required String cargo,
    required String empresa,
    required bool isGerente,
  }) async {
    
    // 1. Criamos uma instância temporária para não deslogar o gerente atual
    FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryApp',
      options: Firebase.app().options,
    );

    try {
      // 2. Cria o usuário na instância secundária
      UserCredential cred = await FirebaseAuth.instanceFor(app: secondaryApp)
          .createUserWithEmailAndPassword(email: email, password: senha);

      final String novoUid = cred.user!.uid;

      // 3. Salva no Firestore usando a instância principal (o gerente continua logado)
      final user = UserModel(
        uid: novoUid,
        nome: nome,
        email: email,
        cargo: cargo,
        empresa: empresa,
        isAdmin: isGerente,
        criadoEm: DateTime.now(),
      );

      await _db.collection('usuarios').doc(novoUid).set(user.toMap());
      
      // 4. Deleta a instância temporária
      await secondaryApp.delete();
      
    } catch (e) {
      await secondaryApp.delete();
      rethrow;
    }
  }
}

final authServiceProvider = Provider((ref) => AuthService());