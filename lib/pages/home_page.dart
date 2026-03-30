import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/ponto_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/ponto_service.dart';
import '../services/notification_service.dart';
import 'login_page.dart';
import 'historico_page.dart';
import 'assinatura_page.dart';
import 'mapa_pontos_page.dart';
import 'banco_horas_page.dart';
import 'espelho_ponto_page.dart';
import 'configurar_lembretes_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _registrando = false;

  TipoBatida? _descobrirProximaBatida(List<PontoModel> pontos) {
    final tiposJaFeitos = pontos.map((p) => p.tipo).toList();
    if (!tiposJaFeitos.contains(TipoBatida.entrada)) return TipoBatida.entrada;
    if (!tiposJaFeitos.contains(TipoBatida.saidaAlmoco)) return TipoBatida.saidaAlmoco;
    if (!tiposJaFeitos.contains(TipoBatida.retornoAlmoco)) return TipoBatida.retornoAlmoco;
    if (!tiposJaFeitos.contains(TipoBatida.saida)) return TipoBatida.saida;
    return null; 
  }

  Color _getCorBatida(TipoBatida tipo) {
    switch (tipo) {
      case TipoBatida.entrada: return const Color(0xFF15803D);
      case TipoBatida.saidaAlmoco: return const Color(0xFFF59E0B);
      case TipoBatida.retornoAlmoco: return const Color(0xFF3B82F6);
      case TipoBatida.saida: return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  Future<void> _registrarPonto(UserModel user, TipoBatida tipo) async {
    setState(() => _registrando = true);
    try {
      await ref.read(pontoServiceProvider).registrarPonto(
        usuarioId: user.uid,
        usuarioNome: user.nome,
        empresaId: user.empresaId, // <--- CORREÇÃO: Envia o ID e não o Nome
        tipo: tipo,
      );
      if (!mounted) return;
      NotificationService().notificarPontoRegistrado(tipo.label, DateFormat('HH:mm').format(DateTime.now()));
    } finally {
      if (mounted) setState(() => _registrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erro: $e'))),
      data: (user) {
        if (user == null) return const LoginPage();

        return Scaffold(
          backgroundColor: const Color(0xFFF0FDF4),
          appBar: AppBar(
            title: const Text('GeoPonto Pro'), 
            actions: [IconButton(onPressed: () => ref.read(authServiceProvider).logout(), icon: const Icon(Icons.logout))]
          ),
          body: StreamBuilder<List<PontoModel>>(
            stream: ref.read(pontoServiceProvider).streamPontosHoje(user.uid),
            builder: (context, snapshot) {
              final pontos = snapshot.data ?? [];
              final proxima = _descobrirProximaBatida(pontos);
              final now = DateTime.now();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildRelogio(user),
                    const SizedBox(height: 20),
                    if (proxima != null)
                      _buildBotao(user, proxima)
                    else
                      const Card(child: ListTile(leading: Icon(Icons.check, color: Colors.green), title: Text('Dia Concluído'))),
                    const SizedBox(height: 25),
                    _buildGrid(user, now),
                    const SizedBox(height: 20),
                    ...pontos.map((p) => Card(child: ListTile(title: Text(p.tipo.label), trailing: Text(DateFormat('HH:mm').format(p.timestamp))))),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRelogio(UserModel user) => StreamBuilder<DateTime>(
    stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
    builder: (ctx, snap) {
      final h = snap.data ?? DateTime.now();
      return Container(
        width: double.infinity, padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF15803D), Color(0xFF16A34A)]), borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(h), style: const TextStyle(color: Colors.white70)),
          Text(DateFormat('HH:mm:ss').format(h), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
          Text(user.nome, style: const TextStyle(color: Colors.white)),
        ]),
      );
    }
  );

  Widget _buildBotao(UserModel user, TipoBatida proxima) => SizedBox(width: double.infinity, height: 75, child: ElevatedButton(
    style: ElevatedButton.styleFrom(backgroundColor: _getCorBatida(proxima), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    onPressed: _registrando ? null : () => _registrarPonto(user, proxima),
    child: _registrando ? const CircularProgressIndicator(color: Colors.white) : Text('BATER ${proxima.label.toUpperCase()}'),
  ));

  Widget _buildGrid(UserModel user, DateTime now) => Column(children: [
    Row(children: [
      Expanded(child: _acao(Icons.history, 'Histórico', Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoricoPage(user: user))))),
      const SizedBox(width: 10),
      Expanded(child: _acao(Icons.draw, 'Assinar', Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AssinaturaPage(user: user))))),
    ]),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: _acao(Icons.map, 'Mapa GPS', Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapaPontosPage(user: user))))),
      const SizedBox(width: 10),
      Expanded(child: _acao(Icons.access_time, 'Banco Horas', Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => BancoHorasPage(user: user))))),
    ]),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: _acao(Icons.picture_as_pdf, 'Relat. PDF', Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (_) => EspelhoPontoPage(user: user, mes: now.month, ano: now.year))))),
      const SizedBox(width: 10),
      Expanded(child: _acao(Icons.notifications_active, 'Lembretes', Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfigurarLembretesPage())))),
    ]),
  ]);

  Widget _acao(IconData i, String l, Color c, VoidCallback t) => InkWell(onTap: t, child: Container(padding: const EdgeInsets.symmetric(vertical: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.2))), child: Column(children: [Icon(i, color: c, size: 24), const SizedBox(height: 4), Text(l, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 11))])));
}