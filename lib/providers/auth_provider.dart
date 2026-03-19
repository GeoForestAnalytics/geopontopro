import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

// Provider que observa a sessão do Firebase Auth
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Provider que busca e armazena os dados do usuário logado (Cache em memória)
final userProfileProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider).value;
  if (authState == null) return null;

  // Realiza a leitura no banco APENAS UMA VEZ
  final doc = await FirebaseFirestore.instance
      .collection('usuarios')
      .doc(authState.uid)
      .get();
      
  return doc.exists ? UserModel.fromFirestore(doc) : null;
});