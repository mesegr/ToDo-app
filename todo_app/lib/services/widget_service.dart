import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/task.dart';

class WidgetService {
  // Actualizar el widget con las tareas del día
  static Future<void> updateWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = prefs.getString('tasks') ?? '[]';
      final List<dynamic> tasksList = json.decode(tasksJson);
      final tasks = tasksList.map((json) => Task.fromJson(json)).toList();

      // Obtener fecha de hoy
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Filtrar tareas de hoy
      final todayTasks = tasks.where((task) {
        final taskDate = DateTime(
          task.assignedTime.year,
          task.assignedTime.month,
          task.assignedTime.day,
        );
        return taskDate.isAtSameMomentAs(today);
      }).toList();

      // Separar tareas con y sin alarma
      final tasksWithAlarm = todayTasks.where((t) => t.hasAlarm).toList();
      final tasksWithoutAlarm = todayTasks.where((t) => !t.hasAlarm).toList();

      // Ordenar por hora
      tasksWithAlarm.sort((a, b) => a.assignedTime.compareTo(b.assignedTime));
      tasksWithoutAlarm.sort((a, b) => a.assignedTime.compareTo(b.assignedTime));

      // Crear JSON para las tareas
      final alarmTasksJson = tasksWithAlarm.map((t) => {
        'title': t.title,
        'time': '${t.assignedTime.hour.toString().padLeft(2, '0')}:${t.assignedTime.minute.toString().padLeft(2, '0')}',
      }).toList();

      final pendingTasksJson = tasksWithoutAlarm.map((t) => {
        'title': t.title,
        'time': '${t.assignedTime.hour.toString().padLeft(2, '0')}:${t.assignedTime.minute.toString().padLeft(2, '0')}',
      }).toList();

      // Guardar datos individuales para el widget (necesario para Android)
      await HomeWidget.saveWidgetData<String>(
        'alarm_tasks',
        json.encode(alarmTasksJson),
      );
      
      await HomeWidget.saveWidgetData<String>(
        'pending_tasks',
        json.encode(pendingTasksJson),
      );
      
      await HomeWidget.saveWidgetData<int>(
        'task_count',
        todayTasks.length,
      );

      // Actualizar el widget
      await HomeWidget.updateWidget(
        name: 'TodoWidgetProvider',
        androidName: 'TodoWidgetProvider',
        iOSName: 'TodoWidget',
      );

      print('✅ Widget actualizado con ${todayTasks.length} tareas');
    } catch (e) {
      print('❌ Error actualizando widget: $e');
    }
  }

  // Registrar callbacks para actualizar automáticamente
  static Future<void> registerCallbacks() async {
    // Callback cuando se toca el widget
    HomeWidget.widgetClicked.listen((Uri? uri) {
      if (uri != null) {
        print('Widget tocado: $uri');
        // Aquí puedes abrir la app en una pantalla específica
      }
    });
  }

  // Inicializar el widget
  static Future<void> initialize() async {
    await registerCallbacks();
    await updateWidget();
  }
}
