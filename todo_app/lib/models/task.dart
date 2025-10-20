import 'repetition_type.dart';

class Task {
  final String id;
  final String title;
  final DateTime assignedTime;
  final bool isCompleted;
  final RepetitionType repetitionType;
  final DayOfWeek? weeklyDay; // Para tareas semanales
  final int? monthlyDay; // Para tareas mensuales (día del mes)

  Task({
    required this.id,
    required this.title,
    required this.assignedTime,
    this.isCompleted = false,
    this.repetitionType = RepetitionType.none,
    this.weeklyDay,
    this.monthlyDay,
  });

  Task copyWith({
    String? id,
    String? title,
    DateTime? assignedTime,
    bool? isCompleted,
    RepetitionType? repetitionType,
    DayOfWeek? weeklyDay,
    int? monthlyDay,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      assignedTime: assignedTime ?? this.assignedTime,
      isCompleted: isCompleted ?? this.isCompleted,
      repetitionType: repetitionType ?? this.repetitionType,
      weeklyDay: weeklyDay ?? this.weeklyDay,
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
        if (weeklyDay != null) {
          return 'Todos los ${weeklyDay!.displayName.toLowerCase()}';
        }
        return 'Semanal';
      case RepetitionType.monthly:
        if (monthlyDay != null) {
          return 'Día $monthlyDay de cada mes';
        }
        return 'Mensual';
    }
  }
}
