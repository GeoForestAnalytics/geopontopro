import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import '../models/user_model.dart';
import '../services/ponto_service.dart';

class AssinaturaPage extends StatefulWidget {
  final UserModel user;
  final int? mes;
  final int? ano;

  const AssinaturaPage({super.key, required this.user, this.mes, this.ano});

  @override
  State<AssinaturaPage> createState() => _AssinaturaPageState();
}

class _AssinaturaPageState extends State<AssinaturaPage> {
  late final SignatureController _controller;
  bool _salvando = false;
  bool _jaAssinado = false;
  bool _carregando = true;
  int? _totalRegistros;

  late int _mes;
  late int _ano;

  final _meses = ['', 'Janeiro','Fevereiro','Março','Abril','Maio','Junho',
      'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];

  @override
  void initState() {
    super.initState();
    _mes = widget.mes ?? DateTime.now().month;
    _ano = widget.ano ?? DateTime.now().year;
    _controller = SignatureController(
      penStrokeWidth: 2.5,
      penColor: const Color(0xFF1e293b),
      exportBackgroundColor: Colors.white,
    );
    _verificar();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verificar() async {
    final service = PontoService();
    final pontos = await service.obterPontosMes(widget.user.uid, _mes, _ano);
    final fechado = await service.verificarFechamentoExistente(widget.user.uid, _mes, _ano);
    setState(() {
      _totalRegistros = pontos.length;
      _jaAssinado = fechado;
      _carregando = false;
    });
  }

  Future<void> _assinar() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, faça sua assinatura antes de confirmar.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    // Confirmar
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Assinatura'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ao assinar, você confirma que os registros de '
                '${_meses[_mes]} $_ano estão corretos.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Esta ação não pode ser desfeita.',
                        style: TextStyle(fontSize: 12, color: Colors.amber)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _salvando = true);
    try {
      final Uint8List? imgBytes = await _controller.toPngBytes();
      if (imgBytes == null) throw Exception('Erro ao exportar assinatura');

      final base64 = base64Encode(imgBytes);
      
      // CORREÇÃO: Adicionado o parâmetro 'empresa' que é obrigatório no PontoService
      await PontoService().salvarAssinatura(
        usuarioId: widget.user.uid,
        usuarioNome: widget.user.nome,
        empresa: widget.user.empresa, // <--- Valor obtido do UserModel
        mes: _mes,
        ano: _ano,
        assinaturaBase64: base64,
      );

      if (mounted) {
        setState(() => _jaAssinado = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.verified, color: Colors.white),
                SizedBox(width: 8),
                Text('Mês assinado com sucesso!'),
              ],
            ),
            backgroundColor: const Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        title: Text('Fechar ${_meses[_mes]} $_ano'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _jaAssinado
              ? _buildJaAssinado()
              : _buildFormulario(),
    );
  }

  Widget _buildJaAssinado() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(48),
              ),
              child: const Icon(Icons.verified, size: 52, color: Color(0xFF15803D)),
            ),
            const SizedBox(height: 24),
            const Text('Mês Assinado!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${_meses[_mes]} $_ano já foi fechado e assinado digitalmente.',
                style: TextStyle(color: Colors.grey[600], fontSize: 15),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Voltar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Color(0xFF3B82F6)),
                    SizedBox(width: 8),
                    Text('Resumo do mês', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                _infoRow('Funcionário', widget.user.nome),
                _infoRow('Cargo', widget.user.cargo),
                _infoRow('Período', '${_meses[_mes]} $_ano'),
                _infoRow('Total de batidas', '$_totalRegistros registros'),
                _infoRow('Data/Hora da assinatura',
                    DateFormat("dd/MM/yyyy HH:mm", 'pt_BR').format(DateTime.now())),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Instrução
          const Text('Assinatura Digital',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Assine no espaço abaixo para confirmar que os registros do mês estão corretos.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 12),

          // Canvas de assinatura
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF8B5CF6), width: 2),
              boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.08),
                  blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                children: [
                  Signature(
                    controller: _controller,
                    height: 200,
                    backgroundColor: Colors.white,
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit, size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text('Assine acima', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Limpar
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _controller.clear(),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Limpar assinatura'),
              style: TextButton.styleFrom(foregroundColor: Colors.red[400]),
            ),
          ),
          const SizedBox(height: 8),

          // Aviso legal
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.gavel, color: Colors.amber, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ao assinar, você declara que os registros de ponto acima '
                    'são verídicos e de sua responsabilidade. Esta assinatura '
                    'tem validade jurídica nos termos da legislação vigente.',
                    style: TextStyle(fontSize: 11, color: Colors.amber),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Botão confirmar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _salvando ? null : _assinar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _salvando
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.verified),
              label: Text(_salvando ? 'Salvando...' : 'Confirmar e Fechar Mês',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Expanded(child: Text(valor,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}