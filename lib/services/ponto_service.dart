import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import '../models/ponto_model.dart';

class PontoService {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ─── REGISTRO DE PONTO ────────────────────────────────────────────────────
  Future<PontoModel> registrarPonto({
    required String usuarioId,
    required String usuarioNome,
    required String empresaId,
    required TipoBatida tipo,
    String comentario = '', // <--- ADICIONADO
  }) async {
    Position? pos;
    String endereco = 'Localização Offline';
    bool offline = false;

    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude).timeout(const Duration(seconds: 3));
      if (placemarks.isNotEmpty) {
        endereco = '${placemarks.first.street}, ${placemarks.first.subLocality}';
      }
    } catch (e) {
      offline = true;
    }

    final ponto = PontoModel(
      id: _uuid.v4(),
      usuarioId: usuarioId,
      usuarioNome: usuarioNome,
      empresaId: empresaId,
      tipo: tipo,
      timestamp: DateTime.now(),
      latitude: pos?.latitude ?? 0.0,
      longitude: pos?.longitude ?? 0.0,
      endereco: endereco,
      offline: offline,
      comentario: comentario,
    );

    _db.collection('pontos').doc(ponto.id).set(ponto.toMap());
    return ponto;
  }

  // ─── STREAMS ESTABILIZADOS ─────────────────────────────────────────────────
  Stream<List<PontoModel>> streamPontosHoje(String usuarioId) {
    final inicio = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _db.collection('pontos')
        .where('usuarioId', isEqualTo: usuarioId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .orderBy('timestamp', descending: false)
        .snapshots(includeMetadataChanges: false) // <--- DESLIGADO PARA EVITAR LOOP NO MONITOR
        .map((s) => s.docs.map((d) => PontoModel.fromFirestore(d)).toList());
  }

  Stream<List<PontoModel>> streamTodosPontosHoje(String empresaId) {
    final inicio = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _db.collection('pontos')
        .where('empresaId', isEqualTo: empresaId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => PontoModel.fromFirestore(d)).toList());
  }

  Stream<List<Map<String, dynamic>>> streamTodosUsuarios(String empresaId) {
    return _db.collection('usuarios')
        .where('empresaId', isEqualTo: empresaId)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'uid': d.id}).toList());
  }

  // ─── FUNÇÃO DE EXPORTAÇÃO EXCEL/CSV ────────────────────────────────────────
  Future<void> exportarPontosParaCSV(List<PontoModel> pontos, String nomeFuncionario) async {
    String csv = "Data;Hora;Colaborador;Tipo;Endereco;Latitude;Longitude;Observacao\n";
    
    for (var p in pontos) {
      csv += "${DateFormat('dd/MM/yyyy').format(p.timestamp)};";
      csv += "${DateFormat('HH:mm').format(p.timestamp)};";
      csv += "${p.usuarioNome};";
      csv += "${p.tipo.label};";
      csv += "${p.endereco.replaceAll(';', ',')};";
      csv += "${p.latitude};";
      csv += "${p.longitude};";
      csv += "${p.comentario.replaceAll(';', ',')}\n";
    }

    final bytes = Uint8List.fromList(csv.codeUnits);
    await Printing.sharePdf(bytes: bytes, filename: 'relatorio_${nomeFuncionario}.csv');
  }

  // --- Outros métodos (obterPontosMes, etc) ---
  Future<List<PontoModel>> obterPontosMes(String usuarioId, int mes, int ano) async {
    final inicio = DateTime(ano, mes, 1);
    final fim = (mes == 12) ? DateTime(ano + 1, 1, 1) : DateTime(ano, mes + 1, 1);
    final query = await _db.collection('pontos')
        .where('usuarioId', isEqualTo: usuarioId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('timestamp', isLessThan: Timestamp.fromDate(fim))
        .orderBy('timestamp', descending: false)
        .get();
    return query.docs.map((d) => PontoModel.fromFirestore(d)).toList();
  }

  Future<bool> verificarFechamentoExistente(String usuarioId, int mes, int ano) async {
    final doc = await _db.collection('fechamentos').doc('${usuarioId}_${ano}_$mes').get();
    return doc.exists;
  }

  Future<void> salvarAssinatura({required String usuarioId, required String usuarioNome, required String empresaId, required int mes, required int ano, required String assinaturaBase64}) async {
    _db.collection('fechamentos').doc('${usuarioId}_${ano}_$mes').set({
      'usuarioId': usuarioId, 'usuarioNome': usuarioNome, 'empresaId': empresaId, 'mes': mes, 'ano': ano, 'assinaturaBase64': assinaturaBase64, 'assinadoEm': FieldValue.serverTimestamp(), 'fechado': true,
    });
  }

  Future<FechamentoMensal?> obterFechamento(String usuarioId, int mes, int ano) async {
    final doc = await _db.collection('fechamentos').doc('${usuarioId}_${ano}_$mes').get();
    return doc.exists ? FechamentoMensal.fromFirestore(doc) : null;
  }
}

final pontoServiceProvider = Provider((ref) => PontoService());

final monitorPontosProvider = StreamProvider.family<List<PontoModel>, String>((ref, empresaId) {
  return ref.watch(pontoServiceProvider).streamTodosPontosHoje(empresaId);
});