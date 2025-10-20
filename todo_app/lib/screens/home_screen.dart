import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/repetition_type.dart';
import '../widgets/task_card.dart';
import '../services/notification_service.dart';
import '../helpers/miui_permissions_helper.dart';
import 'add_task_screen.dart';
import 'edit_task_screen.dart';
import 'alarm_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Lista de tareas (inicialmente vacía)
  List<Task> tasks = [];

  // Índice de la pestaña seleccionada
  int _selectedIndex = 0;

  // Clave para SharedPreferences
  static const String _tasksKey = 'tasks';

  // Timer para verificar alarmas
  Timer? _alarmCheckTimer;
  
  // Set para rastrear alarmas ya mostradas
  final Set<String> _shownAlarms = {};

  @override
  void initState() {
    super.initState();
    _loadTasks();

    // Configurar el callback para cuando se toque una notificación
    NotificationService().onNotificationTap = (String taskId) {
      // Mostrar la pantalla de alarma
      _showAlarmScreen(taskId);
    };

    // Iniciar verificación periódica de alarmas cada 5 segundos
    _alarmCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkPendingAlarms();
    });

    // Mostrar instrucciones MIUI la primera vez
    _showMiuiInstructionsIfNeeded();
  }

  @override
  void dispose() {
    _alarmCheckTimer?.cancel();
    super.dispose();
  }

  void _checkPendingAlarms() {
    final now = DateTime.now();
    
    for (final task in tasks) {
      // Saltar si ya se mostró esta alarma
      if (_shownAlarms.contains(task.id)) continue;
      
      final taskTime = task.assignedTime;
      final difference = now.difference(taskTime).inSeconds;
      
      // Si la alarma debería haber sonado en los últimos 60 segundos
      if (difference >= 0 && difference <= 60) {
        _shownAlarms.add(task.id);
        _showAlarmScreen(task.id);
        break; // Solo mostrar una alarma a la vez
      }
    }
  }

  Future<void> _showMiuiInstructionsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('miui_instructions_shown') ?? false;

    if (!shown && mounted) {
      // Esperar a que la pantalla esté lista
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        await MiuiPermissionsHelper.showMiuiInstructions(context);
        await prefs.setBool('miui_instructions_shown', true);
      }
    }
  }

  // Cargar tareas desde SharedPreferences
  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksJson = prefs.getString(_tasksKey);

    if (tasksJson != null) {
      final List<dynamic> tasksList = json.decode(tasksJson);
      setState(() {
        tasks = tasksList.map((taskJson) => Task.fromJson(taskJson)).toList();
        tasks.sort((a, b) => a.assignedTime.compareTo(b.assignedTime));
      });
    }
  }

  // Guardar tareas en SharedPreferences
  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> tasksJson =
        tasks.map((task) => task.toJson()).toList();
    await prefs.setString(_tasksKey, json.encode(tasksJson));
  }

  Future<void> _addTask() async {
    final Task? newTask = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTaskScreen()),
    );

    if (newTask != null) {
      setState(() {
        tasks.add(newTask);
        // Ordenar tareas por fecha/hora
        tasks.sort((a, b) => a.assignedTime.compareTo(b.assignedTime));
      });

      // Guardar cambios
      await _saveTasks();

      // Programar la notificación
      await NotificationService().scheduleNotification(newTask);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tarea "${newTask.title}" añadida'),
            backgroundColor: const Color(0xFF8B5CF6),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _editTask(Task task) async {
    final Task? updatedTask = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditTaskScreen(task: task)),
    );

    if (updatedTask != null) {
      setState(() {
        final index = tasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          tasks[index] = updatedTask;
          // Ordenar tareas por fecha/hora
          tasks.sort((a, b) => a.assignedTime.compareTo(b.assignedTime));
        }
      });

      // Guardar cambios
      await _saveTasks();

      // Re-programar la notificación con los nuevos datos
      await NotificationService().scheduleNotification(updatedTask);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tarea "${updatedTask.title}" actualizada'),
            backgroundColor: const Color(0xFF8B5CF6),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _deleteTask(Task task) async {
    // Guardar la tarea por si el usuario quiere deshacer
    final deletedTask = task;
    final deletedIndex = tasks.indexOf(task);

    setState(() {
      tasks.remove(task);
    });

    // Guardar cambios
    await _saveTasks();

    // Cancelar la notificación
    await NotificationService().cancelNotification(task.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tarea "${task.title}" eliminada'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Deshacer',
            textColor: Colors.white,
            onPressed: () async {
              setState(() {
                tasks.insert(deletedIndex, deletedTask);
              });
              // Guardar de nuevo al deshacer
              await _saveTasks();
              // Re-programar la notificación
              await NotificationService().scheduleNotification(deletedTask);
            },
          ),
        ),
      );
    }
  }

  // Método para eliminar tarea cuando se descarta la alarma (solo para tareas no repetitivas)
  void _dismissAlarm(String taskId) async {
    final task = tasks.firstWhere((t) => t.id == taskId);

    if (task.repetitionType == RepetitionType.none) {
      setState(() {
        tasks.removeWhere((t) => t.id == taskId);
      });

      await _saveTasks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tarea "${task.title}" completada y eliminada'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Mostrar pantalla de alarma
  void _showAlarmScreen(String taskId) {
    final task = tasks.firstWhere((t) => t.id == taskId);

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => AlarmScreen(task: task, onDismiss: _dismissAlarm),
      ),
    );
  }

  // Filtrar tareas según la pestaña seleccionada
  List<Task> _getFilteredTasks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<Task> filtered;

    switch (_selectedIndex) {
      case 0: // Hoy
        filtered =
            tasks.where((task) {
              final taskDate = DateTime(
                task.assignedTime.year,
                task.assignedTime.month,
                task.assignedTime.day,
              );
              return taskDate.isAtSameMomentAs(today) &&
                  task.repetitionType == RepetitionType.none;
            }).toList();
        break;
      case 1: // Otros días
        filtered =
            tasks.where((task) {
              final taskDate = DateTime(
                task.assignedTime.year,
                task.assignedTime.month,
                task.assignedTime.day,
              );
              return taskDate.isAfter(today) &&
                  task.repetitionType == RepetitionType.none;
            }).toList();
        break;
      case 2: // Repetitivas
        filtered =
            tasks.where((task) {
              return task.repetitionType != RepetitionType.none;
            }).toList();
        break;
      default:
        filtered = tasks;
    }

    // Ordenar por fecha y hora
    filtered.sort((a, b) => a.assignedTime.compareTo(b.assignedTime));
    return filtered;
  }

  String _getEmptyMessage() {
    switch (_selectedIndex) {
      case 0:
        return 'No hay tareas para hoy';
      case 1:
        return 'No hay tareas programadas';
      case 2:
        return 'No hay tareas repetitivas';
      default:
        return 'No hay tareas';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _getFilteredTasks();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Tareas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 40),
            onPressed: _addTask,
            tooltip: 'Añadir tarea',
          ),
        ],
      ),
      body:
          filteredTasks.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.task_alt, size: 100, color: Colors.grey[600]),
                    const SizedBox(height: 16),
                    Text(
                      _getEmptyMessage(),
                      style: TextStyle(fontSize: 20, color: Colors.grey[300]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Presiona el botón + para añadir una tarea',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredTasks.length,
                itemBuilder: (context, index) {
                  final task = filteredTasks[index];
                  return Dismissible(
                    key: Key(task.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete, color: Colors.white, size: 32),
                          SizedBox(height: 4),
                          Text(
                            'Eliminar',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (direction) {
                      _deleteTask(task);
                    },
                    child: TaskCard(task: task, onTap: () => _editTask(task)),
                  );
                },
              ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: const Color(0xFF2A2438),
        selectedItemColor: const Color(0xFF8B5CF6),
        unselectedItemColor: Colors.grey[500],
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.today), label: 'Hoy'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Otros días',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.repeat),
            label: 'Repetitivas',
          ),
        ],
      ),
    );
  }
}
