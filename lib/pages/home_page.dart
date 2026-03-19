import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _carregando = false;
  String _tipoPonto = 'entrada';
  String _currentTime = '';
  String _currentDate = '';
  late Timer _timer;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Atualiza o relógio a cada segundo
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateTime());
    _updateTime();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    if (!mounted) return;
    setState(() {
      _currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
      _currentDate = DateFormat('EEEE, dd ' 'de' ' MMMM', 'pt_BR').format(DateTime.now());
    });
  }

  Future<void> _registrarPonto() async {
    setState(() => _carregando = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Permissão de GPS negada';
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final user = _auth.currentUser;

      final userDoc = await _firestore.collection('usuarios').doc(user!.uid).get();
      final dadosUsuario = userDoc.data() as Map<String, dynamic>;

      await _firestore.collection('registros_ponto').add({
        'usuario_id': user.uid,
        'usuario_nome': dadosUsuario['nome'],
        'empresa': dadosUsuario['empresa'],
        'tipo_batida': _tipoPonto,
        'data_hora_dispositivo': DateTime.now().toIso8601String(),
        'data_hora_servidor': FieldValue.serverTimestamp(),
        'localizacao': GeoPoint(position.latitude, position.longitude),
      });

      _mostrarMensagem('Ponto de $_tipoPonto registrado com sucesso!', Colors.green);
    } catch (e) {
      _mostrarMensagem('Erro: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _mostrarMensagem(String msg, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: cor, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('PORTAL DO COLABORADOR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(onPressed: () => _auth.signOut(), icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER COM NOME E RELÓGIO
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.green[800],
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
              child: Column(
                children: [
                  Text("Olá, ${user?.email?.split('@')[0] ?? 'Colaborador'}", 
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300)),
                  const SizedBox(height: 15),
                  Text(_currentTime, style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                  Text(_currentDate, style: TextStyle(color: Colors.green[100], fontSize: 14)),
                ],
              ),
            ),

            // CARD DE AÇÃO (BATER PONTO)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, -25, 20, 0),
              child: Card(
                elevation: 8,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Text("REGISTRO DE PONTO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _buildTypeButton('entrada', 'Entrada', Icons.login_rounded)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTypeButton('saida', 'Saída', Icons.logout_rounded)),
                        ],
                      ),
                      const SizedBox(height: 25),
                      if (_carregando)
                        const CircularProgressIndicator()
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _tipoPonto == 'entrada' ? Colors.green[700] : Colors.orange[800],
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _registrarPonto,
                            child: Text('CONFIRMAR ${_tipoPonto.toUpperCase()}', 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // SEÇÃO DE HISTÓRICO
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Atividades de Hoje", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Icon(Icons.calendar_today_rounded, size: 18, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 15),
                  
                  // LISTA DE REGISTROS DO DIA
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('registros_ponto')
                        .where('usuario_id', isEqualTo: user?.uid)
                        .orderBy('data_hora_servidor', descending: true)
                        .limit(5)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: LinearProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(30),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.info_outline, color: Colors.grey),
                              SizedBox(height: 10),
                              Text("Nenhum registro hoje", style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          var doc = snapshot.data!.docs[index];
                          DateTime data = (doc['data_hora_servidor'] as Timestamp?)?.toDate() ?? DateTime.now();
                          bool isEntrada = doc['tipo_batida'] == 'entrada';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isEntrada ? Colors.green[50] : Colors.orange[50],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isEntrada ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: isEntrada ? Colors.green : Colors.orange[900],
                                  size: 20,
                                ),
                              ),
                              title: Text("Ponto de ${doc['tipo_batida'].toUpperCase()}", 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(DateFormat('HH:mm').format(data)),
                              trailing: const Icon(Icons.gps_fixed, size: 16, color: Colors.grey),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(String type, String label, IconData icon) {
    bool isSelected = _tipoPonto == type;
    return GestureDetector(
      onTap: () => setState(() => _tipoPonto = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? (type == 'entrada' ? Colors.green[50] : Colors.orange[50]) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? (type == 'entrada' ? Colors.green : Colors.orange) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? (type == 'entrada' ? Colors.green[800] : Colors.orange[900]) : Colors.grey),
            const SizedBox(height: 5),
            Text(label, style: TextStyle(
              color: isSelected ? (type == 'entrada' ? Colors.green[800] : Colors.orange[900]) : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}