import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uuid/uuid.dart';
import '../models/ponto_model.dart';

class PontoService {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ─── GPS ──────────────────────────────────────────────────────────────────
  Future<Position> obterPosicao() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw 'GPS_DESLIGADO';
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw 'PERMISSAO_NEGADA';
    }
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<String> obterEndereco(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return '${p.street}, ${p.subLocality}, ${p.locality}';
      }
    } catch (_) {}
    return 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';
  }

  // ─── REGISTRO ─────────────────────────────────────────────────────────────
  Future<PontoModel> registrarPonto({
    required String usuarioId,
    required String usuarioNome,
    required String empresa,
    required TipoBatida tipo,
  }) async {
    Position? pos;
    String endereco = 'Localização indisponível';
    bool offline = false;

    try {
      pos = await obterPosicao();
      endereco = await obterEndereco(pos.latitude, pos.longitude);
    } catch (e) {
      if (e == 'GPS_DESLIGADO' || e == 'PERMISSAO_NEGADA') rethrow;
      offline = true;
    }

    final ponto = PontoModel(
      id: _uuid.v4(),
      usuarioId: usuarioId,
      usuarioNome: usuarioNome,
      empresa: empresa,
      tipo: tipo,
      timestamp: DateTime.now(),
      latitude: pos?.latitude ?? 0.0,
      longitude: pos?.longitude ?? 0.0,
      endereco: endereco,
      offline: offline,
    );

    await _db.collection('pontos').doc(ponto.id).set(ponto.toMap());
    return ponto;
  }

  // ─── STREAMS (AQUI ESTÁ A ORDENAÇÃO) ──────────────────────────────────────
  
  // Stream para a HomePage do Colaborador
  Stream<List<PontoModel>> streamPontosHoje(String usuarioId) {
    final hoje = DateTime.now();
    final inicioDoDia = DateTime(hoje.year, hoje.month, hoje.day);

    return _db.collection('pontos')
        .where('usuarioId', isEqualTo: usuarioId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDoDia))
        .orderBy('timestamp', descending: false) // <--- ORDENAÇÃO CRUCIAL: Do primeiro ao último
        .snapshots()
        .map((s) => s.docs.map((d) => PontoModel.fromFirestore(d)).toList());
  }

  // Stream para o Painel do Gerente
  Stream<List<PontoModel>> streamTodosPontosHoje(String empresa) {
    final hoje = DateTime.now();
    final inicioDoDia = DateTime(hoje.year, hoje.month, hoje.day);

    return _db.collection('pontos')
        .where('empresa', isEqualTo: empresa)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDoDia))
        .orderBy('timestamp', descending: true) // No dashboard, o mais recente aparece em cima
        .snapshots()
        .map((s) => s.docs.map((d) => PontoModel.fromFirestore(d)).toList());
  }

  // ─── CONSULTAS ────────────────────────────────────────────────────────────
  
  Future<List<PontoModel>> obterPontosMes(String usuarioId, int mes, int ano) async {
    final inicio = DateTime(ano, mes, 1);
    final fim = DateTime(ano, mes + 1, 1);
    
    final query = await _db.collection('pontos')
        .where('usuarioId', isEqualTo: usuarioId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('timestamp', isLessThan: Timestamp.fromDate(fim))
        .orderBy('timestamp', descending: false) // <--- Garante ordem no PDF/Histórico
        .get();
        
    return query.docs.map((d) => PontoModel.fromFirestore(d)).toList();
  }

  Stream<List<Map<String, dynamic>>> streamTodosUsuarios(String empresa) {
    return _db.collection('usuarios')
        .where('empresa', isEqualTo: empresa)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'uid': d.id}).toList());
  }

  // ─── ASSINATURAS ──────────────────────────────────────────────────────────
  
  Future<bool> verificarFechamentoExistente(String usuarioId, int mes, int ano) async {
    final doc = await _db.collection('fechamentos').doc('${usuarioId}_${ano}_$mes').get();
    return doc.exists;
  }

  Future<void> salvarAssinatura({
    required String usuarioId,
    required String usuarioNome,
    required String empresa,
    required int mes,
    required int ano,
    required String assinaturaBase64,
  }) async {
    await _db.collection('fechamentos').doc('${usuarioId}_${ano}_$mes').set({
      'usuarioId': usuarioId,
      'usuarioNome': usuarioNome,
      'empresa': empresa,
      'mes': mes,
      'ano': ano,
      'assinaturaBase64': assinaturaBase64,
      'assinadoEm': FieldValue.serverTimestamp(),
      'fechado': true,
    });
  }

  Future<FechamentoMensal?> obterFechamento(String usuarioId, int mes, int ano) async {
    final doc = await _db.collection('fechamentos').doc('${usuarioId}_${ano}_$mes').get();
    return doc.exists ? FechamentoMensal.fromFirestore(doc) : null;
  }
}

final pontoServiceProvider = Provider((ref) => PontoService());