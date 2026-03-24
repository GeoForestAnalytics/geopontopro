// ============================================================
// pages/banco_horas_page.dart
// ============================================================
// Exibe o saldo acumulado de horas extras/faltantes por mês,
// com histórico dos últimos 6 meses e indicador do saldo total.
//
// Adicione na HomePage:
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => BancoHorasPage(user: user)));
// ============================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ponto_model.dart';
import '../models/user_model.dart';
import '../services/ponto_service.dart';

class _ResumoMes {
  final int mes;
  final int ano;
  final Duration totalTrabalhado;
  final Duration totalContratual;
  final int diasTrabalhados;

  _ResumoMes({
    required this.mes, required this.ano,
    required this.totalTrabalhado, required this.totalContratual,
    required this.diasTrabalhados,
  });

  Duration get saldo => totalTrabalhado - totalContratual;
  bool get positivo => saldo.inMinutes >= 0;
}

class BancoHorasPage extends StatefulWidget {
  final UserModel user;
  final int? cargaHorariaDiaria; // default: 8h

  const BancoHorasPage({super.key, required this.user, this.cargaHorariaDiaria});

  @override
  State<BancoHorasPage> createState() => _BancoHorasPageState();
}

class _BancoHorasPageState extends State<BancoHorasPage> {
  bool _carregando = true;
  List<_ResumoMes> _resumos = [];
  int _cargaHoraria = 8; // horas por dia

  @override
  void initState() {
    super.initState();
    _cargaHoraria = widget.cargaHorariaDiaria ?? 8;
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final service = PontoService();
    final now = DateTime.now();
    final resumos = <_ResumoMes>[];

    for (int i = 5; i >= 0; i--) {
      final data = DateTime(now.year, now.month - i, 1);
      final pontos = await service.obterPontosMes(widget.user.uid, data.month, data.year);
      if (pontos.isEmpty) continue;

      final porDia = <String, List<PontoModel>>{};
      for (final p in pontos) {
        final key = DateFormat('yyyy-MM-dd').format(p.timestamp);
        porDia.putIfAbsent(key, () => []).add(p);
      }

      Duration totalTrabalhado = Duration.zero;
      int diasTrabalhados = 0;

      for (final pts in porDia.values) {
        final d = _calcHorasDia(pts);
        if (d != Duration.zero) { totalTrabalhado += d; diasTrabalhados++; }
      }

      resumos.add(_ResumoMes(
        mes: data.month, ano: data.year,
        totalTrabalhado: totalTrabalhado,
        totalContratual: Duration(hours: diasTrabalhados * _cargaHoraria),
        diasTrabalhados: diasTrabalhados,
      ));
    }

    setState(() { _resumos = resumos; _carregando = false; });
  }

  Duration _calcHorasDia(List<PontoModel> pts) {
    final entrada    = pts.cast<PontoModel?>().firstWhere((p) => p?.tipo == TipoBatida.entrada,       orElse: () => null);
    final saida      = pts.cast<PontoModel?>().firstWhere((p) => p?.tipo == TipoBatida.saida,         orElse: () => null);
    final saidaAlm   = pts.cast<PontoModel?>().firstWhere((p) => p?.tipo == TipoBatida.saidaAlmoco,   orElse: () => null);
    final retornoAlm = pts.cast<PontoModel?>().firstWhere((p) => p?.tipo == TipoBatida.retornoAlmoco, orElse: () => null);
    if (entrada == null || saida == null) return Duration.zero;
    Duration total = saida.timestamp.difference(entrada.timestamp);
    if (saidaAlm != null && retornoAlm != null) {
      total -= retornoAlm.timestamp.difference(saidaAlm.timestamp);
    }
    return total;
  }

  Duration get _saldoTotal => _resumos.fold(
      Duration.zero, (acc, r) => acc + r.saldo);

  String _fmt(Duration d) {
    final h = d.inHours.abs();
    final m = d.inMinutes.abs().remainder(60);
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  final _meses = ['','Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];

  @override
  Widget build(BuildContext context) {
    final saldo = _saldoTotal;
    final positivo = saldo.inMinutes >= 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        title: const Text('Banco de Horas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _configurarCarga,
            tooltip: 'Carga horária',
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _resumos.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hourglass_empty, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Sem dados para calcular o banco de horas',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Card saldo total
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: positivo
                              ? [const Color(0xFF15803D), const Color(0xFF16A34A)]
                              : [const Color(0xFFDC2626), const Color(0xFFEF4444)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                          color: (positivo ? Colors.green : Colors.red).withOpacity(0.3),
                          blurRadius: 12, offset: const Offset(0, 4),
                        )],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            positivo ? Icons.trending_up : Icons.trending_down,
                            color: Colors.white, size: 36,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${positivo ? '+' : '-'}${_fmt(saldo)}',
                            style: const TextStyle(color: Colors.white, fontSize: 42,
                                fontWeight: FontWeight.w300, letterSpacing: -1),
                          ),
                          Text(
                            positivo ? 'Saldo positivo no banco de horas' : 'Horas a compensar',
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _resumoItem('Período', 'Últimos 6 meses'),
                              _resumoItem('Carga diária', '${_cargaHoraria}h/dia'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Gráfico de barras simples
                    const Text('Histórico mensal',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: _resumos.map((r) => _buildBarraMes(r)).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Detalhes por mês
                    const Text('Detalhes por mês',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._resumos.reversed.map((r) => _buildCardMes(r)),
                  ],
                ),
    );
  }

  Widget _resumoItem(String label, String valor) => Column(
    children: [
      Text(valor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
    ],
  );

  Widget _buildBarraMes(_ResumoMes r) {
    final maxH = _resumos.map((x) => x.saldo.inMinutes.abs()).reduce((a, b) => a > b ? a : b);
    final frac = maxH == 0 ? 0.0 : (r.saldo.inMinutes.abs() / maxH).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 36,
              child: Text('${_meses[r.mes]}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey))),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                Container(height: 20, decoration: BoxDecoration(
                    color: Colors.grey[100], borderRadius: BorderRadius.circular(4))),
                FractionallySizedBox(
                  widthFactor: frac,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: r.positivo ? const Color(0xFF15803D) : const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(
              '${r.positivo ? '+' : '-'}${_fmt(r.saldo)}',
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold,
                color: r.positivo ? const Color(0xFF15803D) : const Color(0xFFEF4444),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardMes(_ResumoMes r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: r.positivo ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  r.positivo ? Icons.trending_up : Icons.trending_down,
                  color: r.positivo ? const Color(0xFF15803D) : const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_meses[r.mes]} ${r.ano}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${r.diasTrabalhados} dias trabalhados',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${r.positivo ? '+' : '-'}${_fmt(r.saldo)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16,
                      color: r.positivo ? const Color(0xFF15803D) : const Color(0xFFEF4444),
                    ),
                  ),
                  Text('saldo', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _detalheHora('Trabalhado', _fmt(r.totalTrabalhado), Colors.grey[700]!),
              _detalheHora('Contratual', _fmt(r.totalContratual), Colors.grey[500]!),
              _detalheHora(
                r.positivo ? 'Extras' : 'Faltantes',
                _fmt(r.saldo),
                r.positivo ? const Color(0xFF15803D) : const Color(0xFFEF4444),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detalheHora(String label, String valor, Color cor) => Expanded(
    child: Column(
      children: [
        Text(valor, style: TextStyle(fontWeight: FontWeight.bold, color: cor)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    ),
  );

  void _configurarCarga() {
    int temp = _cargaHoraria;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Carga horária diária'),
        content: StatefulBuilder(
          builder: (ctx, setD) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$temp horas por dia',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Slider(
                value: temp.toDouble(),
                min: 4, max: 12, divisions: 8,
                activeColor: const Color(0xFF15803D),
                label: '$temp h',
                onChanged: (v) => setD(() => temp = v.round()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _cargaHoraria = temp);
              _carregar();
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }
}
