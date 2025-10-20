import '../models/task.dart';

class TaskManager {
  static final TaskManager _instance = TaskManager._internal();
  factory TaskManager() => _instance;
  TaskManager._internal();

  List<Task> _tasks = [];
  
  void setTasks(List<Task> tasks) {
    _tasks = tasks;
  }
  
  Task? getTaskById(String id) {
    try {
      return _tasks.firstWhere((task) => task.id == id);
    } catch (e) {
      return null;
    }
  }
  
  List<Task> get tasks => _tasks;
}
