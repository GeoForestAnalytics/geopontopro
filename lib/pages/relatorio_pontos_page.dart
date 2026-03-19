import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RelatorioPontosPage extends StatefulWidget {
  const RelatorioPontosPage({super.key});

  @override
  State<RelatorioPontosPage> createState() => _RelatorioPontosPageState();
}

class _RelatorioPontosPageState extends State<RelatorioPontosPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<QueryDocumentSnapshot> _registros = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _buscarHistorico();
  }

  Future<void> _buscarHistorico() async {
    if (!mounted) return;
    setState(() => _carregando = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // 1. Busca qual a empresa do gerente atual
      final userDoc = await _firestore.collection('usuarios').doc(user.uid).get();
      final empresaNome = userDoc.data()?['empresa'];

      if (empresaNome != null) {
        // 2. Busca o histórico filtrado pela empresa
        final querySnapshot = await _firestore
            .collection('registros_ponto')
            .where('empresa', isEqualTo: empresaNome)
            .orderBy('data_hora_dispositivo', descending: true)
            .get();

        setState(() {
          _registros = querySnapshot.docs;
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar relatório: $e");
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // Formata a data que vem do Firestore (String ISO ou Timestamp)
  String _formatarData(dynamic data) {
    try {
      if (data is String) {
        DateTime dt = DateTime.parse(data).toLocal();
        return DateFormat('dd/MM/yyyy HH:mm:ss').format(dt);
      } else if (data is Timestamp) {
        return DateFormat('dd/MM/yyyy HH:mm:ss').format(data.toDate().toLocal());
      }
      return "--/--/-- --:--";
    } catch (e) {
      return "Erro na data";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Espelho de Ponto Geral'),
        backgroundColor: Colors.green[900],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(onPressed: _buscarHistorico, icon: const Icon(Icons.refresh))
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _buscarHistorico,
              color: Colors.green[900],
              child: _registros.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _registros.length,
                      itemBuilder: (context, index) {
                        final dados = _registros[index].data() as Map<String, dynamic>;
                        final bool isEntrada = dados['tipo_batida'] == 'entrada';
                        final bool isOffline = dados['status'] == 'pendente'; // Exemplo de lógica offline

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[200]!)
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // Indicador visual de Entrada/Saída
                                Container(
                                  width: 4,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isEntrada ? Colors.green : Colors.orange,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // Dados do Ponto
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dados['usuario_nome'] ?? 'Colaborador',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Horário: ${_formatarData(dados['data_hora_dispositivo'])}',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Status e Tipo
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isEntrada ? Colors.green[50] : Colors.orange[50],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        dados['tipo_batida']?.toUpperCase() ?? 'PONTO',
                                        style: TextStyle(
                                          color: isEntrada ? Colors.green[800] : Colors.orange[800],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (isOffline)
                                      const Row(
                                        children: [
                                          Icon(Icons.cloud_off, size: 12, color: Colors.orange),
                                          SizedBox(width: 4),
                                          Text('OFFLINE', style: TextStyle(fontSize: 10, color: Colors.orange)),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('Nenhum registro encontrado.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}