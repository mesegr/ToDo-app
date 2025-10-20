import 'dart:ui';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

// Nombre único para el worker de alarmas
const String alarmWorkerName = 'alarm_worker';

// Callback que se ejecuta en segundo plano cuando llega la hora de la alarma
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('🔔🔔🔔 Worker ejecutándose: $task');
    print('📋 Datos: $inputData');
    
    if (inputData != null) {
      final taskId = inputData['taskId'] as String?;
      final taskTitle = inputData['taskTitle'] as String?;
      
      if (taskId != null && taskTitle != null) {
        // INICIAR VIBRACIÓN CONTINUA E INTENSA PRIMERO
        // Patrón: 0.4 segundo ON, 0.05 segundos OFF, repetir indefinidamente
        bool? hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator == true) {
          // Vibración MUY agresiva, rápida y continua con intensidad máxima
          await Vibration.vibrate(
            pattern: [0, 400, 50], // 0.4 seg vibra, 0.05 seg pausa, repite
            intensities: [0, 255, 0], // Intensidad máxima (255)
            repeat: 0, // Repetir indefinidamente desde el índice 0
          );
          print('✅ Vibración continua ultra-rápida iniciada!');
        }
        
        // Inicializar notificaciones
        final FlutterLocalNotificationsPlugin notifications = 
            FlutterLocalNotificationsPlugin();

        await notifications.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          ),
        );

        // Crear canal de alarma de máxima prioridad
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'extreme_alarms',
          'Alarmas Extremas',
          description: 'Alarmas que no se pueden ignorar',
          importance: Importance.max,
          playSound: false,
          enableVibration: true,
          enableLights: true,
        );

        final android = notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (android != null) {
          await android.createNotificationChannel(channel);
        }

        // DISPARAR 1 NOTIFICACIÓN DE MÁXIMA PRIORIDAD
        // La vibración continua del sistema seguirá sonando en segundo plano
        await notifications.show(
          taskId.hashCode,
          '⏰ ALARMA: $taskTitle',
          '🔴 TOCA AQUÍ PARA DETENER LA VIBRACIÓN',
          NotificationDetails(
            android: AndroidNotificationDetails(
              'extreme_alarms',
              'Alarmas Extremas',
              channelDescription: 'Alarmas que no se pueden ignorar',
              importance: Importance.max,
              priority: Priority.max,
              enableVibration: false, // Desactivada para la notificación (vibración manejada por sistema)
              playSound: false,
              fullScreenIntent: true,
              category: AndroidNotificationCategory.alarm,
              visibility: NotificationVisibility.public,
              ongoing: true, // No se puede deslizar para eliminar
              autoCancel: false, // No se auto-cancela
              colorized: true,
              color: const Color(0xFFFF0000), // Rojo intenso
              ledColor: const Color(0xFFFF0000),
              ledOnMs: 1000,
              ledOffMs: 500,
            ),
          ),
          payload: taskId,
        );

        print('✅ Notificación disparada con vibración continua!');
        print('⚠️ LA VIBRACIÓN SEGUIRÁ HASTA QUE SE ABRA LA APP');
      }
    }
    
    return Future.value(true);
  });
}
