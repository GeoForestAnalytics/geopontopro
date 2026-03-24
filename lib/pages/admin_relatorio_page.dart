import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/ponto_model.dart';


class AdminRelatorioPage extends StatefulWidget {
  const AdminRelatorioPage({super.key});
  @override
  State<AdminRelatorioPage> createState() => _AdminRelatorioPageState();
}

class _AdminRelatorioPageState extends State<AdminRelatorioPage> {
  late int _mes;
  late int _ano;
  bool _carregando = false;
  Map<String, List<PontoModel>> _porFuncionario = {};

  final _meses = ['', 'Janeiro','Fevereiro','Março','Abril','Maio','Junho',
      'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];

  @override
  void initState() {
    super.initState();
    _mes = DateTime.now().month;
    _ano = DateTime.now().year;
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final inicio = DateTime(_ano, _mes, 1);
    final fim = DateTime(_ano, _mes + 1, 1);

    final query = await FirebaseFirestore.instance
        .collection('pontos')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('timestamp', isLessThan: Timestamp.fromDate(fim))
        .orderBy('timestamp')
        .get();

    final pontos = query.docs.map(PontoModel.fromFirestore).toList();
    final Map<String, List<PontoModel>> agrupado = {};
    for (final p in pontos) {
      agrupado.putIfAbsent(p.usuarioNome, () => []).add(p);
    }
    setState(() {
      _porFuncionario = agrupado;
      _carregando = false;
    });
  }

  Duration _calcularTotalHoras(List<PontoModel> pontos) {
    final porDia = <String, List<PontoModel>>{};
    for (final p in pontos) {
      final key = DateFormat('yyyy-MM-dd').format(p.timestamp);
      porDia.putIfAbsent(key, () => []).add(p);
    }
    Duration total = Duration.zero;
    for (final pts in porDia.values) {
      final entrada = pts.cast<PontoModel?>()
          .firstWhere((p) => p?.tipo == TipoBatida.entrada, orElse: () => null);
      final saida = pts.cast<PontoModel?>()
          .firstWhere((p) => p?.tipo == TipoBatida.saida, orElse: () => null);
      final sAlm = pts.cast<PontoModel?>()
          .firstWhere((p) => p?.tipo == TipoBatida.saidaAlmoco, orElse: () => null);
      final rAlm = pts.cast<PontoModel?>()
          .firstWhere((p) => p?.tipo == TipoBatida.retornoAlmoco, orElse: () => null);

      if (entrada != null && saida != null) {
        Duration dia = saida.timestamp.difference(entrada.timestamp);
        if (sAlm != null && rAlm != null) {
          dia -= rAlm.timestamp.difference(sAlm.timestamp);
        }
        total += dia;
      }
    }
    return total;
  }

  String _formatHoras(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h${m.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Seletor de mês
        Container(
          color: const Color(0xFF15803D),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () {
                  setState(() { if (_mes == 1) { _mes = 12; _ano--; } else _mes--; });
                  _carregar();
                },
              ),
              Column(
                children: [
                  Text('${_meses[_mes]} $_ano',
                      style: const TextStyle(color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text('${_porFuncionario.length} funcionário(s)',
                      style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () {
                  final now = DateTime.now();
                  if (_ano < now.year || (_ano == now.year && _mes < now.month)) {
                    setState(() { if (_mes == 12) { _mes = 1; _ano++; } else _mes++; });
                    _carregar();
                  }
                },
              ),
            ],
          ),
        ),

        // Lista
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : _porFuncionario.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assessment, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('Sem dados em ${_meses[_mes]}',
                              style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _porFuncionario.length,
                      itemBuilder: (_, i) {
                        final nome = _porFuncionario.keys.elementAt(i);
                        final pts = _porFuncionario[nome]!;
                        final totalHoras = _calcularTotalHoras(pts);
                        final diasTrabalhados = <String>{};
                        for (final p in pts) {
                          diasTrabalhados.add(DateFormat('yyyy-MM-dd').format(p.timestamp));
                        }
                        final jaAssinou = false; // buscar do Firestore se necessário

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(0xFFDCFCE7),
                                      child: Text(nome[0].toUpperCase(),
                                          style: const TextStyle(
                                              color: Color(0xFF15803D), fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(nome,
                                              style: const TextStyle(fontWeight: FontWeight.w600)),
                                          Text('${pts.length} batidas • ${diasTrabalhados.length} dias',
                                              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(_formatHoras(totalHoras),
                                            style: const TextStyle(fontWeight: FontWeight.bold,
                                                color: Color(0xFF15803D), fontSize: 16)),
                                        const Text('trabalhadas',
                                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Barra de progresso
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Meta: 176h/mês',
                                            style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                        Text('${((totalHoras.inHours / 176) * 100).clamp(0, 100).toStringAsFixed(0)}%',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: (totalHoras.inHours / 176).clamp(0.0, 1.0),
                                      backgroundColor: Colors.grey[200],
                                      color: const Color(0xFF15803D),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
