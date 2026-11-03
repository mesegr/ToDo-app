import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:workmanager/workmanager.dart';
import '../models/task.dart';
import '../models/repetition_type.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Callback que se ejecutará cuando se toque una notificación
  Function(String taskId)? onNotificationTap;

  Future<void> initialize() async {
    // Inicializar zonas horarias
    tz.initializeTimeZones();
    // Configurar la zona horaria de Madrid específicamente
    tz.setLocalLocation(tz.getLocation('Europe/Madrid'));

    debugPrint('🌍 Zona horaria configurada: ${tz.local.name}');
    debugPrint('🕐 Hora local actual: ${tz.TZDateTime.now(tz.local)}');

    // Crear el canal de notificaciones para Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'task_alarms', // id
      'Alarmas de Tareas', // nombre
      description: 'Notificaciones para recordatorios de tareas',
      importance: Importance.max,
      playSound: false,
      enableVibration: true,
    );

    // Crear el canal en el dispositivo
    final android =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (android != null) {
      await android.createNotificationChannel(channel);
    }

    // Configuración para Android
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Solicitar permisos en Android 13+
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    debugPrint('🔐 Solicitando permisos de notificación...');

    final android =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (android != null) {
      // Solicitar permiso de notificaciones
      final notificationPermission =
          await android.requestNotificationsPermission();
      debugPrint('📱 Permiso de notificaciones: $notificationPermission');

      if (notificationPermission != true) {
        debugPrint('⚠️ ADVERTENCIA: Permisos de notificación denegados');
      }

      // Solicitar permiso de alarmas exactas
      final alarmPermission = await android.requestExactAlarmsPermission();
      debugPrint('⏰ Permiso de alarmas exactas: $alarmPermission');

      if (alarmPermission != true) {
        debugPrint('⚠️ ADVERTENCIA: Permisos de alarmas exactas denegados');
        debugPrint(
          '💡 Ve a Configuración > Aplicaciones > Todo App > Alarmas y recordatorios',
        );
      }

      // Verificar si se pueden programar alarmas exactas
      final canSchedule = await android.canScheduleExactNotifications();
      debugPrint('✅ Puede programar alarmas exactas: $canSchedule');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null && onNotificationTap != null) {
      // Llamar al callback con el ID de la tarea
      onNotificationTap!(response.payload!);
    }
  }

  Future<void> scheduleNotification(Task task) async {
    // Cancelar notificación existente si hay
    await cancelNotification(task.id);

    final notificationId = task.id.hashCode;

    debugPrint('📅 Programando notificación para: ${task.title}');
    debugPrint('⏰ Fecha/Hora: ${task.assignedTime}');
    debugPrint('🔁 Tipo: ${task.repetitionType}');

    // Detalles de la notificación para Android
    const androidDetails = AndroidNotificationDetails(
      'task_alarms',
      'Alarmas de Tareas',
      channelDescription: 'Notificaciones para recordatorios de tareas',
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      playSound: false, // Sin sonido
      fullScreenIntent: true, // Pantalla completa
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    const details = NotificationDetails(android: androidDetails);

    final scheduledDate = tz.TZDateTime.from(task.assignedTime, tz.local);

    debugPrint('🕐 Hora actual: ${tz.TZDateTime.now(tz.local)}');
    debugPrint('🎯 Hora programada: $scheduledDate');

    if (task.repetitionType == RepetitionType.none) {
      // Tarea única
      if (scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
        debugPrint('✅ Programando notificación única...');

        // Calcular el delay en segundos para el Worker
        final now = DateTime.now();
        final delay = task.assignedTime.difference(now);

        // Programar Worker para que se ejecute en el momento exacto
        // Esto funciona incluso con la app cerrada
        await Workmanager().registerOneOffTask(
          'alarm_${task.id}',
          'alarmTask',
          initialDelay: delay,
          inputData: {'taskId': task.id, 'taskTitle': task.title},
        );

        debugPrint(
          '✅ Worker programado para ejecutarse en ${delay.inSeconds} segundos',
        );

        // También programar con notificaciones locales como respaldo
        try {
          await _notifications.zonedSchedule(
            notificationId,
            '⏰ ${task.title}',
            'Es hora de realizar tu tarea',
            scheduledDate,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: task.id,
          );

          debugPrint(
            '✅ Alarma programada con notificación local ID: $notificationId',
          );
        } catch (e) {
          debugPrint('❌ Error al programar notificación: $e');
        }
      } else {
        debugPrint(
          '⚠️ La fecha programada ya pasó. No se programa la notificación.',
        );
      }
    } else if (task.repetitionType == RepetitionType.daily) {
      // Tarea diaria
      await _scheduleDailyNotification(notificationId, task, details);
    } else if (task.repetitionType == RepetitionType.weekly) {
      // Tarea semanal - programar para cada día seleccionado
      await _scheduleWeeklyNotification(notificationId, task, details);
    } else if (task.repetitionType == RepetitionType.monthly) {
      // Tarea mensual
      await _scheduleMonthlyNotification(notificationId, task, details);
    }
  }

  Future<void> _scheduleDailyNotification(
    int notificationId,
    Task task,
    NotificationDetails details,
  ) async {
    var scheduledDate = tz.TZDateTime(
      tz.local,
      task.assignedTime.year,
      task.assignedTime.month,
      task.assignedTime.day,
      task.assignedTime.hour,
      task.assignedTime.minute,
    );

    // Si ya pasó hoy, programar para mañana
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      notificationId,
      '⏰ ${task.title}',
      'Tarea diaria',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: task.id,
    );
  }

  Future<void> _scheduleWeeklyNotification(
    int notificationId,
    Task task,
    NotificationDetails details,
  ) async {
    // Para cada día seleccionado, programar una notificación
    for (int i = 0; i < task.weeklyDays.length; i++) {
      final day = task.weeklyDays[i];
      final uniqueId = notificationId + i;

      var scheduledDate = _getNextWeekday(
        day.weekdayNumber,
        task.assignedTime.hour,
        task.assignedTime.minute,
      );

      await _notifications.zonedSchedule(
        uniqueId,
        '⏰ ${task.title}',
        'Tarea semanal - ${day.displayName}',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: task.id,
      );
    }
  }

  Future<void> _scheduleMonthlyNotification(
    int notificationId,
    Task task,
    NotificationDetails details,
  ) async {
    if (task.monthlyDay == null) return;

    var scheduledDate = tz.TZDateTime(
      tz.local,
      task.assignedTime.year,
      task.assignedTime.month,
      task.monthlyDay!,
      task.assignedTime.hour,
      task.assignedTime.minute,
    );

    // Si ya pasó este mes, programar para el próximo mes
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduledDate = tz.TZDateTime(
        tz.local,
        task.assignedTime.year,
        task.assignedTime.month + 1,
        task.monthlyDay!,
        task.assignedTime.hour,
        task.assignedTime.minute,
      );
    }

    await _notifications.zonedSchedule(
      notificationId,
      '⏰ ${task.title}',
      'Tarea mensual - Día ${task.monthlyDay}',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      payload: task.id,
    );
  }

  tz.TZDateTime _getNextWeekday(int weekday, int hour, int minute) {
    var now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Ajustar al día de la semana correcto
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Si ya pasó hoy, avanzar a la próxima semana
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    return scheduledDate;
  }

  Future<void> cancelNotification(String taskId) async {
    final notificationId = taskId.hashCode;

    // Cancelar Worker
    await Workmanager().cancelByUniqueName('alarm_$taskId');
    debugPrint('🚫 Cancelado Worker para tarea: $taskId');

    // Cancelar la notificación principal
    await _notifications.cancel(notificationId);
    debugPrint('🚫 Cancelada notificación ID: $notificationId');

    // Cancelar posibles notificaciones semanales adicionales (hasta 7 días)
    for (int i = 0; i < 7; i++) {
      await _notifications.cancel(notificationId + i);
    }
  }

  // Método para disparar alarma EXTREMA con 1 notificación
  Future<void> fireExtremeAlarm(String taskId, String taskTitle) async {
    debugPrint('🔥🔥🔥 DISPARANDO ALARMA EXTREMA PARA: $taskTitle');

    final notificationId = taskId.hashCode;

    // Detalles ultra-agresivos
    const androidDetails = AndroidNotificationDetails(
      'extreme_alarms',
      'Alarmas Extremas',
      channelDescription: 'Alarmas imposibles de ignorar',
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      playSound: false,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ongoing: true, // No se puede deslizar
      autoCancel: false,
    );

    const details = NotificationDetails(android: androidDetails);

    // DISPARAR 1 NOTIFICACIÓN DE MÁXIMA PRIORIDAD
    await _notifications.show(
      notificationId,
      '⏰ ALARMA: $taskTitle',
      '🔴 TOCA PARA DETENER LA VIBRACIÓN',
      details,
      payload: taskId,
    );

    debugPrint('✅ Notificación extrema disparada!');
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
