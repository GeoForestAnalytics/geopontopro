// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/enums.dart'; // ISSO CORRIGE O ERRO DE URI E UNDEFINED CLASS

class UserModel {
  final String uid;
  final String nome;
  final String email;
  final String empresa;
  final UserRole cargo;
  final String cpf;

  UserModel({
    required this.uid,
    required this.nome,
    required this.email,
    required this.empresa,
    required this.cargo,
    required this.cpf,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      nome: data['nome'] ?? '',
      email: data['email'] ?? '',
      empresa: data['empresa'] ?? '',
      // Comparação segura de string para Enum
      cargo: data['cargo'] == 'gerente' ? UserRole.gerente : UserRole.colaborador,
      cpf: data['cpf'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nome': nome,
      'email': email,
      'empresa': empresa,
      'cargo': cargo.name, // Salva como string 'gerente' ou 'colaborador'
      'cpf': cpf,
    };
  }
}