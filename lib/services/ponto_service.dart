import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uuid/uuid.dart';
import '../models/ponto_model.dart';

class PontoService {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ─── GPS e Localização ───────────────────────────────────────────────────
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

  // ─── Registro de Ponto ────────────────────────────────────────────────────
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
      tipo: tipo,
      timestamp: DateTime.now(),
      latitude: pos?.latitude ?? 0.0,
      longitude: pos?.longitude ?? 0.0,
      endereco: endereco,
      offline: offline,
    );

    final dados = ponto.toMap();
    dados['empresa'] = empresa; // Filtro de segurança SaaS

    await _db.collection('pontos').doc(ponto.id).set(dados);
    return ponto;
  }

  // ─── Streams e Consultas (Com Filtro de Empresa) ──────────────────────────
  Stream<List<PontoModel>> streamPontosHoje(String usuarioId) {
    final inicio = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _db.collection('pontos')
        .where('usuarioId', isEqualTo: usuarioId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .orderBy('timestamp')
        .snapshots()
        .map((s) => s.docs.map(PontoModel.fromFirestore).toList());
  }

  Stream<List<PontoModel>> streamTodosPontosHoje(String empresa) {
    final inicio = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _db.collection('pontos')
        .where('empresa', isEqualTo: empresa)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PontoModel.fromFirestore).toList());
  }

  Stream<List<Map<String, dynamic>>> streamTodosUsuarios(String empresa) {
    return _db.collection('usuarios')
        .where('empresa', isEqualTo: empresa)
        .orderBy('isAdmin', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'uid': d.id}).toList());
  }

  Future<List<PontoModel>> obterPontosMes(String usuarioId, int mes, int ano) async {
    final inicio = DateTime(ano, mes, 1);
    final fim = DateTime(ano, mes + 1, 1);
    final query = await _db.collection('pontos')
        .where('usuarioId', isEqualTo: usuarioId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('timestamp', isLessThan: Timestamp.fromDate(fim))
        .orderBy('timestamp')
        .get();
    return query.docs.map(PontoModel.fromFirestore).toList();
  }

  // ─── Assinaturas e Fechamento ─────────────────────────────────────────────
  Future<bool> verificarFechamentoExistente(String usuarioId, int mes, int ano) async {
    final doc = await _db.collection('fechamentos').doc('${usuarioId}_${ano}_$mes').get();
    return doc.exists;
  }

  Future<FechamentoMensal?> obterFechamento(String usuarioId, int mes, int ano) async {
    final doc = await _db.collection('fechamentos').doc('${usuarioId}_${ano}_$mes').get();
    return doc.exists ? FechamentoMensal.fromFirestore(doc) : null;
  }

  Future<void> salvarAssinatura({
    required String usuarioId,
    required String usuarioNome,
    required String empresa,
    required int mes,
    required int ano,
    required String assinaturaBase64,
  }) async {
    final fechamento = FechamentoMensal(
      id: '${usuarioId}_${ano}_$mes',
      usuarioId: usuarioId,
      usuarioNome: usuarioNome,
      mes: mes,
      ano: ano,
      pontos: [],
      assinaturaBase64: assinaturaBase64,
      assinadoEm: DateTime.now(),
      fechado: true,
    );
    final dados = fechamento.toMap();
    dados['empresa'] = empresa;
    await _db.collection('fechamentos').doc(fechamento.id).set(dados);
  }
}

final pontoServiceProvider = Provider((ref) => PontoService());