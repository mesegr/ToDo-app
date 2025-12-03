import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/task.dart';

class WidgetService {
  // Flag para evitar múltiples actualizaciones simultáneas
  static bool _isUpdating = false;

  // Actualizar el widget con el número de tareas de hoy
  static Future<void> updateWidget() async {
    // Evitar múltiples actualizaciones simultáneas
    if (_isUpdating) {
      debugPrint('⏳ Widget update ya en progreso, ignorando...');
      return;
    }

    _isUpdating = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = prefs.getString('tasks') ?? '[]';
      
      if (tasksJson.isEmpty || tasksJson == '[]') {
        // No hay tareas, establecer contadores en 0
        await HomeWidget.saveWidgetData<int>('task_count', 0);
        await HomeWidget.saveWidgetData<int>('pending_count', 0);
        await HomeWidget.saveWidgetData<int>('completed_count', 0);
        
        await HomeWidget.updateWidget(
          name: 'TodoWidgetProvider',
          androidName: 'TodoWidgetProvider',
        );
        
        debugPrint('✅ Widget actualizado: 0 tareas');
        return;
      }

      List<dynamic> tasksList = [];
      try {
        tasksList = json.decode(tasksJson);
      } catch (e) {
        debugPrint('❌ Error decodificando JSON: $e');
        tasksList = [];
      }

      if (tasksList.isEmpty) {
        // JSON decodificó a lista vacía
        await HomeWidget.saveWidgetData<int>('task_count', 0);
        await HomeWidget.saveWidgetData<int>('pending_count', 0);
        await HomeWidget.saveWidgetData<int>('completed_count', 0);
        
        await HomeWidget.updateWidget(
          name: 'TodoWidgetProvider',
          androidName: 'TodoWidgetProvider',
        );
        
        debugPrint('✅ Widget actualizado: JSON vacío');
        return;
      }

      List<Task> tasks = [];
      try {
        tasks = tasksList.map((json) => Task.fromJson(json as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('❌ Error creando tareas desde JSON: $e');
        tasks = [];
      }

      // Obtener fecha de hoy (ignorar hora para comparación)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Filtrar tareas de hoy
      final todayTasks = tasks.where((task) {
        try {
          final taskDate = DateTime(
            task.assignedTime.year,
            task.assignedTime.month,
            task.assignedTime.day,
          );
          return taskDate.isAtSameMomentAs(today);
        } catch (e) {
          debugPrint('⚠️ Error filtrando tarea: $e');
          return false;
        }
      }).toList();

      // Contar tareas completadas y pendientes
      final completedTasks = todayTasks.where((t) => t.isCompleted).length;
      final pendingTasks = todayTasks.length - completedTasks;

      debugPrint('📊 Datos del widget:');
      debugPrint('  - Total tareas hoy: ${todayTasks.length}');
      debugPrint('  - Completadas: $completedTasks');
      debugPrint('  - Pendientes: $pendingTasks');

      // Guardar datos para el widget
      await HomeWidget.saveWidgetData<int>('task_count', todayTasks.length);
      await HomeWidget.saveWidgetData<int>('pending_count', pendingTasks);
      await HomeWidget.saveWidgetData<int>('completed_count', completedTasks);

      // Actualizar el widget
      await HomeWidget.updateWidget(
        name: 'TodoWidgetProvider',
        androidName: 'TodoWidgetProvider',
      );

      debugPrint('✅ Widget actualizado correctamente');
    } catch (e) {
      debugPrint('❌ Error actualizando widget: $e');
    } finally {
      _isUpdating = false;
    }
  }

  // Inicializar el widget
  static Future<void> initialize() async {
    await updateWidget();
  }
}
