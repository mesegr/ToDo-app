import 'repetition_type.dart';

class Task {
  final String id;
  final String title;
  final DateTime assignedTime;
  final bool isCompleted;
  final RepetitionType repetitionType;
  final List<DayOfWeek> weeklyDays; // Para tareas semanales (múltiples días)
  final int? monthlyDay; // Para tareas mensuales (día del mes)

  Task({
    required this.id,
    required this.title,
    required this.assignedTime,
    this.isCompleted = false,
    this.repetitionType = RepetitionType.none,
    this.weeklyDays = const [],
    this.monthlyDay,
  });

  Task copyWith({
    String? id,
    String? title,
    DateTime? assignedTime,
    bool? isCompleted,
    RepetitionType? repetitionType,
    List<DayOfWeek>? weeklyDays,
    int? monthlyDay,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      assignedTime: assignedTime ?? this.assignedTime,
      isCompleted: isCompleted ?? this.isCompleted,
      repetitionType: repetitionType ?? this.repetitionType,
      weeklyDays: weeklyDays ?? this.weeklyDays,
      monthlyDay: monthlyDay ?? this.monthlyDay,
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
      'assignedTime': assignedTime.toIso8601String(),
      'isCompleted': isCompleted,
      'repetitionType': repetitionType.index,
      'weeklyDays': weeklyDays.map((day) => day.index).toList(),
      'monthlyDay': monthlyDay,
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
      assignedTime: DateTime.parse(json['assignedTime'] as String),
      isCompleted: json['isCompleted'] as bool? ?? false,
      repetitionType:
          RepetitionType.values[json['repetitionType'] as int? ?? 0],
      weeklyDays: weeklyDaysList,
      monthlyDay: json['monthlyDay'] as int?,
    );
  }
}
