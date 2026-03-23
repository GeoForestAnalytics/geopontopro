import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoBatida { entrada, saidaAlmoco, retornoAlmoco, saida }

extension TipoBatidaExt on TipoBatida {
  String get label {
    switch (this) {
      case TipoBatida.entrada:        return 'Entrada';
      case TipoBatida.saidaAlmoco:    return 'Saída Almoço';
      case TipoBatida.retornoAlmoco:  return 'Retorno Almoço';
      case TipoBatida.saida:          return 'Saída';
    }
  }

  String get value {
    switch (this) {
      case TipoBatida.entrada:        return 'entrada';
      case TipoBatida.saidaAlmoco:    return 'saida_almoco';
      case TipoBatida.retornoAlmoco:  return 'retorno_almoco';
      case TipoBatida.saida:          return 'saida';
    }
  }

  static TipoBatida fromString(String v) {
    switch (v) {
      case 'entrada':         return TipoBatida.entrada;
      case 'saida_almoco':    return TipoBatida.saidaAlmoco;
      case 'retorno_almoco':  return TipoBatida.retornoAlmoco;
      default:                return TipoBatida.saida;
    }
  }
}

class PontoModel {
  final String id;
  final String usuarioId;
  final String usuarioNome;
  final TipoBatida tipo;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String endereco;
  final bool offline;

  PontoModel({
    required this.id,
    required this.usuarioId,
    required this.usuarioNome,
    required this.tipo,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.endereco,
    this.offline = false,
  });

  factory PontoModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PontoModel(
      id: doc.id,
      usuarioId: d['usuarioId'] ?? '',
      usuarioNome: d['usuarioNome'] ?? '',
      tipo: TipoBatidaExt.fromString(d['tipo'] ?? 'entrada'),
      timestamp: (d['timestamp'] as Timestamp).toDate(),
      latitude: (d['latitude'] ?? 0.0).toDouble(),
      longitude: (d['longitude'] ?? 0.0).toDouble(),
      endereco: d['endereco'] ?? '',
      offline: d['offline'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'usuarioId': usuarioId,
    'usuarioNome': usuarioNome,
    'tipo': tipo.value,
    'timestamp': Timestamp.fromDate(timestamp),
    'latitude': latitude,
    'longitude': longitude,
    'endereco': endereco,
    'offline': offline,
  };
}

class FechamentoMensal {
  final String id;
  final String usuarioId;
  final String usuarioNome;
  final int mes;
  final int ano;
  final List<PontoModel> pontos;
  final String? assinaturaBase64;
  final DateTime? assinadoEm;
  final bool fechado;

  FechamentoMensal({
    required this.id,
    required this.usuarioId,
    required this.usuarioNome,
    required this.mes,
    required this.ano,
    required this.pontos,
    this.assinaturaBase64,
    this.assinadoEm,
    required this.fechado,
  });

  factory FechamentoMensal.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FechamentoMensal(
      id: doc.id,
      usuarioId: d['usuarioId'] ?? '',
      usuarioNome: d['usuarioNome'] ?? '',
      mes: d['mes'] ?? 1,
      ano: d['ano'] ?? DateTime.now().year,
      pontos: [],
      assinaturaBase64: d['assinaturaBase64'],
      assinadoEm: (d['assinadoEm'] as Timestamp?)?.toDate(),
      fechado: d['fechado'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'usuarioId': usuarioId,
    'usuarioNome': usuarioNome,
    'mes': mes,
    'ano': ano,
    'assinaturaBase64': assinaturaBase64,
    'assinadoEm': assinadoEm != null ? Timestamp.fromDate(assinadoEm!) : null,
    'fechado': fechado,
  };
}
