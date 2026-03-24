// ============================================================
// services/notification_service.dart (VERSÃO FINAL REVISADA)
// ============================================================

import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

// Handler de background para mensagens do Firebase (Push)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Mensagem em background: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _fcm = FirebaseMessaging.instance;
  final _localNotif = FlutterLocalNotificationsPlugin();

  // IDs para os lembretes
  static const int _idEntrada       = 1001;
  static const int _idAlmoco        = 1002;
  static const int _idRetornoAlmoco = 1003;
  static const int _idSaida         = 1004;

  // Canal de Notificação para Android
  static const _androidChannel = AndroidNotificationChannel(
    'geoponto_lembretes',
    'Lembretes de Ponto',
    description: 'Notificações agendadas para registro de ponto',
    importance: Importance.max, // Máxima para garantir que o celular desperte
    playSound: true,
    enableVibration: true,
  );

  // ─── Inicialização ──────────────────────────────────────────────────────────

  Future<void> inicializar() async {
    // 1. Configura fusos horários (Brasília)
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    // 2. Permissões Push (Firebase)
    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 3. Configura Canal Android
    final androidPlugin = _localNotif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);

    // 4. Inicializa Plugins de Notificação Local
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    await _localNotif.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // 5. Escuta mensagens em foreground
    FirebaseMessaging.onMessage.listen((msg) {
      final notif = msg.notification;
      if (notif != null) _exibirNotifLocal(notif.title ?? '', notif.body ?? '');
    });
  }

  // ─── Exibir Notificação Imediata ───────────────────────────────────────────

  Future<void> _exibirNotifLocal(String titulo, String corpo, {int id = 0}) async {
    await _localNotif.show(
      id,
      titulo,
      corpo,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }

  // ─── Lógica de Agendamento (Lembretes) ─────────────────────────────────────

  Future<void> agendarLembretes({
    required TimeOfDay horaEntrada,
    required TimeOfDay horaAlmoco,
    required TimeOfDay horaRetornoAlmoco,
    required TimeOfDay horaSaida,
  }) async {
    // Cancela tudo antes de reagendar
    await cancelarTodosLembretes();

    // Verificação Crítica: Android 12+ exige permissão de Alarme Exato
    if (Platform.isAndroid) {
      final androidPlugin = _localNotif
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      // Se a permissão for negada pelo sistema, o agendamento não funcionará
      final bool? canSchedule = await androidPlugin?.canScheduleExactNotifications();
      if (canSchedule == false) {
        debugPrint("ERRO: App não tem permissão para alarmes exatos no Android.");
        return; 
      }
    }

    // Agendamentos
    await _agendarDiario(id: _idEntrada, titulo: '⏰ Hora da Entrada', corpo: 'Não esqueça de bater o ponto!', hora: horaEntrada);
    await _agendarDiario(id: _idAlmoco, titulo: '🍽️ Saída Almoço', corpo: 'Bom apetite! Registre sua saída.', hora: horaAlmoco);
    await _agendarDiario(id: _idRetornoAlmoco, titulo: '🔄 Retorno Almoço', corpo: 'Hora de voltar ao trabalho.', hora: horaRetornoAlmoco);
    await _agendarDiario(id: _idSaida, titulo: '🏠 Fim do Expediente', corpo: 'Bom descanso! Registre sua saída.', hora: horaSaida);
    
    debugPrint("Lembretes agendados com sucesso.");
  }

  Future<void> _agendarDiario({
    required int id,
    required String titulo,
    required String corpo,
    required TimeOfDay hora,
  }) async {
    final agora = tz.TZDateTime.now(tz.local);
    var agendamento = tz.TZDateTime(
      tz.local, agora.year, agora.month, agora.day, hora.hour, hora.minute,
    );

    // Se o horário já passou hoje, agenda para amanhã
    if (agendamento.isBefore(agora)) {
      agendamento = agendamento.add(const Duration(days: 1));
    }

    await _localNotif.zonedSchedule(
      id,
      titulo,
      corpo,
      agendamento,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true, // Tenta acordar a tela do celular
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      // exactAllowWhileIdle: Permite tocar mesmo se o celular estiver em modo de economia
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repete diariamente no mesmo horário
    );
  }

  Future<void> cancelarTodosLembretes() async {
    await _localNotif.cancelAll();
    debugPrint("Todos os lembretes foram removidos.");
  }

  // ─── Notificação de Sucesso Imediata ───────────────────────────────────────

  Future<void> notificarPontoRegistrado(String tipoBatida, String horario) async {
    await _exibirNotifLocal(
      '✅ Ponto Registrado',
      '$tipoBatida às $horario com sucesso!',
      id: 2000,
    );
  }
}