import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/repetition_type.dart';
import '../widgets/task_card.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
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

  // Variables para el sistema de filtros
  String _sortOrder = 'asc'; // 'asc' o 'desc'
  String? _filterByDay; // null, 'today', 'tomorrow', 'week', 'month'
  bool _showFilterMenu = false;

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
      // Solo verificar tareas que tienen alarma activada
      if (!task.hasAlarm) continue;
      
      // Saltar si ya se mostró esta alarma
      if (_shownAlarms.contains(task.id)) continue;
      
      final taskTime = task.assignedTime;
      final difference = now.difference(taskTime).inSeconds;
      
      // Si la alarma debería haber sonado en los últimos 60 segundos
      if (difference >= 0 && difference <= 60) {
        _shownAlarms.add(task.id);
        
        // DISPARAR ALARMA EXTREMA CON 10 NOTIFICACIONES
        NotificationService().fireExtremeAlarm(task.id, task.title);
        
        // Mostrar pantalla de alarma
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
    
    // Actualizar el widget después de guardar las tareas
    await WidgetService.updateWidget();
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

      // Programar la notificación solo si la tarea tiene alarma
      if (newTask.hasAlarm) {
        await NotificationService().scheduleNotification(newTask);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newTask.hasAlarm
                ? 'Tarea "${newTask.title}" añadida'
                : 'Pendiente "${newTask.title}" creado',
            ),
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

      // Re-programar la notificación con los nuevos datos solo si tiene alarma
      if (updatedTask.hasAlarm) {
        await NotificationService().scheduleNotification(updatedTask);
      } else {
        // Si se desactivó la alarma, cancelar cualquier notificación existente
        await NotificationService().cancelNotification(updatedTask.id);
      }

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

    // Cancelar la notificación solo si tenía alarma
    if (task.hasAlarm) {
      await NotificationService().cancelNotification(task.id);
    }

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
              // Re-programar la notificación solo si tiene alarma
              if (deletedTask.hasAlarm) {
                await NotificationService().scheduleNotification(deletedTask);
              }
            },
          ),
        ),
      );
    }
  }

  // Método para marcar tarea como completada/no completada
  void _toggleTaskComplete(Task task) async {
    setState(() {
      final index = tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        tasks[index] = task.copyWith(isCompleted: !task.isCompleted);
      }
    });

    // Guardar cambios
    await _saveTasks();
  }

  // Método para eliminar tarea cuando se descarta la alarma (solo para tareas no repetitivas)
  void _dismissAlarm(String taskId) async {
    try {
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
    } catch (e) {
      // La tarea ya no existe (probablemente fue eliminada)
      debugPrint('⚠️ Tarea $taskId no encontrada al descartar alarma');
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
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));
    final nextMonth = today.add(const Duration(days: 30));

    List<Task> filtered;

    switch (_selectedIndex) {
      case 0: // Pendientes (mostrar todas, incluso sin alarma)
        filtered = tasks.where((task) => !task.hasAlarm).toList();
        break;
      case 1: // Hoy
        filtered =
            tasks.where((task) {
              if (!task.hasAlarm) return false; // Solo mostrar tareas con alarma
              final taskDate = DateTime(
                task.assignedTime.year,
                task.assignedTime.month,
                task.assignedTime.day,
              );
              return taskDate.isAtSameMomentAs(today) &&
                  task.repetitionType == RepetitionType.none;
            }).toList();
        break;
      case 2: // Otros días
        filtered =
            tasks.where((task) {
              if (!task.hasAlarm) return false; // Solo mostrar tareas con alarma
              final taskDate = DateTime(
                task.assignedTime.year,
                task.assignedTime.month,
                task.assignedTime.day,
              );
              return taskDate.isAfter(today) &&
                  task.repetitionType == RepetitionType.none;
            }).toList();
        break;
      case 3: // Repetitivas
        filtered =
            tasks.where((task) {
              return task.hasAlarm && task.repetitionType != RepetitionType.none;
            }).toList();
        break;
      default:
        filtered = tasks;
    }

    // Aplicar filtro por día si está activo
    if (_filterByDay != null) {
      filtered = filtered.where((task) {
        final taskDate = DateTime(
          task.assignedTime.year,
          task.assignedTime.month,
          task.assignedTime.day,
        );

        switch (_filterByDay) {
          case 'today':
            return taskDate.isAtSameMomentAs(today);
          case 'tomorrow':
            return taskDate.isAtSameMomentAs(tomorrow);
          case 'week':
            return taskDate.isAfter(today) && taskDate.isBefore(nextWeek);
          case 'month':
            return taskDate.isAfter(today) && taskDate.isBefore(nextMonth);
          default:
            return true;
        }
      }).toList();
    }

    // Ordenar por fecha y hora
    filtered.sort((a, b) {
      if (_sortOrder == 'desc') {
        return b.assignedTime.compareTo(a.assignedTime);
      }
      return a.assignedTime.compareTo(b.assignedTime);
    });
    
    return filtered;
  }

  String _getEmptyMessage() {
    switch (_selectedIndex) {
      case 0:
        return 'No hay tareas pendientes';
      case 1:
        return 'No hay tareas para hoy';
      case 2:
        return 'No hay tareas programadas';
      case 3:
        return 'No hay tareas repetitivas';
      default:
        return 'No hay tareas';
    }
  }

  // Widget para los chips de filtro
  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF3D3350),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey[700]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _getFilteredTasks();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Tareas'),
        actions: [
          // Botón de filtros
          IconButton(
            icon: Icon(
              _showFilterMenu ? Icons.filter_alt : Icons.filter_alt_outlined,
              size: 28,
            ),
            onPressed: () {
              setState(() {
                _showFilterMenu = !_showFilterMenu;
              });
            },
            tooltip: 'Filtros',
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 40),
            onPressed: _addTask,
            tooltip: 'Añadir tarea',
          ),
        ],
      ),
      body: Column(
        children: [
          // Panel de filtros desplegable
          if (_showFilterMenu)
            Container(
              color: const Color(0xFF2D2640),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Orden
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sort, color: Colors.white70, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Orden:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                              label: 'Más reciente primero',
                              isSelected: _sortOrder == 'asc',
                              onTap: () {
                                setState(() {
                                  _sortOrder = 'asc';
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Más antiguo primero',
                              isSelected: _sortOrder == 'desc',
                              onTap: () {
                                setState(() {
                                  _sortOrder = 'desc';
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Filtro por día
                  Row(
                    children: [
                      const Icon(Icons.date_range, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Período:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        label: 'Todas',
                        isSelected: _filterByDay == null,
                        onTap: () {
                          setState(() {
                            _filterByDay = null;
                          });
                        },
                      ),
                      _buildFilterChip(
                        label: 'Hoy',
                        isSelected: _filterByDay == 'today',
                        onTap: () {
                          setState(() {
                            _filterByDay = 'today';
                          });
                        },
                      ),
                      _buildFilterChip(
                        label: 'Mañana',
                        isSelected: _filterByDay == 'tomorrow',
                        onTap: () {
                          setState(() {
                            _filterByDay = 'tomorrow';
                          });
                        },
                      ),
                      _buildFilterChip(
                        label: 'Esta semana',
                        isSelected: _filterByDay == 'week',
                        onTap: () {
                          setState(() {
                            _filterByDay = 'week';
                          });
                        },
                      ),
                      _buildFilterChip(
                        label: 'Este mes',
                        isSelected: _filterByDay == 'month',
                        onTap: () {
                          setState(() {
                            _filterByDay = 'month';
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          // Lista de tareas
          Expanded(
            child: filteredTasks.isEmpty
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
                    child: TaskCard(
                      task: task, 
                      onTap: () => _editTask(task),
                      onToggleComplete: (isCompleted) => _toggleTaskComplete(task),
                    ),
                  );
                },
              ),
          ),
        ],
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
          BottomNavigationBarItem(
            icon: Icon(Icons.check_box_outlined), 
            label: 'Pendientes',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.today), label: 'Hoy'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Próximas',
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
