import 'package:flutter/foundation.dart';

import '../models/task.dart';
import '../repositories/task_repository.dart';
import '../services/widget_service.dart';

class TaskManager extends ChangeNotifier {
  TaskManager({TaskRepository? repository})
    : _repository = repository ?? TaskRepository();

  final TaskRepository _repository;
  List<Task> _tasks = [];
  bool _isLoaded = false;

  List<Task> get tasks => List.unmodifiable(_tasks);
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    _tasks = await _repository.loadTasks();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> add(Task task) async {
    _tasks = [..._tasks, task]..sort(_compareByTime);
    await _saveAndNotify();
  }

  Future<void> update(Task task) async {
    _tasks =
        _tasks
            .map((existing) => existing.id == task.id ? task : existing)
            .toList()
          ..sort(_compareByTime);
    await _saveAndNotify();
  }

  Future<void> remove(String taskId) async {
    _tasks = _tasks.where((task) => task.id != taskId).toList();
    await _saveAndNotify();
  }

  Future<void> restore(Task task, int index) async {
    final restored = List<Task>.from(_tasks);
    restored.insert(index.clamp(0, restored.length), task);
    _tasks = restored..sort(_compareByTime);
    await _saveAndNotify();
  }

  Future<void> toggleCompleted(Task task) async {
    await update(task.copyWith(isCompleted: !task.isCompleted));
  }

  Future<void> _saveAndNotify() async {
    await _repository.saveTasks(_tasks);
    notifyListeners();
    await WidgetService.updateWidget();
  }

  int _compareByTime(Task a, Task b) =>
      a.assignedTime.compareTo(b.assignedTime);
}
