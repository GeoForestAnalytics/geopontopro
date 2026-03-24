import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uuid/uuid.dart';
import '../models/ponto_model.dart';

class PontoService {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ─── LOCALIZAÇÃO COM TIMEOUT (PARA NÃO TRAVAR OFFLINE) ────────────────────────────
  Future<Position> obterPosicao() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw 'GPS_DESLIGADO';

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw 'PERMISSAO_NEGADA';
    }

    // Timeout de 6 segundos: se o satélite não responder, o app não fica "girando" infinito
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 6),
    );
  }

  Future<String> obterEndereco(double lat, double lng) async {
    try {
      // Tradução de endereço exige internet. Colocamos timeout de 3s.
      final placemarks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 3));
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return '${p.street}, ${p.subLocality}, ${p.locality}';
      }
    } catch (_) {
      // Em caso de falha ou falta de internet, retorna as coordenadas cruas
    }
    return 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)} (Sinal fraco)';
  }

  // ─── REGISTRO INSTANTÂNEO (LOCAL-FIRST) ──────────────────────────────────
  Future<PontoModel> registrarPonto({
    required String usuarioId,
    required String usuarioNome,
    required String empresa,
    required TipoBatida tipo,
  }) async {
    Position? pos;
    String endereco = 'Localização Offline';
    bool offline = false;

    try {
      pos = await obterPosicao();
      endereco = await obterEndereco(pos.latitude, pos.longitude);
    } catch (e) {
      // Se der erro de GPS ou Timeout, marcamos como offline e seguimos
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

    // REMOVIDO O 'AWAIT': O app grava no banco interno do celular imediatamente.
    // O Firebase SDK cuida de enviar para a nuvem em segundo plano quando houver rede.
    _db.collection('pontos').doc(ponto.id).set(ponto.toMap());
    
    return ponto;
  }

  // ─── STREAMS COM SUPORTE A CACHE (includeMetadataChanges: true) ──────────
  // O parâmetro 'includeMetadataChanges' faz o ponto aparecer na lista 
  // no exato segundo que você clica no botão, mesmo sem internet.

  Stream<List<PontoModel>> streamPontosHoje(String usuarioId) {
    final inicioDoDia = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _db.collection('pontos')
        .where('usuarioId', isEqualTo: usuarioId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDoDia))
        .orderBy('timestamp', descending: false)
        .snapshots(includeMetadataChanges: true) 
        .map((s) => s.docs.map((d) => PontoModel.fromFirestore(d)).toList());
  }

  Stream<List<PontoModel>> streamTodosPontosHoje(String empresa) {
    final inicioDoDia = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _db.collection('pontos')
        .where('empresa', isEqualTo: empresa)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDoDia))
        .orderBy('timestamp', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((s) => s.docs.map((d) => PontoModel.fromFirestore(d)).toList());
  }

  Stream<List<Map<String, dynamic>>> streamTodosUsuarios(String empresa) {
    return _db.collection('usuarios')
        .where('empresa', isEqualTo: empresa)
        .snapshots(includeMetadataChanges: true)
        .map((s) => s.docs.map((d) => {...d.data(), 'uid': d.id}).toList());
  }

  // ─── CONSULTAS COM FONTE HÍBRIDA ─────────────────────────────────────────
  Future<List<PontoModel>> obterPontosMes(String usuarioId, int mes, int ano) async {
    final inicio = DateTime(ano, mes, 1);
    final fim = (mes == 12) ? DateTime(ano + 1, 1, 1) : DateTime(ano, mes + 1, 1);
    
    final query = await _db.collection('pontos')
        .where('usuarioId', isEqualTo: usuarioId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('timestamp', isLessThan: Timestamp.fromDate(fim))
        .orderBy('timestamp', descending: false)
        .get(const GetOptions(source: Source.serverAndCache)); // Prioriza servidor, mas usa cache se offline
        
    return query.docs.map((d) => PontoModel.fromFirestore(d)).toList();
  }

  // ─── ASSINATURAS E FECHAMENTO ─────────────────────────────────────────────
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
    // Também grava assinatura localmente primeiro
    _db.collection('fechamentos').doc('${usuarioId}_${ano}_$mes').set({
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
}

// ─── PROVIDERS (ESTABILIZADORES DE TELA) ───────────────────────────────────
final pontoServiceProvider = Provider((ref) => PontoService());

final monitorPontosProvider = StreamProvider.family<List<PontoModel>, String>((ref, empresa) {
  return ref.watch(pontoServiceProvider).streamTodosPontosHoje(empresa);
});