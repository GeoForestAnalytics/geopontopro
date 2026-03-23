import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/ponto_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/ponto_service.dart';
import 'historico_page.dart';
import 'assinatura_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _registrando = false;

  Color _corTipo(TipoBatida tipo) {
    switch (tipo) {
      case TipoBatida.entrada:       return const Color(0xFF15803D);
      case TipoBatida.saidaAlmoco:   return const Color(0xFFF59E0B);
      case TipoBatida.retornoAlmoco: return const Color(0xFF3B82F6);
      case TipoBatida.saida:         return const Color(0xFFEF4444);
    }
  }

  IconData _iconeTipo(TipoBatida tipo) {
    switch (tipo) {
      case TipoBatida.entrada:       return Icons.login;
      case TipoBatida.saidaAlmoco:   return Icons.restaurant;
      case TipoBatida.retornoAlmoco: return Icons.replay;
      case TipoBatida.saida:         return Icons.logout;
    }
  }

  TipoBatida _proximaBatida(List<PontoModel> pontos) {
    final tipos = pontos.map((p) => p.tipo).toList();
    if (!tipos.contains(TipoBatida.entrada))       return TipoBatida.entrada;
    if (!tipos.contains(TipoBatida.saidaAlmoco))   return TipoBatida.saidaAlmoco;
    if (!tipos.contains(TipoBatida.retornoAlmoco)) return TipoBatida.retornoAlmoco;
    return TipoBatida.saida;
  }

  Future<void> _registrarPonto(UserModel user, TipoBatida tipo) async {
    setState(() => _registrando = true);
    try {
      await ref.read(pontoServiceProvider).registrarPonto(
        usuarioId: user.uid,
        usuarioNome: user.nome,
        tipo: tipo,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tipo.label} registrada com sucesso!'),
            backgroundColor: const Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
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
        if (user == null) return const Scaffold(body: Center(child: Text('Usuário não encontrado')));

        return Scaffold(
          backgroundColor: const Color(0xFFF0FDF4),
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('GeoPonto Pro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(user.empresa, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                icon: CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Text(user.nome[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                onSelected: (v) {
                  if (v == 'logout') ref.read(authServiceProvider).logout();
                  if (v == 'historico') {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => HistoricoPage(user: user)));
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(user.cargo, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'historico',
                      child: Row(children: [Icon(Icons.history), SizedBox(width: 8), Text('Histórico')])),
                  const PopupMenuItem(value: 'logout',
                      child: Row(children: [Icon(Icons.logout, color: Colors.red),
                          SizedBox(width: 8), Text('Sair', style: TextStyle(color: Colors.red))])),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: StreamBuilder<List<PontoModel>>(
            stream: ref.read(pontoServiceProvider).streamPontosHoje(user.uid),
            builder: (context, snapshot) {
              final pontos = snapshot.data ?? [];
              final proxima = _proximaBatida(pontos);
              final now = DateTime.now();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card data e hora
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF15803D), Color(0xFF16A34A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3),
                            blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(now),
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                          const SizedBox(height: 4),
                          StreamBuilder<DateTime>(
                            stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
                            builder: (_, s) => Text(
                              DateFormat('HH:mm:ss').format(s.data ?? now),
                              style: const TextStyle(color: Colors.white, fontSize: 42,
                                  fontWeight: FontWeight.w300, letterSpacing: -1),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.person, color: Colors.white70, size: 16),
                              const SizedBox(width: 4),
                              Text('${user.nome} • ${user.cargo}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botão principal de bater ponto
                    if (pontos.length < 4) ...[
                      GestureDetector(
                        onTap: _registrando ? null : () => _registrarPonto(user, proxima),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: _registrando ? Colors.grey[200] : _corTipo(proxima),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: _registrando ? [] : [
                              BoxShadow(color: _corTipo(proxima).withOpacity(0.4),
                                  blurRadius: 16, offset: const Offset(0, 6)),
                            ],
                          ),
                          child: Column(
                            children: [
                              if (_registrando)
                                const CircularProgressIndicator(color: Colors.white)
                              else ...[
                                Icon(_iconeTipo(proxima), color: Colors.white, size: 40),
                                const SizedBox(height: 8),
                                Text('Registrar ${proxima.label}',
                                    style: const TextStyle(color: Colors.white, fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                const Text('Toque para registrar com GPS',
                                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ] else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF15803D), size: 28),
                            SizedBox(width: 12),
                            Text('Jornada completa hoje!',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Linha do tempo do dia
                    const Text('Registros de hoje',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    if (pontos.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: const Center(
                          child: Column(
                            children: [
                              Icon(Icons.history_toggle_off, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Nenhum registro hoje', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    else
                      ...pontos.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final ponto = entry.value;
                        return _buildPontoCard(ponto, idx, pontos.length);
                      }),

                    const SizedBox(height: 20),

                    // Ações rápidas
                    Row(
                      children: [
                        Expanded(
                          child: _buildAcaoCard(
                            icon: Icons.history,
                            label: 'Histórico',
                            cor: const Color(0xFF3B82F6),
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => HistoricoPage(user: user))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildAcaoCard(
                            icon: Icons.draw,
                            label: 'Assinar Mês',
                            cor: const Color(0xFF8B5CF6),
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => AssinaturaPage(user: user))),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPontoCard(PontoModel ponto, int idx, int total) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _corTipo(ponto.tipo).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconeTipo(ponto.tipo), color: _corTipo(ponto.tipo), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(ponto.tipo.label,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    if (ponto.offline) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: const Text('OFFLINE',
                            style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(ponto.endereco,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(DateFormat('HH:mm').format(ponto.timestamp),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildAcaoCard({
    required IconData icon,
    required String label,
    required Color cor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cor.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: cor, size: 28),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: cor, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
