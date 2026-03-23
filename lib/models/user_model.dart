import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String nome;
  final String email;
  final String cargo;
  final String empresa;
  final bool isAdmin;
  final DateTime criadoEm;

  UserModel({
    required this.uid,
    required this.nome,
    required this.email,
    required this.cargo,
    required this.empresa,
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
      empresa: data['empresa'] ?? '',
      isAdmin: data['isAdmin'] ?? false,
      criadoEm: (data['criadoEm'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'nome': nome,
    'email': email,
    'cargo': cargo,
    'empresa': empresa,
    'isAdmin': isAdmin,
    'criadoEm': Timestamp.fromDate(criadoEm),
  };
}
