import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/repetition_type.dart';

class EditTaskScreen extends StatefulWidget {
  final Task task;

  const EditTaskScreen({super.key, required this.task});

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late RepetitionType _repetitionType;
  List<DayOfWeek> _selectedWeekDays = [];
  int? _selectedMonthDay;
  late bool _hasAlarm;

  @override
  void initState() {
    super.initState();
    // Inicializar con los datos de la tarea existente
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(text: widget.task.description ?? '');
    _selectedDate = widget.task.assignedTime;
    _selectedTime = TimeOfDay.fromDateTime(widget.task.assignedTime);
    _repetitionType = widget.task.repetitionType;
    _selectedWeekDays = List.from(widget.task.weeklyDays);
    _selectedMonthDay = widget.task.monthlyDay;
    _hasAlarm = widget.task.hasAlarm;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveTask() {
    if (_formKey.currentState!.validate()) {
      // Combinar fecha y hora
      final DateTime assignedDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Solo validar repeticiones si tiene alarma
      if (_hasAlarm) {
        // Validar que si es semanal, tenga un día seleccionado
        if (_repetitionType == RepetitionType.weekly &&
            _selectedWeekDays.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor selecciona al menos un día de la semana'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Validar que si es mensual, tenga un día del mes seleccionado
        if (_repetitionType == RepetitionType.monthly &&
            _selectedMonthDay == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor selecciona un día del mes'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      final updatedTask = widget.task.copyWith(
        title: _titleController.text,
        description: _descriptionController.text.isEmpty 
            ? null 
            : _descriptionController.text,
        assignedTime: assignedDateTime,
        repetitionType: _hasAlarm ? _repetitionType : RepetitionType.none,
        weeklyDays: _hasAlarm ? _selectedWeekDays : [],
        monthlyDay: _hasAlarm ? _selectedMonthDay : null,
        hasAlarm: _hasAlarm,
        category: widget.task.category, // Mantener la categoría actual
      );

      Navigator.pop(context, updatedTask);
    }
  }

  Widget _buildRepetitionOptions() {
    switch (_repetitionType) {
      case RepetitionType.weekly:
        return Card(
          margin: const EdgeInsets.only(top: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selecciona los días de la semana:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      DayOfWeek.values.map((day) {
                        final isSelected = _selectedWeekDays.contains(day);
                        return ChoiceChip(
                          label: Text(day.displayName),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedWeekDays.add(day);
                              } else {
                                _selectedWeekDays.remove(day);
                              }
                            });
                          },
                          selectedColor: const Color(0xFF8B5CF6),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
          ),
        );
      case RepetitionType.monthly:
        return Card(
          margin: const EdgeInsets.only(top: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selecciona el día del mes:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _selectedMonthDay,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  hint: const Text('Selecciona un día'),
                  items: List.generate(31, (index) {
                    final day = index + 1;
                    return DropdownMenuItem(
                      value: day,
                      child: Text('Día $day'),
                    );
                  }),
                  onChanged: (value) {
                    setState(() {
                      _selectedMonthDay = value;
                    });
                  },
                ),
              ],
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Tarea')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Campo de título
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título de la tarea',
                hintText: 'Ej: Revisar correos',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingresa un título';
                }
                if (value.length < 3) {
                  return 'El título debe tener al menos 3 caracteres';
                }
                return null;
              },
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Campo de descripción (opcional)
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Añade detalles sobre la tarea...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            // Selector de fecha
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.calendar_today,
                  color: Color(0xFF8B5CF6),
                ),
                title: const Text('Fecha'),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _selectDate(context),
              ),
            ),
            const SizedBox(height: 12),

            // Selector de hora
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.access_time,
                  color: Color(0xFF8B5CF6),
                ),
                title: const Text('Hora'),
                subtitle: Text(_selectedTime.format(context)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _selectTime(context),
              ),
            ),
            const SizedBox(height: 24),

            // Switch para activar/desactivar alarma
            Card(
              child: SwitchListTile(
                title: const Text('Configurar alarma'),
                subtitle: Text(
                  _hasAlarm 
                    ? 'Esta tarea tendrá recordatorio' 
                    : 'Esta tarea es solo un pendiente',
                ),
                value: _hasAlarm,
                onChanged: (bool value) {
                  setState(() {
                    _hasAlarm = value;
                    if (!_hasAlarm) {
                      // Si se desactiva la alarma, limpiar repeticiones
                      _repetitionType = RepetitionType.none;
                      _selectedWeekDays = [];
                      _selectedMonthDay = null;
                    }
                  });
                },
                activeThumbColor: const Color(0xFF8B5CF6),
                secondary: Icon(
                  _hasAlarm ? Icons.notifications_active : Icons.check_box,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ),

            // Mostrar opciones de fecha/hora/repetición solo si tiene alarma
            if (_hasAlarm) ...[
              const SizedBox(height: 12),

              // Selector de fecha
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.calendar_today,
                    color: Color(0xFF8B5CF6),
                  ),
                  title: const Text('Fecha'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _selectDate(context),
                ),
              ),
              const SizedBox(height: 12),

              // Selector de hora
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.access_time,
                    color: Color(0xFF8B5CF6),
                  ),
                  title: const Text('Hora'),
                  subtitle: Text(_selectedTime.format(context)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _selectTime(context),
                ),
              ),
              const SizedBox(height: 24),

              // Selector de tipo de repetición
              const Text(
                'Repetición',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children:
                      RepetitionType.values.map((type) {
                        return RadioListTile<RepetitionType>(
                          title: Text(type.displayName),
                          value: type,
                          groupValue: _repetitionType,
                          onChanged: (RepetitionType? value) {
                            setState(() {
                              _repetitionType = value!;
                              // Limpiar selecciones previas si cambia el tipo
                              if (_repetitionType != RepetitionType.weekly) {
                                _selectedWeekDays = [];
                              }
                              if (_repetitionType != RepetitionType.monthly) {
                                _selectedMonthDay = null;
                              }
                            });
                          },
                          activeColor: const Color(0xFF8B5CF6),
                        );
                      }).toList(),
                ),
              ),

              // Opciones adicionales según el tipo de repetición
              _buildRepetitionOptions(),
            ] else ...[
              // Si no tiene alarma, mostrar selector de fecha simple
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.calendar_today,
                    color: Color(0xFF8B5CF6),
                  ),
                  title: const Text('Fecha límite (opcional)'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _selectDate(context),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Botón de guardar
            ElevatedButton(
              onPressed: _saveTask,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Guardar Cambios',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            
            // Padding inferior para que el botón nunca esté pegado al borde
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
