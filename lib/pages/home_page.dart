import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../models/ponto_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/ponto_service.dart';
import '../services/notification_service.dart';
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

  // ─── LÓGICA DO BOTÃO INTELIGENTE ──────────────────────────────────────────
  // Decide qual batida deve ser feita agora com base no que já foi batido hoje
  TipoBatida _descobrirProximaBatida(List<PontoModel> pontos) {
    if (pontos.isEmpty) return TipoBatida.entrada;
    
    // Como os pontos vem ordenados por timestamp (do mais antigo para o novo no stream)
    // nós contamos quantos registros existem hoje.
    if (pontos.length == 1) return TipoBatida.saidaAlmoco;
    if (pontos.length == 2) return TipoBatida.retornoAlmoco;
    if (pontos.length == 3) return TipoBatida.saida;
    
    return TipoBatida.saida; // Caso tenha mais de 4, continua como saída por segurança
  }

  // ─── CORES DINÂMICAS PARA O BOTÃO ─────────────────────────────────────────
  Color _corBotao(TipoBatida tipo) {
    switch (tipo) {
      case TipoBatida.entrada: return const Color(0xFF15803D); // Verde
      case TipoBatida.saidaAlmoco: return const Color(0xFFF59E0B); // Laranja
      case TipoBatida.retornoAlmoco: return const Color(0xFF3B82F6); // Azul
      case TipoBatida.saida: return const Color(0xFFEF4444); // Vermelho
    }
  }

  void _mostrarErroGPS(String erro) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('GPS Necessário'),
        content: const Text('Ligue o GPS para registrar seu ponto com segurança.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Geolocator.openLocationSettings();
              Navigator.pop(ctx);
            },
            child: const Text('Configurar'),
          ),
        ],
      ),
    );
  }

  Future<void> _registrarPonto(UserModel user, TipoBatida tipo) async {
    setState(() => _registrando = true);
    try {
      await ref.read(pontoServiceProvider).registrarPonto(
        usuarioId: user.uid,
        usuarioNome: user.nome,
        empresa: user.empresa,
        tipo: tipo,
      );
      
      NotificationService().notificarPontoRegistrado(
        tipo.label, 
        DateFormat('HH:mm').format(DateTime.now())
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tipo.label} registrada!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (e == 'GPS_DESLIGADO' || e == 'PERMISSAO_NEGADA') {
        _mostrarErroGPS(e.toString());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
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
            title: const Text('GeoPonto Pro', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(onPressed: () => ref.read(authServiceProvider).logout(), icon: const Icon(Icons.logout))
            ],
          ),
          body: StreamBuilder<List<PontoModel>>(
            // Usamos o stream de pontos de hoje para alimentar o botão e a lista
            stream: ref.read(pontoServiceProvider).streamPontosHoje(user.uid),
            builder: (context, snapshot) {
              final pontos = snapshot.data ?? [];
              // AQUI ESTÁ A MÁGICA: O botão descobre sozinho qual é o próximo passo
              final proxima = _descobrirProximaBatida(pontos);
              final now = DateTime.now();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. RELÓGIO EM TEMPO REAL (Não trava mais)
                    _buildRelogioVivo(user),
                    const SizedBox(height: 20),

                    // 2. BOTÃO DINÂMICO
                    _buildBotaoAcao(user, proxima, pontos.length),
                    const SizedBox(height: 25),

                    // 3. LISTA DE REGISTROS DO DIA
                    const Text('Registros de Hoje', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    if (pontos.isEmpty)
                      const Card(child: ListTile(title: Text('Nenhum registro ainda', style: TextStyle(color: Colors.grey, fontSize: 13))))
                    else
                      ...pontos.map((p) => _buildMiniCardPonto(p)).toList(),

                    const SizedBox(height: 25),
                    const Text('Menu de Opções', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    _buildGridAcoes(user, now),
                    const SizedBox(height: 30),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ─── WIDGET: RELÓGIO QUE ATUALIZA SOZINHO ──────────────────────────────────
  Widget _buildRelogioVivo(UserModel user) {
    return StreamBuilder<DateTime>(
      // Cria um timer que "pinga" a cada 1 segundo
      stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
      builder: (context, snapshot) {
        final horaAtual = snapshot.data ?? DateTime.now();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF15803D), Color(0xFF16A34A)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(horaAtual), style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              Text(DateFormat('HH:mm:ss').format(horaAtual), style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold)),
              Text('${user.nome} • ${user.empresa}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            ],
          ),
        );
      }
    );
  }

  // ─── WIDGET: BOTÃO QUE MUDA DE COR E TEXTO ─────────────────────────────────
  Widget _buildBotaoAcao(UserModel user, TipoBatida proxima, int totalHoje) {
    if (totalHoje >= 4) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green)),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text('Jornada concluída hoje!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))],
        ),
      );
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _corBotao(proxima), // Cor muda conforme a batida
        minimumSize: const Size(double.infinity, 85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
      ),
      onPressed: _registrando ? null : () => _registrarPonto(user, proxima),
      child: _registrando 
        ? const CircularProgressIndicator(color: Colors.white)
        : Column(
            children: [
              Text('REGISTRAR ${proxima.label.toUpperCase()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Text('Toque para validar GPS e horário', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.white70)),
            ],
          ),
    );
  }

  Widget _buildMiniCardPonto(PontoModel p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.check_circle, color: _corBotao(p.tipo), size: 20),
        title: Text(p.tipo.label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(p.endereco, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
        trailing: Text(DateFormat('HH:mm').format(p.timestamp), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  Widget _buildGridAcoes(UserModel user, DateTime now) {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _buildAcaoCard(icon: Icons.history, label: 'Histórico', cor: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoricoPage(user: user))))),
          const SizedBox(width: 10),
          Expanded(child: _buildAcaoCard(icon: Icons.draw, label: 'Assinar Mês', cor: Colors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AssinaturaPage(user: user))))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _buildAcaoCard(icon: Icons.map, label: 'Mapa GPS', cor: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapaPontosPage(user: user))))),
          const SizedBox(width: 10),
          Expanded(child: _buildAcaoCard(icon: Icons.access_time, label: 'Banco Horas', cor: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BancoHorasPage(user: user))))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _buildAcaoCard(icon: Icons.picture_as_pdf, label: 'Espelho PDF', cor: Colors.red, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EspelhoPontoPage(user: user, mes: now.month, ano: now.year))))),
          const SizedBox(width: 10),
          Expanded(child: _buildAcaoCard(icon: Icons.notifications_active, label: 'Lembretes', cor: Colors.green, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfigurarLembretesPage())))),
        ]),
      ],
    );
  }

  Widget _buildAcaoCard({required IconData icon, required String label, required Color cor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cor.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: cor, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}