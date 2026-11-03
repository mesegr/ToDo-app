import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/repetition_type.dart';
import 'package:todo_app/models/task.dart';

void main() {
  group('Task JSON serialization', () {
    final assignedTime = DateTime(2026, 11, 3, 9, 30);

    test('round-trips all task fields', () {
      final task = Task(
        id: 'task-1',
        title: 'Revisar proyecto',
        description: 'Preparar los cambios',
        assignedTime: assignedTime,
        isCompleted: true,
        repetitionType: RepetitionType.weekly,
        weeklyDays: [DayOfWeek.monday, DayOfWeek.friday],
        monthlyDay: 12,
        hasAlarm: false,
        category: 'Trabajo',
      );

      final restored = Task.fromJson(task.toJson());

      expect(restored.id, task.id);
      expect(restored.title, task.title);
      expect(restored.description, task.description);
      expect(restored.assignedTime, assignedTime);
      expect(restored.isCompleted, isTrue);
      expect(restored.repetitionType, RepetitionType.weekly);
      expect(restored.weeklyDays, [DayOfWeek.monday, DayOfWeek.friday]);
      expect(restored.monthlyDay, 12);
      expect(restored.hasAlarm, isFalse);
      expect(restored.category, 'Trabajo');
    });

    test('uses defaults for fields absent in older saved tasks', () {
      final task = Task.fromJson({
        'id': 'legacy-task',
        'title': 'Tarea antigua',
        'assignedTime': assignedTime.toIso8601String(),
      });

      expect(task.description, isNull);
      expect(task.isCompleted, isFalse);
      expect(task.repetitionType, RepetitionType.none);
      expect(task.weeklyDays, isEmpty);
      expect(task.monthlyDay, isNull);
      expect(task.hasAlarm, isTrue);
      expect(task.category, isNull);
    });

    test('migrates the legacy singular weeklyDay field', () {
      final task = Task.fromJson({
        'id': 'legacy-weekly',
        'title': 'Tarea semanal',
        'assignedTime': assignedTime.toIso8601String(),
        'repetitionType': RepetitionType.weekly.index,
        'weeklyDay': DayOfWeek.wednesday.index,
      });

      expect(task.weeklyDays, [DayOfWeek.wednesday]);
    });

    test('prefers weeklyDays when both old and new keys exist', () {
      final task = Task.fromJson({
        'id': 'weekly-task',
        'title': 'Tarea semanal',
        'assignedTime': assignedTime.toIso8601String(),
        'repetitionType': RepetitionType.weekly.index,
        'weeklyDays': [DayOfWeek.tuesday.index, DayOfWeek.thursday.index],
        'weeklyDay': DayOfWeek.sunday.index,
      });

      expect(task.weeklyDays, [DayOfWeek.tuesday, DayOfWeek.thursday]);
    });
  });

  group('Task repetition descriptions', () {
    Task task({
      required RepetitionType repetition,
      List<DayOfWeek> days = const [],
      int? monthlyDay,
    }) => Task(
      id: 'task',
      title: 'Tarea',
      assignedTime: DateTime(2026, 11, 3),
      repetitionType: repetition,
      weeklyDays: days,
      monthlyDay: monthlyDay,
    );

    test('describes no repetition and daily repetition', () {
      expect(
        task(repetition: RepetitionType.none).getRepetitionDescription(),
        '',
      );
      expect(
        task(repetition: RepetitionType.daily).getRepetitionDescription(),
        'Todos los días',
      );
    });

    test('describes weekly repetition with no selected days', () {
      expect(
        task(repetition: RepetitionType.weekly).getRepetitionDescription(),
        'Semanal',
      );
    });

    test('describes one selected weekday in lowercase', () {
      expect(
        task(
          repetition: RepetitionType.weekly,
          days: [DayOfWeek.monday],
        ).getRepetitionDescription(),
        'Todos los lunes',
      );
    });

    test('sorts multiple selected weekdays by weekday order', () {
      expect(
        task(
          repetition: RepetitionType.weekly,
          days: [DayOfWeek.friday, DayOfWeek.monday, DayOfWeek.wednesday],
        ).getRepetitionDescription(),
        'Lunes, Miércoles, Viernes',
      );
    });

    test('describes all seven selected days as daily repetition', () {
      expect(
        task(
          repetition: RepetitionType.weekly,
          days: DayOfWeek.values,
        ).getRepetitionDescription(),
        'Todos los días',
      );
    });

    test('describes monthly repetition with and without a day', () {
      expect(
        task(repetition: RepetitionType.monthly).getRepetitionDescription(),
        'Mensual',
      );
      expect(
        task(
          repetition: RepetitionType.monthly,
          monthlyDay: 15,
        ).getRepetitionDescription(),
        'Día 15 de cada mes',
      );
    });
  });
}
