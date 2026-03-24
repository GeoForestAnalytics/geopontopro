// ============================================================
// pages/configurar_lembretes_page.dart (ATUALIZADO)
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart'; // <--- OBRIGATÓRIO
import '../services/notification_service.dart';

class ConfigurarLembretesPage extends StatefulWidget {
  const ConfigurarLembretesPage({super.key});
  @override
  State<ConfigurarLembretesPage> createState() => _ConfigurarLembretesPageState();
}

class _ConfigurarLembretesPageState extends State<ConfigurarLembretesPage> {
  bool _ativo = false;
  bool _salvando = false;

  TimeOfDay _entrada       = const TimeOfDay(hour: 8,  minute: 0);
  TimeOfDay _almoco        = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _retornoAlmoco = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _saida         = const TimeOfDay(hour: 17, minute: 0);

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ativo = prefs.getBool('lembretes_ativo') ?? false;
      _entrada       = _fromString(prefs.getString('lembrete_entrada')       ?? '08:00');
      _almoco        = _fromString(prefs.getString('lembrete_almoco')        ?? '12:00');
      _retornoAlmoco = _fromString(prefs.getString('lembrete_retorno_almoco') ?? '13:00');
      _saida         = _fromString(prefs.getString('lembrete_saida')         ?? '17:00');
    });
  }

  TimeOfDay _fromString(String s) {
    final parts = s.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _toString(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ─── LÓGICA DE SALVAMENTO COM PERMISSÕES ───────────────────────────────────
  Future<void> _salvar() async {
    setState(() => _salvando = true);

    if (_ativo) {
      // 1. Pedir permissão de Notificação (Essencial para Android 13+)
      var statusNotif = await Permission.notification.status;
      if (statusNotif.isDenied) {
        statusNotif = await Permission.notification.request();
      }

      // 2. Pedir permissão de Alarme Exato (Essencial para Android 12+)
      // Nota: scheduleExactAlarm é o que faz o lembrete tocar no segundo certo
      var statusAlarme = await Permission.scheduleExactAlarm.status;
      if (statusAlarme.isDenied) {
        statusAlarme = await Permission.scheduleExactAlarm.request();
      }

      // Se o usuário negou as permissões, avisamos que pode não funcionar
      if (statusNotif.isPermanentlyDenied || statusAlarme.isPermanentlyDenied) {
        if (mounted) {
          _mostrarAvisoPermissao();
          setState(() => _salvando = false);
          return;
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lembretes_ativo', _ativo);
    await prefs.setString('lembrete_entrada',        _toString(_entrada));
    await prefs.setString('lembrete_almoco',         _toString(_almoco));
    await prefs.setString('lembrete_retorno_almoco', _toString(_retornoAlmoco));
    await prefs.setString('lembrete_saida',          _toString(_saida));

    final service = NotificationService();
    if (_ativo) {
      await service.agendarLembretes(
        horaEntrada: _entrada,
        horaAlmoco: _almoco,
        horaRetornoAlmoco: _retornoAlmoco,
        horaSaida: _saida,
      );
    } else {
      await service.cancelarTodosLembretes();
    }

    if (mounted) {
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_ativo ? 'Lembretes configurados e ativos!' : 'Lembretes desativados.'),
          backgroundColor: const Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _mostrarAvisoPermissao() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permissões Necessárias'),
        content: const Text(
          'Para que os lembretes funcionem, você precisa permitir "Notificações" e "Alarmes" nas configurações do seu celular.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () {
              openAppSettings(); // Abre as configs do Android direto no seu app
              Navigator.pop(ctx);
            },
            child: const Text('ABRIR CONFIGURAÇÕES'),
          ),
        ],
      ),
    );
  }

  Future<void> _escolherHora(TimeOfDay atual, ValueChanged<TimeOfDay> onSelecionado) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: atual,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) onSelecionado(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(title: const Text('Lembretes de Ponto')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Toggle principal
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _ativo ? const Color(0xFFDCFCE7) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.notifications_active,
                      color: _ativo ? const Color(0xFF15803D) : Colors.grey),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ativar lembretes',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text('Receba notificações diárias',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
                Switch(
                  value: _ativo,
                  onChanged: (v) => setState(() => _ativo = v),
                  activeColor: const Color(0xFF15803D),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (_ativo) ...[
            const Text('Horários dos lembretes',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Toque para alterar o horário de cada lembrete',
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            const SizedBox(height: 12),

            _lembreteTile(
              icon: Icons.login,
              cor: const Color(0xFF15803D),
              label: 'Entrada',
              hora: _entrada,
              onTap: () => _escolherHora(_entrada, (t) => setState(() => _entrada = t)),
            ),
            _lembreteTile(
              icon: Icons.restaurant,
              cor: const Color(0xFFF59E0B),
              label: 'Saída Almoço',
              hora: _almoco,
              onTap: () => _escolherHora(_almoco, (t) => setState(() => _almoco = t)),
            ),
            _lembreteTile(
              icon: Icons.replay,
              cor: const Color(0xFF3B82F6),
              label: 'Retorno Almoço',
              hora: _retornoAlmoco,
              onTap: () => _escolherHora(_retornoAlmoco, (t) => setState(() => _retornoAlmoco = t)),
            ),
            _lembreteTile(
              icon: Icons.logout,
              cor: const Color(0xFFEF4444),
              label: 'Saída',
              hora: _saida,
              onTap: () => _escolherHora(_saida, (t) => setState(() => _saida = t)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Os lembretes são repetidos automaticamente todos os dias úteis.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon: _salvando
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_salvando ? 'Salvando...' : 'Salvar configurações',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lembreteTile({
    required IconData icon,
    required Color cor,
    required String label,
    required TimeOfDay hora,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: cor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: cor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: cor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cor.withOpacity(0.3)),
              ),
              child: Text(
                '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontWeight: FontWeight.bold, color: cor, fontSize: 15),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}