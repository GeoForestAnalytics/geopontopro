import 'dart:convert';
import 'dart:typed_data';
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

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Assinatura'),
        content: Text('Ao assinar, você confirma que os registros de ${_meses[_mes]} $_ano estão corretos.'),
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
      
      // CORREÇÃO: Nome do parâmetro alterado para 'empresaId'
      await PontoService().salvarAssinatura(
        usuarioId: widget.user.uid,
        usuarioNome: widget.user.nome,
        empresaId: widget.user.empresaId, // <--- CORRIGIDO AQUI
        mes: _mes,
        ano: _ano,
        assinaturaBase64: base64,
      );

      if (mounted) {
        setState(() => _jaAssinado = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mês assinado com sucesso!'), backgroundColor: Color(0xFF15803D)),
        );
        Navigator.pop(context);
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
      appBar: AppBar(title: Text('Fechar ${_meses[_mes]} $_ano')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _jaAssinado
              ? _buildJaAssinado()
              : _buildFormulario(),
    );
  }

  Widget _buildJaAssinado() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified, size: 80, color: Color(0xFF15803D)),
          const SizedBox(height: 16),
          const Text('Mês Assinado!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Voltar')),
        ],
      ),
    );
  }

  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Funcionário', widget.user.nome),
                _infoRow('Empresa', widget.user.empresaNome),
                _infoRow('Período', '${_meses[_mes]} $_ano'),
                _infoRow('Registros', '$_totalRegistros batidas'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Assinatura Digital', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green, width: 2)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Signature(controller: _controller, height: 200, backgroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(onPressed: () => _controller.clear(), icon: const Icon(Icons.delete_outline), label: const Text('Limpar')),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _salvando ? null : _assinar,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _salvando ? const CircularProgressIndicator(color: Colors.white) : const Text('CONFIRMAR FECHAMENTO', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey))), Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.bold)))]),
    );
  }
}