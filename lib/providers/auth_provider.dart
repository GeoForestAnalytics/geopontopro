import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final userProfileProvider = FutureProvider<UserModel?>((ref) async {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return null;
  final doc = await FirebaseFirestore.instance.collection('usuarios').doc(auth.uid).get();
  return doc.exists ? UserModel.fromFirestore(doc) : null;
});

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<UserModel?> login(String email, String senha) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: senha);
    final doc = await _db.collection('usuarios').doc(cred.user!.uid).get();
    return doc.exists ? UserModel.fromFirestore(doc) : null;
  }

  Future<void> logout() => _auth.signOut();

  Future<UserModel> criarFuncionario({
    required String nome,
    required String email,
    required String senha,
    required String cargo,
    required String empresa,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: senha);
    final user = UserModel(
      uid: cred.user!.uid,
      nome: nome,
      email: email,
      cargo: cargo,
      empresa: empresa,
      isAdmin: false,
      criadoEm: DateTime.now(),
    );
    await _db.collection('usuarios').doc(cred.user!.uid).set(user.toMap());
    return user;
  }
}

final authServiceProvider = Provider((ref) => AuthService());
