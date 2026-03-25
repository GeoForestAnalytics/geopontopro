import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uuid/uuid.dart';
import '../models/ponto_model.dart';

class PontoService {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  Future<Position> obterPosicao() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw 'GPS_DESLIGADO';
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw 'PERMISSAO_NEGADA';
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 6),
    );
  }

  Future<String> obterEndereco(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng).timeout(const Duration(seconds: 3));
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return '${p.street}, ${p.subLocality}, ${p.locality}';
      }
    } catch (_) {}
    return 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';
  }

  Future<PontoModel> registrarPonto({
    required String usuarioId,
    required String usuarioNome,
    required String empresaId, // <--- CORRIGIDO
    required TipoBatida tipo,
    String comentario = '',
  }) async {
    Position? pos;
    String endereco = 'Localização Offline';
    bool offline = false;

    try {
      pos = await obterPosicao();
      endereco = await obterEndereco(pos.latitude, pos.longitude);
    } catch (e) {
      offline = true;
    }

    final ponto = PontoModel(
      id: _uuid.v4(),
      usuarioId: usuarioId,
      usuarioNome: usuarioNome,
      empresaId: empresaId, // <--- CORRIGIDO
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

  Stream<List<PontoModel>> streamPontosHoje(String usuarioId) {
    final inicioDoDia = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _db.collection('pontos')
        .where('usuarioId', isEqualTo: usuarioId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDoDia))
        .orderBy('timestamp', descending: false)
        .snapshots(includeMetadataChanges: true) 
        .map((s) => s.docs.map((d) => PontoModel.fromFirestore(d)).toList());
  }

  Stream<List<PontoModel>> streamTodosPontosHoje(String empresaId) {
    final inicioDoDia = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _db.collection('pontos')
        .where('empresaId', isEqualTo: empresaId) // <--- CORRIGIDO
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDoDia))
        .orderBy('timestamp', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((s) => s.docs.map((d) => PontoModel.fromFirestore(d)).toList());
  }

  Stream<List<Map<String, dynamic>>> streamTodosUsuarios(String empresaId) {
    return _db.collection('usuarios')
        .where('empresaId', isEqualTo: empresaId) // <--- CORRIGIDO
        .snapshots(includeMetadataChanges: true)
        .map((s) => s.docs.map((d) => {...d.data(), 'uid': d.id}).toList());
  }

  Future<List<PontoModel>> obterPontosMes(String usuarioId, int mes, int ano) async {
    final inicio = DateTime(ano, mes, 1);
    final fim = (mes == 12) ? DateTime(ano + 1, 1, 1) : DateTime(ano, mes + 1, 1);
    
    final query = await _db.collection('pontos')
        .where('usuarioId', isEqualTo: usuarioId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('timestamp', isLessThan: Timestamp.fromDate(fim))
        .orderBy('timestamp', descending: false)
        .get(const GetOptions(source: Source.serverAndCache));
        
    return query.docs.map((d) => PontoModel.fromFirestore(d)).toList();
  }

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
    required String empresaId,
    required int mes,
    required int ano,
    required String assinaturaBase64,
  }) async {
    _db.collection('fechamentos').doc('${usuarioId}_${ano}_$mes').set({
      'usuarioId': usuarioId,
      'usuarioNome': usuarioNome,
      'empresaId': empresaId,
      'mes': mes,
      'ano': ano,
      'assinaturaBase64': assinaturaBase64,
      'assinadoEm': FieldValue.serverTimestamp(),
      'fechado': true,
    });
  }
}

final pontoServiceProvider = Provider((ref) => PontoService());

final monitorPontosProvider = StreamProvider.family<List<PontoModel>, String>((ref, empresaId) {
  return ref.watch(pontoServiceProvider).streamTodosPontosHoje(empresaId);
});