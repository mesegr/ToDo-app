import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/task.dart';

class WidgetService {
  // Actualizar el widget con el número de tareas de hoy
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

      // Contar tareas sin alarma
      final tasksWithoutAlarm = todayTasks.where((t) => !t.hasAlarm).length;

      // Contar tareas con alarma de hoy
      final tasksWithAlarmToday = todayTasks.where((t) => t.hasAlarm).length;

      // Contar tareas con alarma totales (todas las fechas)
      final allTasksWithAlarm = tasks.where((t) => t.hasAlarm).length;

      // Guardar datos para el widget
      await HomeWidget.saveWidgetData<int>('tasks_without_alarm', tasksWithoutAlarm);
      await HomeWidget.saveWidgetData<int>('tasks_with_alarm_today', tasksWithAlarmToday);
      await HomeWidget.saveWidgetData<int>('all_tasks_with_alarm', allTasksWithAlarm);

      // Actualizar el widget
      await HomeWidget.updateWidget(
        name: 'TodoWidgetProvider',
        androidName: 'TodoWidgetProvider',
      );

      print('✅ Widget actualizado: ${todayTasks.length} tareas');
    } catch (e) {
      print('❌ Error actualizando widget: $e');
    }
  }

  // Inicializar el widget
  static Future<void> initialize() async {
    await updateWidget();
  }
}
