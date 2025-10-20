import 'package:flutter/material.dart';
import '../models/task.dart';
import '../widgets/task_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Lista de tareas de ejemplo
  List<Task> tasks = [
    Task(
      id: '1',
      title: 'Completar proyecto Flutter',
      assignedTime: DateTime.now(),
    ),
    Task(
      id: '2',
      title: 'Revisar correos',
      assignedTime: DateTime.now().add(const Duration(hours: 2)),
    ),
    Task(
      id: '3',
      title: 'Reunión con el equipo',
      assignedTime: DateTime.now().add(const Duration(hours: 4)),
    ),
  ];

  void _addTask() {
    // Por ahora solo muestra un diálogo simple
    // Puedes expandir esto más tarde para agregar tareas reales
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir Tarea'),
        content: const Text('Función de añadir tarea - Por implementar'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Tareas'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.task_alt,
                    size: 100,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay tareas',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Presiona el botón + para añadir una tarea',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                return TaskCard(task: tasks[index]);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
