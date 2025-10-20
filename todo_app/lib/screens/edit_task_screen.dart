import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/repetition_type.dart';

class EditTaskScreen extends StatefulWidget {
  final Task task;

  const EditTaskScreen({
    super.key,
    required this.task,
  });

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late RepetitionType _repetitionType;
  DayOfWeek? _selectedWeekDay;
  int? _selectedMonthDay;

  @override
  void initState() {
    super.initState();
    // Inicializar con los datos de la tarea existente
    _titleController = TextEditingController(text: widget.task.title);
    _selectedDate = widget.task.assignedTime;
    _selectedTime = TimeOfDay.fromDateTime(widget.task.assignedTime);
    _repetitionType = widget.task.repetitionType;
    _selectedWeekDay = widget.task.weeklyDay;
    _selectedMonthDay = widget.task.monthlyDay;
  }

  @override
  void dispose() {
    _titleController.dispose();
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

      // Validar que si es semanal, tenga un día seleccionado
      if (_repetitionType == RepetitionType.weekly && _selectedWeekDay == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor selecciona un día de la semana'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Validar que si es mensual, tenga un día del mes seleccionado
      if (_repetitionType == RepetitionType.monthly && _selectedMonthDay == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor selecciona un día del mes'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final updatedTask = widget.task.copyWith(
        title: _titleController.text,
        assignedTime: assignedDateTime,
        repetitionType: _repetitionType,
        weeklyDay: _selectedWeekDay,
        monthlyDay: _selectedMonthDay,
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
                  'Selecciona el día de la semana:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: DayOfWeek.values.map((day) {
                    final isSelected = _selectedWeekDay == day;
                    return ChoiceChip(
                      label: Text(day.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedWeekDay = selected ? day : null;
                        });
                      },
                      selectedColor: Colors.blue,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _selectedMonthDay,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      appBar: AppBar(
        title: const Text('Editar Tarea'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
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
            const SizedBox(height: 24),

            // Selector de fecha
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.blue),
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
                leading: const Icon(Icons.access_time, color: Colors.blue),
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: RepetitionType.values.map((type) {
                  return RadioListTile<RepetitionType>(
                    title: Text(type.displayName),
                    value: type,
                    groupValue: _repetitionType,
                    onChanged: (RepetitionType? value) {
                      setState(() {
                        _repetitionType = value!;
                        // Limpiar selecciones previas si cambia el tipo
                        if (_repetitionType != RepetitionType.weekly) {
                          _selectedWeekDay = null;
                        }
                        if (_repetitionType != RepetitionType.monthly) {
                          _selectedMonthDay = null;
                        }
                      });
                    },
                    activeColor: Colors.blue,
                  );
                }).toList(),
              ),
            ),

            // Opciones adicionales según el tipo de repetición
            _buildRepetitionOptions(),

            const SizedBox(height: 24),

            // Botón de guardar
            ElevatedButton(
              onPressed: _saveTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Guardar Cambios',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
