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

  // Controller para el PageView
  late PageController _pageController;

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

  // Variables para el sistema de categorías
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
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
    _pageController.dispose();
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
        _loadCategories(); // Cargar categorías desde las tareas
      });
    }
  }

  // Extraer categorías únicas de las tareas
  void _loadCategories() {
    final Set<String> uniqueCategories = {};
    for (final task in tasks) {
      if (task.category != null && task.category!.isNotEmpty) {
        uniqueCategories.add(task.category!);
      }
    }
    _categories = uniqueCategories.toList()..sort();
  }

  // Crear una nueva categoría
  Future<void> _createCategory() async {
    final TextEditingController controller = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2640),
        title: const Text('Nueva Carpeta', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nombre de la carpeta',
            hintStyle: TextStyle(color: Colors.grey[400]),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF8B5CF6)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('Crear', style: TextStyle(color: Color(0xFF8B5CF6))),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && !_categories.contains(result)) {
      setState(() {
        _categories.add(result);
        _categories.sort();
      });
    }
  }

  // Mover tarea a una categoría
  Future<void> _moveTaskToCategory(Task task, String? category) async {
    final index = tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) return;
    
    // Actualizar la tarea con la nueva categoría
    final updatedTask = task.copyWith(category: category);
    tasks[index] = updatedTask;
    
    // Guardar cambios
    await _saveTasks();
    
    // Recargar categorías y forzar reconstrucción completa
    setState(() {
      _loadCategories();
    });
    
    // Mostrar confirmación
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            category == null 
              ? '✓ Tarea sacada de la carpeta' 
              : '✓ Tarea movida a "$category"',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Sacar tarea de carpeta (mediante deslizar a la derecha)
  void _removeTaskFromCategory(Task task) {
    final index = tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) return;
    
    // Crear una copia de la tarea sin categoría
    final taskWithoutCategory = task.copyWith(category: null);
    
    // PRIMERO: Eliminar la tarea original completamente
    setState(() {
      tasks.removeAt(index);
    });
    
    // DESPUÉS: En el siguiente frame, añadir la nueva tarea
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          tasks.insert(index, taskWithoutCategory);
          _loadCategories();
        });
        _saveTasks();
        
        // Mostrar confirmación
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Tarea sacada de la carpeta'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }


  // Eliminar categoría (pone las tareas en null)
  Future<void> _deleteCategory(String category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2640),
        title: const Text('Eliminar Carpeta', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Eliminar "$category"?\n\nLas tareas NO se eliminarán, solo quedarán sin carpeta.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        // Remover categoría de todas las tareas que la tengan
        for (int i = 0; i < tasks.length; i++) {
          if (tasks[i].category == category) {
            tasks[i] = tasks[i].copyWith(category: null);
          }
        }
        _categories.remove(category);
      });
      await _saveTasks();
    }
  }

  // Guardar tareas en SharedPreferences
  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> tasksJson =
        tasks.map((task) => task.toJson()).toList();
    await prefs.setString(_tasksKey, json.encode(tasksJson));
    
    // Actualizar el widget
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
        // Determinar a qué pestaña navegar
        int targetIndex;
        
        if (!newTask.hasAlarm) {
          // Sin alarma → Pendientes (índice 0)
          targetIndex = 0;
        } else if (newTask.repetitionType != RepetitionType.none) {
          // Con alarma y repetición → Repetitivas (índice 3)
          targetIndex = 3;
        } else {
          // Con alarma y sin repetición → Verificar si es hoy o futura
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final taskDate = DateTime(
            newTask.assignedTime.year,
            newTask.assignedTime.month,
            newTask.assignedTime.day,
          );
          
          if (taskDate.isAtSameMomentAs(today)) {
            // Es hoy → Hoy (índice 1)
            targetIndex = 1;
          } else {
            // Es futura → Próximas (índice 2)
            targetIndex = 2;
          }
        }

        // Navegar a la pestaña correspondiente
        if (targetIndex != _selectedIndex) {
          setState(() {
            _selectedIndex = targetIndex;
          });
          _pageController.animateToPage(
            targetIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }

        // Esperar un momento para que se muestre la tarea
        await Future.delayed(const Duration(milliseconds: 400));
        
        // Mostrar confirmación visual
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '✓ Tarea creada: "${newTask.title}"',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green[700],
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
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

  String _getEmptyMessage(int index) {
    switch (index) {
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

  Widget _buildTaskList(int tabIndex) {
    // Solo aplicar categorías en "Pendientes" (índice 0)
    if (tabIndex == 0) {
      return _buildPendientesWithCategories();
    }

    // Para las demás pestañas, mantener el comportamiento actual
    final previousIndex = _selectedIndex;
    _selectedIndex = tabIndex;
    final filteredTasks = _getFilteredTasks();
    _selectedIndex = previousIndex;

    if (filteredTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 100, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              _getEmptyMessage(tabIndex),
              style: TextStyle(fontSize: 20, color: Colors.grey[300]),
            ),
            const SizedBox(height: 8),
            Text(
              'Presiona el botón + para añadir una tarea',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
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
    );
  }

  // Widget especializado para "Pendientes" con categorías
  Widget _buildPendientesWithCategories() {
    // Obtener solo tareas sin alarma
    final pendingTasks = tasks.where((task) => !task.hasAlarm).toList();

    if (pendingTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 100, color: Colors.grey[600]),
            const SizedBox(height: 16),
            const Text(
              'No hay tareas pendientes',
              style: TextStyle(fontSize: 20, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Presiona el botón + para añadir una tarea',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    // Agrupar tareas por categoría
    final Map<String?, List<Task>> tasksByCategory = {};
    for (final task in pendingTasks) {
      tasksByCategory.putIfAbsent(task.category, () => []).add(task);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Botón para crear nueva carpeta
        GestureDetector(
          onTap: _createCategory,
          child: Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF3D3350),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF8B5CF6), width: 2),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, color: Color(0xFF8B5CF6), size: 28),
                SizedBox(width: 8),
                Text(
                  'Crear Nueva Carpeta',
                  style: TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Mostrar categorías existentes
        ..._categories.map((category) {
          final categoryTasks = tasksByCategory[category] ?? [];
          return _buildCategorySection(category, categoryTasks);
        }),

        // Tareas sin categoría (normales, sin sección especial)
        ...tasksByCategory[null]?.map((task) => _buildDraggableTask(task)) ?? [],
      ],
    );
  }

  // Sección de categoría con drag target
  Widget _buildCategorySection(String category, List<Task> categoryTasks) {
    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) => details.data.category != category,
      onAcceptWithDetails: (details) {
        _moveTaskToCategory(details.data, category);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isHovering ? const Color(0xFF4A3F5C) : const Color(0xFF3D3350),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovering ? const Color(0xFF8B5CF6) : Colors.grey[700]!,
              width: isHovering ? 3 : 1,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: const Icon(Icons.folder, color: Color(0xFF8B5CF6), size: 28),
              title: Text(
              category,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${categoryTasks.length} ${categoryTasks.length == 1 ? 'tarea' : 'tareas'}',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isHovering ? '⬇ Soltar aquí' : '',
                  style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 12),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _deleteCategory(category),
                ),
              ],
            ),
            children: categoryTasks.map((task) => _buildDraggableTask(task)).toList(),
            ),
          ),
        );
      },
    );
  }

  // Tarea draggable
  Widget _buildDraggableTask(Task task) {
    return LongPressDraggable<Task>(
      key: ValueKey('${task.id}_${task.category}'), // Key única que cambia con la categoría
      data: task,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: MediaQuery.of(context).size.width - 48,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.drag_indicator, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: TaskCard(
          task: task,
          onTap: () {},
          onToggleComplete: (_) {},
        ),
      ),
      child: Dismissible(
        key: Key('${task.id}_${task.category ?? "no_category"}'), // Key única que cambia con la categoría
        // Si tiene categoría: ambas direcciones. Si no: solo eliminar (izquierda)
        direction: task.category != null 
            ? DismissDirection.horizontal 
            : DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          // Deslizar a la DERECHA = sacar de carpeta (solo si tiene categoría)
          if (direction == DismissDirection.startToEnd && task.category != null) {
            return true; // Permitir el dismiss para sacar de carpeta
          }
          // Deslizar a la IZQUIERDA = eliminar
          if (direction == DismissDirection.endToStart) {
            return true; // Permitir el dismiss para eliminar
          }
          return false;
        },
        background: Container(
          // Background para deslizar DERECHA (sacar de carpeta)
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6), // Morado para sacar de carpeta
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_off, color: Colors.white, size: 28),
              SizedBox(height: 4),
              Text(
                'Sacar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        secondaryBackground: Container(
          // Background para deslizar IZQUIERDA (eliminar)
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete, color: Colors.white, size: 28),
              SizedBox(height: 4),
              Text(
                'Eliminar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        onDismissed: (direction) {
          if (direction == DismissDirection.startToEnd) {
            // Deslizó a la DERECHA = sacar de carpeta
            _removeTaskFromCategory(task);
          } else {
            // Deslizó a la IZQUIERDA = eliminar
            _deleteTask(task);
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: TaskCard(
            task: task,
            onTap: () => _editTask(task),
            onToggleComplete: (isCompleted) => _toggleTaskComplete(task),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          // PageView para deslizar entre pestañas
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              children: [
                _buildTaskList(0), // Pendientes
                _buildTaskList(1), // Hoy
                _buildTaskList(2), // Próximas
                _buildTaskList(3), // Repetitivas
              ],
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
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
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
