import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback? onTap;
  final Function(bool)? onToggleComplete;

  const TaskCard({
    super.key, 
    required this.task, 
    this.onTap,
    this.onToggleComplete,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _isExpanded = false;

  String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final repetitionDesc = widget.task.getRepetitionDescription();
    final hasDescription = widget.task.description != null && 
                          widget.task.description!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icono de tarea para tareas sin alarma, icono de notificación para tareas con alarma
                  if (!widget.task.hasAlarm)
                    GestureDetector(
                      onTap: () => widget.onToggleComplete?.call(!widget.task.isCompleted),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: widget.task.isCompleted 
                            ? Colors.green.withOpacity(0.2)
                            : const Color(0xFF8B5CF6).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          widget.task.isCompleted
                            ? Icons.task_alt
                            : Icons.assignment_outlined,
                          color: widget.task.isCompleted
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
                          widget.task.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            decoration: widget.task.isCompleted && !widget.task.hasAlarm
                              ? TextDecoration.lineThrough
                              : null,
                            decorationColor: Colors.grey,
                          ),
                        ),
                        // Mostrar preview de descripción si existe
                        if (hasDescription && !_isExpanded) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.task.description!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              widget.task.hasAlarm ? Icons.access_time : Icons.calendar_today,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_formatTime(widget.task.assignedTime)} - ${_formatDate(widget.task.assignedTime)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        // Mostrar indicador de repetición solo para tareas con alarma
                        if (widget.task.hasAlarm && repetitionDesc.isNotEmpty) ...[
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
                  // Botón para expandir descripción si existe
                  if (hasDescription)
                    IconButton(
                      icon: Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: const Color(0xFF8B5CF6),
                      ),
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      tooltip: _isExpanded ? 'Ver menos' : 'Ver más',
                    )
                  else
                    // Icono de editar cuando no hay descripción
                    Icon(Icons.edit_outlined, size: 20, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
          // Sección expandible para la descripción completa
          if (hasDescription && _isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.description,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Descripción:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.task.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[300],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
