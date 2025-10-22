import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final Function(bool)? onToggleComplete;

  const TaskCard({
    super.key, 
    required this.task, 
    this.onTap,
    this.onToggleComplete,
  });

  String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final repetitionDesc = task.getRepetitionDescription();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono de tarea para tareas sin alarma, icono de notificación para tareas con alarma
              if (!task.hasAlarm)
                GestureDetector(
                  onTap: () => onToggleComplete?.call(!task.isCompleted),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: task.isCompleted 
                        ? Colors.green.withOpacity(0.2)
                        : const Color(0xFF8B5CF6).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      task.isCompleted
                        ? Icons.task_alt
                        : Icons.assignment_outlined,
                      color: task.isCompleted
                        ? Colors.green
                        : const Color(0xFF8B5CF6),
                      size: 28,
                    ),
                  ),
                )
              else
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    color: Color(0xFF8B5CF6),
                    size: 28,
                  ),
                ),
              const SizedBox(width: 16),
              // Información de la tarea
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        decoration: task.isCompleted && !task.hasAlarm
                          ? TextDecoration.lineThrough
                          : null,
                        decorationColor: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          task.hasAlarm ? Icons.access_time : Icons.calendar_today,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatTime(task.assignedTime)} - ${_formatDate(task.assignedTime)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    // Mostrar indicador de repetición solo para tareas con alarma
                    if (task.hasAlarm && repetitionDesc.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.repeat,
                            size: 16,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            repetitionDesc,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Icono de editar
              Icon(Icons.edit_outlined, size: 20, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
