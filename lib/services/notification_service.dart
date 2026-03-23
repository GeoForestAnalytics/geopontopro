// ============================================================
// services/notification_service.dart
// ============================================================
// Dependências necessárias no pubspec.yaml:
//
//   firebase_messaging: ^14.9.0
//   flutter_local_notifications: ^17.1.2
//
// Android: adicionar em android/app/src/main/AndroidManifest.xml
//   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
//   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
//   Dentro de <application>:
//     <service android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
//              android:exported="false">
//       <intent-filter>
//         <action android:name="android.intent.action.BOOT_COMPLETED"/>
//       </intent-filter>
//     </service>
//
// iOS: em ios/Runner/AppDelegate.swift certifique que UNUserNotificationCenter
//      está configurado (gerado automaticamente pelo FlutterFire).
// ============================================================

import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

// Handler de background (deve estar no top-level, fora de qualquer classe)
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

  // IDs fixos para cada lembrete diário
  static const int _idEntrada       = 1001;
  static const int _idAlmoco        = 1002;
  static const int _idRetornoAlmoco = 1003;
  static const int _idSaida         = 1004;

  // Canal Android
  static const _androidChannel = AndroidNotificationChannel(
    'geoponto_lembretes',
    'Lembretes de Ponto',
    description: 'Notificações para lembrar de registrar o ponto',
    importance: Importance.high,
    playSound: true,
  );

  // ─── Inicialização ──────────────────────────────────────────────────────────

  Future<void> inicializar() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    // Permissões FCM
    final settings = await _fcm.requestPermission(
      alert: true, badge: true, sound: true,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    // Handler background
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Criar canal Android
    final androidPlugin = _localNotif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);

    // Inicializar plugin local
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotif.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Escutar mensagens em foreground
    FirebaseMessaging.onMessage.listen((msg) {
      final notif = msg.notification;
      if (notif != null) _exibirNotifLocal(notif.title ?? '', notif.body ?? '');
    });
  }

  // ─── Obter token FCM ────────────────────────────────────────────────────────

  Future<String?> obterToken() => _fcm.getToken();

  // ─── Exibir notificação local imediata ─────────────────────────────────────

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
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
    );
  }

  // ─── Agendar lembretes diários ──────────────────────────────────────────────

  Future<void> agendarLembretes({
    required TimeOfDay horaEntrada,
    required TimeOfDay horaAlmoco,
    required TimeOfDay horaRetornoAlmoco,
    required TimeOfDay horaSaida,
  }) async {
    await cancelarTodosLembretes();

    await _agendarDiario(
      id: _idEntrada,
      hora: horaEntrada,
      titulo: '⏰ Hora de registrar a Entrada!',
      corpo: 'Não esqueça de bater o ponto de entrada.',
    );
    await _agendarDiario(
      id: _idAlmoco,
      hora: horaAlmoco,
      titulo: '🍽️ Hora do Almoço!',
      corpo: 'Registre a saída para o almoço.',
    );
    await _agendarDiario(
      id: _idRetornoAlmoco,
      hora: horaRetornoAlmoco,
      titulo: '🔄 Retorno do Almoço',
      corpo: 'Lembre de registrar o retorno do almoço.',
    );
    await _agendarDiario(
      id: _idSaida,
      hora: horaSaida,
      titulo: '🏠 Hora de ir para casa!',
      corpo: 'Não esqueça de registrar a saída.',
    );
  }

  Future<void> _agendarDiario({
    required int id,
    required TimeOfDay hora,
    required String titulo,
    required String corpo,
  }) async {
    final agora = tz.TZDateTime.now(tz.local);
    var proximo = tz.TZDateTime(
      tz.local, agora.year, agora.month, agora.day, hora.hour, hora.minute,
    );
    if (proximo.isBefore(agora)) {
      proximo = proximo.add(const Duration(days: 1));
    }

    await _localNotif.zonedSchedule(
      id,
      titulo,
      corpo,
      proximo,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repete todo dia
    );
  }

  Future<void> cancelarTodosLembretes() => _localNotif.cancelAll();

  // ─── Notificação imediata após bater ponto ──────────────────────────────────

  Future<void> notificarPontoRegistrado(String tipoBatida, String horario) async {
    await _exibirNotifLocal(
      '✅ Ponto Registrado',
      '$tipoBatida registrada às $horario com sucesso!',
      id: 2000,
    );
  }
}
