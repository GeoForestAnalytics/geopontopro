// ============================================================
// services/pdf_service.dart
// ============================================================
// Dependências necessárias no pubspec.yaml:
//
//   pdf: ^3.11.0
//   printing: ^5.12.0
//   path_provider: ^2.1.3
// ============================================================

import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/ponto_model.dart';
import '../models/user_model.dart';

class PdfService {
  static const _meses = [
    '', 'Janeiro','Fevereiro','Março','Abril','Maio','Junho',
    'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro',
  ];

  // ─── Gerar bytes do PDF ───────────────────────────────────────────────────

  Future<Uint8List> gerarEspelhoPonto({
    required UserModel usuario,
    required List<PontoModel> pontos,
    required int mes,
    required int ano,
    String? assinaturaBase64,
  }) async {
    final pdf = pw.Document();

    // Agrupar por dia
    final Map<String, List<PontoModel>> porDia = {};
    for (final p in pontos) {
      final key = DateFormat('yyyy-MM-dd').format(p.timestamp);
      porDia.putIfAbsent(key, () => []).add(p);
    }
    final diasOrdenados = porDia.keys.toList()..sort();

    // Calcular totais
    Duration totalHoras = Duration.zero;
    int totalDias = 0;
    for (final pts in porDia.values) {
      final d = _calcularHorasDia(pts);
      if (d != Duration.zero) { totalHoras += d; totalDias++; }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildHeader(usuario, mes, ano),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          _buildInfoFuncionario(usuario, mes, ano, totalDias, totalHoras),
          pw.SizedBox(height: 16),
          _buildTabelaPontos(diasOrdenados, porDia),
          pw.SizedBox(height: 16),
          _buildResumoHoras(totalHoras, totalDias),
          if (assinaturaBase64 != null) ...[
            pw.SizedBox(height: 24),
            _buildAssinatura(usuario, assinaturaBase64),
          ] else ...[
            pw.SizedBox(height: 40),
            _buildCampoAssinatura(usuario),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  // ─── Widgets do PDF ───────────────────────────────────────────────────────

  pw.Widget _buildHeader(UserModel u, int mes, int ano) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.green800, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('ESPELHO DE PONTO',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800)),
              pw.Text('${_meses[mes]} $ano',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            ],
          ),
          pw.Text('GeoPonto Pro',
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey500)),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Gerado em ${DateFormat("dd/MM/yyyy 'às' HH:mm").format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
          pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
        ],
      ),
    );
  }

  pw.Widget _buildInfoFuncionario(UserModel u, int mes, int ano, int dias, Duration total) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.green200),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoLinha('Funcionário', u.nome),
                _infoLinha('Cargo', u.cargo),
                // CORREÇÃO: Usando 'empresaNome' em vez de 'empresa'
                _infoLinha('Empresa', u.empresaNome),
                _infoLinha('E-mail', u.email),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoLinha('Período', '${_meses[mes]} $ano'),
                _infoLinha('Dias trabalhados', '$dias dias'),
                _infoLinha('Total de horas', _formatarDuracao(total)),
                _infoLinha('Horas contratuais', '176h00 (22 dias × 8h)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _infoLinha(String label, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text('$label:',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ),
          pw.Expanded(
            child: pw.Text(valor,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTabelaPontos(List<String> dias, Map<String, List<PontoModel>> porDia) {
    // Cabeçalho
    final headerStyle = pw.TextStyle(
        fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
    final cellStyle = const pw.TextStyle(fontSize: 9);
    final cellStyleMuted = const pw.TextStyle(fontSize: 8, color: PdfColors.grey600);

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.2),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
        5: const pw.FlexColumnWidth(1.5),
        6: const pw.FlexColumnWidth(2.5),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.green800),
          children: [
            _cell('Data', headerStyle),
            _cell('Entrada', headerStyle),
            _cell('Saída Alm.', headerStyle),
            _cell('Retorno', headerStyle),
            _cell('Saída', headerStyle),
            _cell('Total', headerStyle),
            _cell('Local', headerStyle),
          ],
        ),
        // Linhas de dados
        ...dias.asMap().entries.map((entry) {
          final idx = entry.key;
          final key = entry.value;
          final pts = porDia[key]!;
          final diaDate = DateTime.parse(key);
          final diaSemana = DateFormat('EEE', 'pt_BR').format(diaDate);
          final diaFormatado = DateFormat('dd/MM').format(diaDate);
          final totalDia = _calcularHorasDia(pts);
          final hExtra = totalDia - const Duration(hours: 8);
          final isExtra = hExtra.inMinutes > 0;

          PontoModel? pEntrada       = pts.cast<PontoModel?>().firstWhere((p) => p?.tipo == TipoBatida.entrada,       orElse: () => null);
          PontoModel? pSaidaAlm      = pts.cast<PontoModel?>().firstWhere((p) => p?.tipo == TipoBatida.saidaAlmoco,   orElse: () => null);
          PontoModel? pRetornoAlm    = pts.cast<PontoModel?>().firstWhere((p) => p?.tipo == TipoBatida.retornoAlmoco, orElse: () => null);
          PontoModel? pSaida         = pts.cast<PontoModel?>().firstWhere((p) => p?.tipo == TipoBatida.saida,         orElse: () => null);

          final bg = idx.isEven ? PdfColors.white : PdfColors.grey50;
          final totalColor = isExtra ? PdfColors.green700 : PdfColors.black;

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              _cell('$diaFormatado $diaSemana'.toUpperCase(), cellStyle),
              _cell(pEntrada    != null ? DateFormat('HH:mm').format(pEntrada.timestamp)    : '--:--', cellStyle),
              _cell(pSaidaAlm   != null ? DateFormat('HH:mm').format(pSaidaAlm.timestamp)   : '--:--', cellStyle),
              _cell(pRetornoAlm != null ? DateFormat('HH:mm').format(pRetornoAlm.timestamp) : '--:--', cellStyle),
              _cell(pSaida      != null ? DateFormat('HH:mm').format(pSaida.timestamp)      : '--:--', cellStyle),
              _cell(totalDia != Duration.zero ? _formatarDuracao(totalDia) : '--:--',
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: totalColor)),
              _cell(pEntrada?.endereco.split(',').first ?? '', cellStyleMuted, align: pw.TextAlign.left),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _cell(String text, pw.TextStyle style,
      {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(text, style: style, textAlign: align),
    );
  }

  pw.Widget _buildResumoHoras(Duration total, int dias) {
    final hExtra = total - Duration(hours: dias * 8);
    final isPositivo = hExtra.inMinutes >= 0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.green800, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _resumoItem('Dias Trabalhados', '$dias dias'),
          _resumoItem('Total Trabalhado', _formatarDuracao(total)),
          _resumoItem('Meta Contratual', '${(dias * 8)}h00'),
          _resumoItem(
            isPositivo ? 'Horas Extras' : 'Horas Faltantes',
            _formatarDuracao(hExtra.abs()),
            color: isPositivo ? PdfColors.green700 : PdfColors.red700,
          ),
        ],
      ),
    );
  }

  pw.Widget _resumoItem(String label, String valor, {PdfColor color = PdfColors.black}) {
    return pw.Column(
      children: [
        pw.Text(valor,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ],
    );
  }

  pw.Widget _buildAssinatura(UserModel u, String base64) {
    final imgBytes = base64Decode(base64);
    final img = pw.MemoryImage(imgBytes);

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Assinatura Digital do Funcionário',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Image(img, height: 80)),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'Assinado digitalmente por ${u.nome} em '
              '${DateFormat("dd/MM/yyyy 'às' HH:mm").format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCampoAssinatura(UserModel u) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: PdfColors.black),
        pw.SizedBox(height: 4),
        pw.Text('${u.nome} — ${u.cargo}',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text('Declaro que os registros acima são verídicos.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Text(
          'Data: ____/____/________     Assinatura: _________________________________',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Duration _calcularHorasDia(List<PontoModel> pts) {
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

  String _formatarDuracao(Duration d) {
    final h = d.inHours.abs();
    final m = d.inMinutes.abs().remainder(60);
    return '${h.toString().padLeft(2, '0')}h${m.toString().padLeft(2, '0')}';
  }

  // ─── Compartilhar / Imprimir ──────────────────────────────────────────────

  Future<void> compartilharPdf(Uint8List bytes, String nomeArquivo) async {
    await Printing.sharePdf(bytes: bytes, filename: nomeArquivo);
  }

  Future<void> imprimirPdf(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }
}