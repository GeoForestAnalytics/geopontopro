import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  _initDb() async {
    String path = join(await getDatabasesPath(), 'geoponto_pro_offline.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          """CREATE TABLE pontos_pendentes(
            id INTEGER PRIMARY KEY AUTOINCREMENT, 
            usuario_id TEXT, 
            usuario_nome TEXT,
            empresa TEXT, 
            tipo_batida TEXT, 
            data_hora_dispositivo TEXT, 
            lat REAL, 
            lng REAL
          )""",
        );
      },
    );
  }

  // Salva no SQLite apenas se você quiser um controle manual extra
  Future<void> salvarPontoLocal({
    required String usuarioId,
    required String usuarioNome,
    required String empresa,
    required String tipoBatida,
    required double lat,
    required double lng,
  }) async {
    final dbClient = await db;
    await dbClient.insert('pontos_pendentes', {
      'usuario_id': usuarioId,
      'usuario_nome': usuarioNome,
      'empresa': empresa,
      'tipo_batida': tipoBatida,
      'data_hora_dispositivo': DateTime.now().toIso8601String(),
      'lat': lat,
      'lng': lng,
    });
  }

  Future<List<Map<String, dynamic>>> buscarPontosPendentes() async {
    final dbClient = await db;
    return await dbClient.query('pontos_pendentes');
  }

  Future<void> deletarPontoSincronizado(int id) async {
    final dbClient = await db;
    await dbClient.delete('pontos_pendentes', where: 'id = ?', whereArgs: [id]);
  }
}