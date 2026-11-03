import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';

class TaskRepository {
  static const String _tasksKey = 'tasks';

  Future<List<Task>> loadTasks() async {
    final preferences = await SharedPreferences.getInstance();
    final tasksJson = preferences.getString(_tasksKey);
    if (tasksJson == null) return [];

    final decoded = json.decode(tasksJson) as List<dynamic>;
    return decoded
        .map((item) => Task.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.assignedTime.compareTo(b.assignedTime));
  }

  Future<void> saveTasks(List<Task> tasks) async {
    final preferences = await SharedPreferences.getInstance();
    final tasksJson = json.encode(tasks.map((task) => task.toJson()).toList());
    await preferences.setString(_tasksKey, tasksJson);
  }
}
