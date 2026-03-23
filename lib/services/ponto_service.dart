import 'package:flutter_riverpod/flutter_riverpod.dart'; // <--- ADICIONE ESTA LINHA
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uuid/uuid.dart';
import '../models/ponto_model.dart';

class PontoService {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ─── Geolocalização ───────────────────────────────────────────────────────

  Future<Position> obterPosicao() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Serviço de localização desativado.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permissão de localização negada.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permissão de localização negada permanentemente.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<String> obterEndereco(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return '${p.street}, ${p.subLocality}, ${p.locality} - ${p.administrativeArea}';
      }
    } catch (_) {}
    return 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}';
  }

  // ─── Registrar ponto ──────────────────────────────────────────────────────

  Future<PontoModel> registrarPonto({
    required String usuarioId,
    required String usuarioNome,
    required TipoBatida tipo,
    bool offline = false,
  }) async {
    Position? position;
    String endereco = 'Localização indisponível';

    try {
      position = await obterPosicao();
      endereco = await obterEndereco(position.latitude, position.longitude);
    } catch (e) {
      offline = true;
    }

    final ponto = PontoModel(
      id: _uuid.v4(),
      usuarioId: usuarioId,
      usuarioNome: usuarioNome,
      tipo: tipo,
      timestamp: DateTime.now(),
      latitude: position?.latitude ?? 0.0,
      longitude: position?.longitude ?? 0.0,
      endereco: endereco,
      offline: offline,
    );

    await _db
        .collection('pontos')
        .doc(ponto.id)
        .set(ponto.toMap());

    return ponto;
  }

  // ─── Buscar pontos do dia ─────────────────────────────────────────────────

  Future<List<PontoModel>> obterPontosHoje(String usuarioId) async {
    final hoje = DateTime.now();
    final inicio = DateTime(hoje.year, hoje.month, hoje.day);
    final fim = inicio.add(const Duration(days: 1));

    final query = await _db
        .collection('pontos')
        .where('usuarioId', isEqualTo: usuarioId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('timestamp', isLessThan: Timestamp.fromDate(fim))
        .orderBy('timestamp')
        .get();

    return query.docs.map(PontoModel.fromFirestore).toList();
  }

  // ─── Buscar pontos do mês ─────────────────────────────────────────────────

  Future<List<PontoModel>> obterPontosMes(String usuarioId, int mes, int ano) async {
    final inicio = DateTime(ano, mes, 1);
    final fim = DateTime(ano, mes + 1, 1);

    final query = await _db
        .collection('pontos')
        .where('usuarioId', isEqualTo: usuarioId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('timestamp', isLessThan: Timestamp.fromDate(fim))
        .orderBy('timestamp')
        .get();

    return query.docs.map(PontoModel.fromFirestore).toList();
  }

  // ─── Stream pontos hoje (tempo real) ────────────────────────────────────

  Stream<List<PontoModel>> streamPontosHoje(String usuarioId) {
    final hoje = DateTime.now();
    final inicio = DateTime(hoje.year, hoje.month, hoje.day);
    final fim = inicio.add(const Duration(days: 1));

    return _db
        .collection('pontos')
        .where('usuarioId', isEqualTo: usuarioId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('timestamp', isLessThan: Timestamp.fromDate(fim))
        .orderBy('timestamp')
        .snapshots()
        .map((s) => s.docs.map(PontoModel.fromFirestore).toList());
  }

  // ─── Stream todos os funcionários hoje (admin) ────────────────────────────

  Stream<List<PontoModel>> streamTodosPontosHoje() {
    final hoje = DateTime.now();
    final inicio = DateTime(hoje.year, hoje.month, hoje.day);
    final fim = inicio.add(const Duration(days: 1));

    return _db
        .collection('pontos')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('timestamp', isLessThan: Timestamp.fromDate(fim))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PontoModel.fromFirestore).toList());
  }

  // ─── Fechamento mensal ────────────────────────────────────────────────────

  Future<bool> verificarFechamentoExistente(String usuarioId, int mes, int ano) async {
    final doc = await _db
        .collection('fechamentos')
        .doc('${usuarioId}_${ano}_$mes')
        .get();
    return doc.exists && (doc.data()?['fechado'] ?? false);
  }

  Future<FechamentoMensal?> obterFechamento(String usuarioId, int mes, int ano) async {
    final doc = await _db
        .collection('fechamentos')
        .doc('${usuarioId}_${ano}_$mes')
        .get();
    return doc.exists ? FechamentoMensal.fromFirestore(doc) : null;
  }

  Future<void> salvarAssinatura({
    required String usuarioId,
    required String usuarioNome,
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

    await _db
        .collection('fechamentos')
        .doc(fechamento.id)
        .set(fechamento.toMap());
  }

  // ─── Todos os funcionários (admin) ───────────────────────────────────────

  Stream<List<Map<String, dynamic>>> streamFuncionarios() {
    return _db
        .collection('usuarios')
        .where('isAdmin', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'uid': d.id}).toList());
  }
}

final pontoServiceProvider = Provider((ref) => PontoService());
