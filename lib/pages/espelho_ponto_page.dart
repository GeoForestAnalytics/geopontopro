// ============================================================
// pages/espelho_ponto_page.dart
// ============================================================
// Como usar: adicione no HistoricoPage um botão:
//
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => EspelhoPontoPage(
//       user: widget.user, mes: _mes, ano: _ano)));
// ============================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/ponto_service.dart';
import '../services/pdf_service.dart';

class EspelhoPontoPage extends StatefulWidget {
  final UserModel user;
  final int mes;
  final int ano;

  const EspelhoPontoPage({
    super.key, required this.user, required this.mes, required this.ano,
  });

  @override
  State<EspelhoPontoPage> createState() => _EspelhoPontoPageState();
}

class _EspelhoPontoPageState extends State<EspelhoPontoPage> {
  Uint8List? _pdfBytes;
  bool _gerando = false;
  String? _erro;

  final _meses = ['', 'Janeiro','Fevereiro','Março','Abril','Maio','Junho',
      'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];

  @override
  void initState() {
    super.initState();
    _gerar();
  }

  Future<void> _gerar() async {
    setState(() { _gerando = true; _erro = null; });
    try {
      final service = PontoService();
      final pontos = await service.obterPontosMes(
          widget.user.uid, widget.mes, widget.ano);

      final fechamento = await service.obterFechamento(
          widget.user.uid, widget.mes, widget.ano);

      final bytes = await PdfService().gerarEspelhoPonto(
        usuario: widget.user,
        pontos: pontos,
        mes: widget.mes,
        ano: widget.ano,
        assinaturaBase64: fechamento?.assinaturaBase64,
      );
      setState(() { _pdfBytes = bytes; _gerando = false; });
    } catch (e) {
      setState(() { _erro = e.toString(); _gerando = false; });
    }
  }

  String get _nomeArquivo =>
      'espelho_${widget.user.nome.replaceAll(' ', '_')}_'
      '${widget.mes.toString().padLeft(2, '0')}_${widget.ano}.pdf';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        title: Text('Espelho — ${_meses[widget.mes]} ${widget.ano}'),
        actions: [
          if (_pdfBytes != null) ...[
            IconButton(
              tooltip: 'Compartilhar',
              icon: const Icon(Icons.share),
              onPressed: () => PdfService().compartilharPdf(_pdfBytes!, _nomeArquivo),
            ),
            IconButton(
              tooltip: 'Imprimir',
              icon: const Icon(Icons.print),
              onPressed: () => PdfService().imprimirPdf(_pdfBytes!),
            ),
          ],
        ],
      ),
      body: _gerando
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF15803D)),
                  SizedBox(height: 16),
                  Text('Gerando espelho de ponto...'),
                ],
              ),
            )
          : _erro != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(_erro!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _gerar,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Barra de ações
                    Container(
                      color: const Color(0xFF15803D),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_nomeArquivo,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          ),
                          TextButton.icon(
                            onPressed: () => PdfService().compartilharPdf(_pdfBytes!, _nomeArquivo),
                            icon: const Icon(Icons.download, color: Colors.white70, size: 18),
                            label: const Text('Baixar', style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                    ),
                    // Visualizador do PDF
                    Expanded(
                      child: PdfPreview(
                        build: (_) async => _pdfBytes!,
                        allowPrinting: true,
                        allowSharing: true,
                        canChangePageFormat: false,
                        canChangeOrientation: false,
                        pdfFileName: _nomeArquivo,
                        loadingWidget: const Center(
                            child: CircularProgressIndicator(color: Color(0xFF15803D))),
                      ),
                    ),
                  ],
                ),
    );
  }
}
