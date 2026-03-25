import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String nome;
  final String email;
  final String cargo;
  final String empresaId; // <--- AGORA USAMOS O ID ÚNICO
  final String empresaNome; // Nome para exibição rápida
  final bool isAdmin;
  final DateTime criadoEm;

  UserModel({
    required this.uid,
    required this.nome,
    required this.email,
    required this.cargo,
    required this.empresaId,
    required this.empresaNome,
    required this.isAdmin,
    required this.criadoEm,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      nome: data['nome'] ?? '',
      email: data['email'] ?? '',
      cargo: data['cargo'] ?? '',
      empresaId: data['empresaId'] ?? '',
      empresaNome: data['empresaNome'] ?? '',
      isAdmin: data['isAdmin'] ?? false,
      criadoEm: (data['criadoEm'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'nome': nome,
    'email': email,
    'cargo': cargo,
    'empresaId': empresaId,
    'empresaNome': empresaNome,
    'isAdmin': isAdmin,
    'criadoEm': Timestamp.fromDate(criadoEm),
  };
}