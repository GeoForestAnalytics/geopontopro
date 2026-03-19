import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importação Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Importação Auth
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

class MonitoramentoPage extends StatefulWidget {
  const MonitoramentoPage({super.key});

  @override
  State<MonitoramentoPage> createState() => _MonitoramentoPageState();
}

class _MonitoramentoPageState extends State<MonitoramentoPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<QueryDocumentSnapshot> _registros = [];
  bool _carregando = true;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _buscarPontosRecentes();
  }

  Future<void> _buscarPontosRecentes() async {
    if (!mounted) return;
    setState(() => _carregando = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // 1. Busca os dados do gerente para saber a empresa
      final userDoc = await _firestore.collection('usuarios').doc(user.uid).get();
      final empresaNome = userDoc.data()?['empresa'];

      if (empresaNome != null) {
        // 2. Busca registros de ponto desta empresa
        // No Firebase, não precisamos de Joins complexos, pois salvamos o nome no registro
        final querySnapshot = await _firestore
            .collection('registros_ponto')
            .where('empresa', isEqualTo: empresaNome)
            .orderBy('data_hora_servidor', descending: true)
            .limit(50)
            .get();

        setState(() {
          _registros = querySnapshot.docs;
        });
      }
    } catch (e) {
      debugPrint("Erro ao monitorar mapa: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao carregar mapa: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // Conversão direta de GeoPoint para LatLng
  LatLng _converterGeoPoint(dynamic loc) {
    if (loc is GeoPoint) {
      return LatLng(loc.latitude, loc.longitude);
    }
    return const LatLng(-15.7942, -47.8821); // Centro do Brasil padrão
  }

  String _formatarHora(dynamic data) {
    if (data == null) return "--:--";
    // O Firebase retorna Timestamps
    DateTime dt = (data as Timestamp).toDate().toLocal();
    return DateFormat('HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoramento de Campo'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _buscarPontosRecentes, icon: const Icon(Icons.refresh))
        ],
      ),
      body: _carregando 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // MAPA (Parte superior)
              Expanded(
                flex: 2,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _registros.isNotEmpty 
                      ? _converterGeoPoint(_registros.first['localizacao']) 
                      : const LatLng(-15.7942, -47.8821),
                    initialZoom: 11,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.geoponto.pro',
                    ),
                    MarkerLayer(
                      markers: _registros.map((doc) {
                        final dados = doc.data() as Map<String, dynamic>;
                        final point = _converterGeoPoint(dados['localizacao']);
                        return Marker(
                          point: point,
                          width: 50,
                          height: 50,
                          child: GestureDetector(
                            onTap: () => _mostrarDetalhesPonto(dados),
                            child: const Icon(
                              Icons.location_on, 
                              color: Colors.red, 
                              size: 40,
                              shadows: [Shadow(color: Colors.black26, blurRadius: 10)],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              
              // CABEÇALHO DA LISTA
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))
                ),
                child: Row(
                  children: [
                    Icon(Icons.history, color: Colors.green[800]),
                    const SizedBox(width: 10),
                    const Text('Últimas atividades da equipe', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              
              // LISTA (Parte inferior)
              Expanded(
                flex: 1,
                child: Container(
                  color: Colors.white,
                  child: _registros.isEmpty 
                  ? const Center(child: Text("Nenhuma batida registrada hoje."))
                  : ListView.separated(
                      itemCount: _registros.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final dados = _registros[index].data() as Map<String, dynamic>;
                        final bool isEntrada = dados['tipo_batida'] == 'entrada';

                        return ListTile(
                          onTap: () {
                            _mapController.move(_converterGeoPoint(dados['localizacao']), 15);
                          },
                          leading: CircleAvatar(
                            backgroundColor: isEntrada ? Colors.green[50] : Colors.orange[50],
                            child: Icon(
                              isEntrada ? Icons.login : Icons.logout, 
                              color: isEntrada ? Colors.green[800] : Colors.orange[800],
                              size: 20,
                            ),
                          ),
                          title: Text(
                            dados['usuario_nome'] ?? 'Desconhecido',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Ponto de ${dados['tipo_batida']} às ${_formatarHora(dados['data_hora_servidor'])}'),
                          trailing: const Icon(Icons.gps_fixed, size: 16, color: Colors.grey),
                        );
                      },
                    ),
                ),
              ),
            ],
          ),
    );
  }

  void _mostrarDetalhesPonto(Map<String, dynamic> dados) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dados['usuario_nome'] ?? 'Colaborador', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            const SizedBox(height: 10),
            Text('Tipo: ${dados['tipo_batida'].toString().toUpperCase()}'),
            Text('Hora no Servidor: ${_formatarHora(dados['data_hora_servidor'])}'),
            Text('Hora no Dispositivo: ${dados['data_hora_dispositivo']}'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800], foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context),
                child: const Text('FECHAR'),
              ),
            )
          ],
        ),
      ),
    );
  }
}