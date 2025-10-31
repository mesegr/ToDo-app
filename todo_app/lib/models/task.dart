import 'repetition_type.dart';

// Clase auxiliar para diferenciar entre "no pasar el parámetro" y "pasar null"
class _Undefined {
  const _Undefined();
}

class Task {
  final String id;
  final String title;
  final String? description; // Descripción opcional de la tarea
  final DateTime assignedTime;
  final bool isCompleted;
  final RepetitionType repetitionType;
  final List<DayOfWeek> weeklyDays; // Para tareas semanales (múltiples días)
  final int? monthlyDay; // Para tareas mensuales (día del mes)
  final bool hasAlarm; // Indica si la tarea tiene alarma o es solo un to-do
  final String? category; // Categoría/carpeta para organizar tareas

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.assignedTime,
    this.isCompleted = false,
    this.repetitionType = RepetitionType.none,
    this.weeklyDays = const [],
    this.monthlyDay,
    this.hasAlarm = true, // Por defecto tiene alarma (retrocompatibilidad)
    this.category, // Categoría opcional
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? assignedTime,
    bool? isCompleted,
    RepetitionType? repetitionType,
    List<DayOfWeek>? weeklyDays,
    int? monthlyDay,
    bool? hasAlarm,
    Object? category = const _Undefined(), // Usar Object para permitir null explícito
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTime: assignedTime ?? this.assignedTime,
      isCompleted: isCompleted ?? this.isCompleted,
      repetitionType: repetitionType ?? this.repetitionType,
      weeklyDays: weeklyDays ?? this.weeklyDays,
      monthlyDay: monthlyDay ?? this.monthlyDay,
      hasAlarm: hasAlarm ?? this.hasAlarm,
      category: category is _Undefined ? this.category : category as String?,
    );
  }

  String getRepetitionDescription() {
    switch (repetitionType) {
      case RepetitionType.none:
        return '';
      case RepetitionType.daily:
        return 'Todos los días';
      case RepetitionType.weekly:
        if (weeklyDays.isNotEmpty) {
          if (weeklyDays.length == 7) {
            return 'Todos los días';
          } else if (weeklyDays.length == 1) {
            return 'Todos los ${weeklyDays[0].displayName.toLowerCase()}';
          } else {
            // Ordenar los días
            final sortedDays = List<DayOfWeek>.from(weeklyDays)
              ..sort((a, b) => a.weekdayNumber.compareTo(b.weekdayNumber));
            final dayNames = sortedDays.map((d) => d.displayName).join(', ');
            return dayNames;
          }
        }
        return 'Semanal';
      case RepetitionType.monthly:
        if (monthlyDay != null) {
          return 'Día $monthlyDay de cada mes';
        }
        return 'Mensual';
    }
  }

  // Serialización a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'assignedTime': assignedTime.toIso8601String(),
      'isCompleted': isCompleted,
      'repetitionType': repetitionType.index,
      'weeklyDays': weeklyDays.map((day) => day.index).toList(),
      'monthlyDay': monthlyDay,
      'hasAlarm': hasAlarm,
      'category': category,
    };
  }

  // Deserialización desde JSON
  factory Task.fromJson(Map<String, dynamic> json) {
    // Compatibilidad con versión anterior (weeklyDay singular)
    List<DayOfWeek> weeklyDaysList = [];
    if (json.containsKey('weeklyDays')) {
      final days = json['weeklyDays'] as List<dynamic>?;
      if (days != null) {
        weeklyDaysList = days.map((d) => DayOfWeek.values[d as int]).toList();
      }
    } else if (json.containsKey('weeklyDay') && json['weeklyDay'] != null) {
      // Migrar de la versión antigua
      weeklyDaysList = [DayOfWeek.values[json['weeklyDay'] as int]];
    }

    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      assignedTime: DateTime.parse(json['assignedTime'] as String),
      isCompleted: json['isCompleted'] as bool? ?? false,
      repetitionType:
          RepetitionType.values[json['repetitionType'] as int? ?? 0],
      weeklyDays: weeklyDaysList,
      monthlyDay: json['monthlyDay'] as int?,
      hasAlarm: json['hasAlarm'] as bool? ?? true, // Por defecto true para retrocompatibilidad
      category: json['category'] as String?,
    );
  }
}
