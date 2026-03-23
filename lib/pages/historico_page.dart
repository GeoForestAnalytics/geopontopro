import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ponto_model.dart';
import '../models/user_model.dart';
import '../services/ponto_service.dart';
import 'assinatura_page.dart';

class HistoricoPage extends StatefulWidget {
  final UserModel user;
  const HistoricoPage({super.key, required this.user});
  @override
  State<HistoricoPage> createState() => _HistoricoPageState();
}

class _HistoricoPageState extends State<HistoricoPage> {
  late int _mes;
  late int _ano;
  bool _loading = true;
  List<PontoModel> _pontos = [];
  bool _fechado = false;

  @override
  void initState() {
    super.initState();
    _mes = DateTime.now().month;
    _ano = DateTime.now().year;
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final service = PontoService();
    final pontos = await service.obterPontosMes(widget.user.uid, _mes, _ano);
    final fechado = await service.verificarFechamentoExistente(widget.user.uid, _mes, _ano);
    setState(() {
      _pontos = pontos;
      _fechado = fechado;
      _loading = false;
    });
  }

  Map<String, List<PontoModel>> _agruparPorDia() {
    final Map<String, List<PontoModel>> grupos = {};
    for (final p in _pontos) {
      final key = DateFormat('yyyy-MM-dd').format(p.timestamp);
      grupos.putIfAbsent(key, () => []).add(p);
    }
    return Map.fromEntries(grupos.entries.toList().reversed);
  }

  Duration _calcularHorasTrabalhadas(List<PontoModel> pontosDia) {
    PontoModel? entrada = pontosDia.cast<PontoModel?>()
        .firstWhere((p) => p?.tipo == TipoBatida.entrada, orElse: () => null);
    PontoModel? saida = pontosDia.cast<PontoModel?>()
        .firstWhere((p) => p?.tipo == TipoBatida.saida, orElse: () => null);
    PontoModel? saidaAlmoco = pontosDia.cast<PontoModel?>()
        .firstWhere((p) => p?.tipo == TipoBatida.saidaAlmoco, orElse: () => null);
    PontoModel? retornoAlmoco = pontosDia.cast<PontoModel?>()
        .firstWhere((p) => p?.tipo == TipoBatida.retornoAlmoco, orElse: () => null);

    if (entrada == null || saida == null) return Duration.zero;

    Duration total = saida.timestamp.difference(entrada.timestamp);
    if (saidaAlmoco != null && retornoAlmoco != null) {
      total -= retornoAlmoco.timestamp.difference(saidaAlmoco.timestamp);
    }
    return total;
  }

  String _formatarDuracao(Duration d) {
    if (d == Duration.zero) return '--:--';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h.toString().padLeft(2, '0')}h${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final grupos = _agruparPorDia();
    final meses = ['', 'Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        title: const Text('Histórico de Pontos'),
        actions: [
          if (!_fechado)
            TextButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => AssinaturaPage(user: widget.user,
                      mes: _mes, ano: _ano))).then((_) => _carregar()),
              icon: const Icon(Icons.draw, color: Colors.white, size: 18),
              label: const Text('Assinar', style: TextStyle(color: Colors.white)),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Colors.white70, size: 18),
                  const SizedBox(width: 4),
                  Text('Assinado', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Seletor de mês
          Container(
            color: const Color(0xFF15803D),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      if (_mes == 1) { _mes = 12; _ano--; } else { _mes--; }
                    });
                    _carregar();
                  },
                ),
                Column(
                  children: [
                    Text('${meses[_mes]} $_ano',
                        style: const TextStyle(color: Colors.white, fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text('${_pontos.length} registros',
                        style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: () {
                    final now = DateTime.now();
                    if (_ano < now.year || (_ano == now.year && _mes < now.month)) {
                      setState(() {
                        if (_mes == 12) { _mes = 1; _ano++; } else { _mes++; }
                      });
                      _carregar();
                    }
                  },
                ),
              ],
            ),
          ),

          // Status do fechamento
          if (_fechado)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: const Color(0xFF166534),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified, color: Colors.white70, size: 16),
                  SizedBox(width: 6),
                  Text('Mês fechado e assinado digitalmente',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),

          // Lista de pontos
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : grupos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('Nenhum registro em ${meses[_mes]}',
                                style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: grupos.length,
                        itemBuilder: (_, idx) {
                          final key = grupos.keys.elementAt(idx);
                          final diaDate = DateTime.parse(key);
                          final pts = grupos[key]!;
                          final horas = _calcularHorasTrabalhadas(pts);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[200]!),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8)],
                            ),
                            child: Column(
                              children: [
                                // Cabeçalho do dia
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44, height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(DateFormat('d').format(diaDate),
                                                  style: const TextStyle(fontWeight: FontWeight.bold,
                                                      fontSize: 16, color: Color(0xFF15803D))),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              DateFormat("EEEE", 'pt_BR').format(diaDate).capitalize(),
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                            Text('${pts.length} registros',
                                                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      if (horas != Duration.zero)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(_formatarDuracao(horas),
                                              style: const TextStyle(fontWeight: FontWeight.bold,
                                                  color: Color(0xFF15803D), fontSize: 13)),
                                        ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                // Registros do dia
                                ...pts.map((p) => ListTile(
                                  dense: true,
                                  leading: Icon(_icone(p.tipo), color: _cor(p.tipo), size: 20),
                                  title: Text(p.tipo.label,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  subtitle: Text(p.endereco,
                                      style: const TextStyle(fontSize: 11),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (p.offline)
                                        const Icon(Icons.cloud_off, size: 14, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      Text(DateFormat('HH:mm').format(p.timestamp),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: (!_fechado && _pontos.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => AssinaturaPage(
                      user: widget.user, mes: _mes, ano: _ano)))
                  .then((_) => _carregar()),
              backgroundColor: const Color(0xFF8B5CF6),
              icon: const Icon(Icons.draw),
              label: const Text('Fechar e Assinar Mês'),
            )
          : null,
    );
  }

  Color _cor(TipoBatida t) {
    switch (t) {
      case TipoBatida.entrada:       return const Color(0xFF15803D);
      case TipoBatida.saidaAlmoco:   return const Color(0xFFF59E0B);
      case TipoBatida.retornoAlmoco: return const Color(0xFF3B82F6);
      case TipoBatida.saida:         return const Color(0xFFEF4444);
    }
  }

  IconData _icone(TipoBatida t) {
    switch (t) {
      case TipoBatida.entrada:       return Icons.login;
      case TipoBatida.saidaAlmoco:   return Icons.restaurant;
      case TipoBatida.retornoAlmoco: return Icons.replay;
      case TipoBatida.saida:         return Icons.logout;
    }
  }
}

extension StringExt on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
