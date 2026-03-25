import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../models/ponto_model.dart';
import '../models/user_model.dart';
import '../services/ponto_service.dart';

class MapaPontosPage extends StatefulWidget {
  final UserModel user;
  final int? mes;
  final int? ano;

  const MapaPontosPage({super.key, required this.user, this.mes, this.ano});

  @override
  State<MapaPontosPage> createState() => _MapaPontosPageState();
}

class _MapaPontosPageState extends State<MapaPontosPage> {
  bool _carregando = true;
  List<PontoModel> _pontos = [];
  PontoModel? _selecionado;
  late final MapController _mapController;

  late int _mes;
  late int _ano;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _mes = widget.mes ?? DateTime.now().month;
    _ano = widget.ano ?? DateTime.now().year;
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final service = PontoService();
    final pontos = await service.obterPontosMes(widget.user.uid, _mes, _ano);
    
    // Filtra apenas pontos com coordenadas válidas
    final comGPS = pontos.where((p) => p.latitude != 0 && p.longitude != 0).toList();
    
    if (mounted) {
      setState(() { 
        _pontos = comGPS; 
        _carregando = false; 
      });

      if (comGPS.isNotEmpty) {
        // Pequeno delay para garantir que o mapa carregou antes de mover
        Future.delayed(const Duration(milliseconds: 500), () => _centralizarMapa());
      }
    }
  }

  void _centralizarMapa() {
    if (_pontos.isEmpty) return;
    final lats = _pontos.map((p) => p.latitude);
    final lngs = _pontos.map((p) => p.longitude);
    final centerLat = (lats.reduce((a, b) => a + b)) / lats.length;
    final centerLng = (lngs.reduce((a, b) => a + b)) / lngs.length;
    _mapController.move(LatLng(centerLat, centerLng), 14);
  }

  Color _corTipo(TipoBatida t) {
    switch (t) {
      case TipoBatida.entrada:       return const Color(0xFF15803D);
      case TipoBatida.saidaAlmoco:   return const Color(0xFFF59E0B);
      case TipoBatida.retornoAlmoco: return const Color(0xFF3B82F6);
      case TipoBatida.saida:         return const Color(0xFFEF4444);
      case TipoBatida.observacao:    return Colors.blueGrey; // <--- ADICIONADO
    }
  }

  IconData _iconeTipo(TipoBatida t) {
    switch (t) {
      case TipoBatida.entrada:       return Icons.login;
      case TipoBatida.saidaAlmoco:   return Icons.restaurant;
      case TipoBatida.retornoAlmoco: return Icons.replay;
      case TipoBatida.saida:         return Icons.logout;
      case TipoBatida.observacao:    return Icons.info_outline; // <--- ADICIONADO
    }
  }

  @override
  Widget build(BuildContext context) {
    final meses = ['', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Mapa — ${widget.user.nome.split(' ')[0]}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Centralizar',
            onPressed: _centralizarMapa,
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _pontos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('Nenhum registro com GPS em ${meses[_mes]}',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(
                          _pontos.first.latitude, 
                          _pontos.first.longitude,
                        ),
                        initialZoom: 14,
                        onTap: (_, __) => setState(() => _selecionado = null),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'br.com.geoponto.app',
                        ),

                        // Linha conectando os pontos
                        PolylineLayer(
                          polylines: _buildPolylines(),
                        ),

                        // Marcadores
                        MarkerLayer(
                          markers: _pontos.map((p) {
                            final isSel = _selecionado?.id == p.id;
                            return Marker(
                              point: LatLng(p.latitude, p.longitude),
                              width: isSel ? 52 : 44,
                              height: isSel ? 52 : 44,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _selecionado = p);
                                  _mapController.move(LatLng(p.latitude, p.longitude), 15);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: _corTipo(p.tipo),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: isSel ? 3 : 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _corTipo(p.tipo).withOpacity(0.5),
                                        blurRadius: isSel ? 12 : 6,
                                      ),
                                    ],
                                  ),
                                  child: Icon(_iconeTipo(p.tipo), color: Colors.white, size: isSel ? 26 : 22),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),

                    // Legenda Superior Direita
                    Positioned(
                      top: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: TipoBatida.values.map((t) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 12, height: 12, decoration: BoxDecoration(color: _corTipo(t), shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text(t.label, style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                    ),

                    // Card do selecionado
                    if (_selecionado != null)
                      Positioned(
                        bottom: 16, left: 16, right: 16,
                        child: _buildCardSelecionado(_selecionado!),
                      ),
                  ],
                ),
    );
  }

  List<Polyline> _buildPolylines() {
    final Map<String, List<PontoModel>> porDia = {};
    for (final p in _pontos) {
      final key = DateFormat('yyyy-MM-dd').format(p.timestamp);
      porDia.putIfAbsent(key, () => []).add(p);
    }

    return porDia.values.map((pts) {
      pts.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return Polyline(
        points: pts.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        color: Colors.green.withOpacity(0.4),
        strokeWidth: 3,
      );
    }).toList();
  }

  Widget _buildCardSelecionado(PontoModel p) {
    final String dataFormatada = DateFormat("dd/MM/yyyy 'às' HH:mm", "pt_BR").format(p.timestamp);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12)],
        border: Border.all(color: _corTipo(p.tipo).withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: _corTipo(p.tipo).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(_iconeTipo(p.tipo), color: _corTipo(p.tipo), size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(p.tipo.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(dataFormatada, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  p.comentario.isNotEmpty ? p.comentario : p.endereco, 
                  style: TextStyle(color: Colors.grey[500], fontSize: 11), 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () => setState(() => _selecionado = null),
          ),
        ],
      ),
    );
  }
}