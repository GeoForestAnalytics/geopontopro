import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/ponto_model.dart';
import '../models/user_model.dart';

class ExportService {
  Future<void> exportarPontosCSV(UserModel usuario, List<PontoModel> pontos) async {
    List<List<dynamic>> rows = [];
    
    // MUDANÇA 1: Use cabeçalhos em inglês e sem espaços (opcional, mas ajuda o QGIS a detectar)
    // MUDANÇA 2: Latitude e Longitude devem ser as primeiras ou estar bem claras
    rows.add([
      "latitude",   // QGIS reconhece automaticamente
      "longitude",  // QGIS reconhece automaticamente
      "timestamp",
      "funcionario",
      "tipo",
      "endereco",
      "modo",
      "observacao"
    ]);

    for (var p in pontos) {
      rows.add([
        p.latitude,  // Mantém o ponto (.) como separador decimal (Padrão WGS84)
        p.longitude, // Mantém o ponto (.) como separador decimal (Padrão WGS84)
        DateFormat('yyyy-MM-dd HH:mm:ss').format(p.timestamp), // ISO 8601 é melhor para GIS
        usuario.nome,
        p.tipo.label,
        p.endereco,
        p.offline ? "Offline" : "Online",
        p.comentario,
      ]);
    }

    // MUDANÇA 3: No GIS, o padrão mundial é VÍRGULA (,). 
    // Se você usar PONTO E VÍRGULA (;), o Google Earth pode se perder.
    // DICA: Use vírgula para GIS, e ponto-e-vírgula se o foco for EXCEL BRASIL.
    String csvData = const ListToCsvConverter(fieldDelimiter: ',').convert(rows);

    final directory = await getTemporaryDirectory();
    final String fileName = "GEO_${usuario.nome.replaceAll(' ', '_')}.csv";
    final File file = File("${directory.path}/$fileName");
    
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(file.path)], text: 'Dados Geográficos WGS84');
  }
}