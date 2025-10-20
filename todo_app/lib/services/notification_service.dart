import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:vibration/vibration.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import '../models/task.dart';
import '../models/repetition_type.dart';

// Callback estático para AndroidAlarmManager
@pragma('vm:entry-point')
void alarmCallback(int id, Map<String, dynamic> params) async {
  print('🔔 Alarma disparada! ID: $id');
  print('📋 Params: $params');
  
  // Inicializar el plugin de notificaciones
  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
  
  await notifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  
  // Crear el canal
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'task_alarms',
    'Alarmas de Tareas',
    description: 'Notificaciones para recordatorios de tareas',
    importance: Importance.max,
    playSound: false,
    enableVibration: true,
  );
  
  final android = notifications.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (android != null) {
    await android.createNotificationChannel(channel);
  }
  
  // Mostrar la notificación
  await notifications.show(
    id,
    '⏰ ${params['title']}',
    'Es hora de realizar tu tarea',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'task_alarms',
        'Alarmas de Tareas',
        channelDescription: 'Notificaciones para recordatorios de tareas',
        importance: Importance.max,
        priority: Priority.max,
        enableVibration: true,
        playSound: false,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
      ),
    ),
    payload: params['taskId'],
  );
  
  // Vibrar
  await Vibration.vibrate(
    pattern: [0, 1000, 500, 1000, 500, 1000],
    intensities: [0, 255, 0, 255, 0, 255],
  );
  
  print('✅ Notificación y vibración activadas');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  // Callback que se ejecutará cuando se toque una notificación
  Function(String taskId)? onNotificationTap;

  Future<void> initialize() async {
    // Inicializar zonas horarias
    tz.initializeTimeZones();
    // Configurar la zona horaria de Madrid específicamente
    tz.setLocalLocation(tz.getLocation('Europe/Madrid'));
    
    print('🌍 Zona horaria configurada: ${tz.local.name}');
    print('🕐 Hora local actual: ${tz.TZDateTime.now(tz.local)}');
    
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
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (android != null) {
      await android.createNotificationChannel(channel);
    }
    
    // Configuración para Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuración para iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false, // Sin sonido
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Solicitar permisos en Android 13+
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    print('🔐 Solicitando permisos de notificación...');
    
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (android != null) {
      // Solicitar permiso de notificaciones
      final notificationPermission = await android.requestNotificationsPermission();
      print('📱 Permiso de notificaciones: $notificationPermission');
      
      if (notificationPermission != true) {
        print('⚠️ ADVERTENCIA: Permisos de notificación denegados');
      }
      
      // Solicitar permiso de alarmas exactas
      final alarmPermission = await android.requestExactAlarmsPermission();
      print('⏰ Permiso de alarmas exactas: $alarmPermission');
      
      if (alarmPermission != true) {
        print('⚠️ ADVERTENCIA: Permisos de alarmas exactas denegados');
        print('💡 Ve a Configuración > Aplicaciones > Todo App > Alarmas y recordatorios');
      }
      
      // Verificar si se pueden programar alarmas exactas
      final canSchedule = await android.canScheduleExactNotifications();
      print('✅ Puede programar alarmas exactas: $canSchedule');
    }

    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    
    if (ios != null) {
      await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: false,
      );
      print('🍎 Permisos de iOS solicitados');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null && onNotificationTap != null) {
      // Llamar al callback con el ID de la tarea
      onNotificationTap!(response.payload!);
      
      // Iniciar vibración intensa
      _startVibration();
    }
  }

  Future<void> _startVibration() async {
    // Verificar si el dispositivo puede vibrar
    bool? hasVibrator = await Vibration.hasVibrator();
    
    if (hasVibrator == true) {
      // Patrón de vibración intensa: vibrar 1s, pausa 0.5s, repetir
      // [espera, vibración, espera, vibración, ...]
      await Vibration.vibrate(
        pattern: [0, 1000, 500, 1000, 500, 1000],
        intensities: [0, 255, 0, 255, 0, 255], // Máxima intensidad
      );
    }
  }

  Future<void> stopVibration() async {
    await Vibration.cancel();
  }

  Future<void> scheduleNotification(Task task) async {
    // Cancelar notificación existente si hay
    await cancelNotification(task.id);

    final notificationId = task.id.hashCode;
    
    print('📅 Programando notificación para: ${task.title}');
    print('⏰ Fecha/Hora: ${task.assignedTime}');
    print('🔁 Tipo: ${task.repetitionType}');
    
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

    // Detalles para iOS
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final scheduledDate = tz.TZDateTime.from(task.assignedTime, tz.local);
    
    print('🕐 Hora actual: ${tz.TZDateTime.now(tz.local)}');
    print('🎯 Hora programada: $scheduledDate');

    if (task.repetitionType == RepetitionType.none) {
      // Tarea única
      if (scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
        print('✅ Programando notificación única...');
        
        // Programar con AndroidAlarmManager (más confiable en MIUI)
        final DateTime alarmTime = task.assignedTime;
        final Duration delay = alarmTime.difference(DateTime.now());
        
        print('⏱️ Programando AndroidAlarmManager con delay: ${delay.inSeconds} segundos');
        
        await AndroidAlarmManager.oneShotAt(
          alarmTime,
          notificationId,
          alarmCallback,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
          params: {
            'taskId': task.id,
            'title': task.title,
          },
        );
        
        // También programar con notificaciones locales como respaldo
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
        
        print('✅ Alarma programada con AndroidAlarmManager y notificación local con ID: $notificationId');
        
        // Mostrar una notificación de confirmación inmediata
        await _notifications.show(
          999999, // ID temporal
          '✓ Alarma programada',
          'Tu tarea "${task.title}" tiene una alarma para ${task.assignedTime.hour.toString().padLeft(2, '0')}:${task.assignedTime.minute.toString().padLeft(2, '0')}',
          details,
        );
      } else {
        print('⚠️ La fecha programada ya pasó. No se programa la notificación.');
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
    
    // Cancelar AndroidAlarmManager
    await AndroidAlarmManager.cancel(notificationId);
    print('🚫 Cancelada alarma de AndroidAlarmManager ID: $notificationId');
    
    // Cancelar la notificación principal
    await _notifications.cancel(notificationId);
    
    // Cancelar posibles notificaciones semanales adicionales (hasta 7 días)
    for (int i = 0; i < 7; i++) {
      await _notifications.cancel(notificationId + i);
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
