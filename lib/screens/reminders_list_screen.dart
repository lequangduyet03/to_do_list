import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/task.dart';
import 'reminders_screen.dart';

class RemindersListScreen extends StatefulWidget {
  final int userId;

  const RemindersListScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _RemindersListScreenState createState() => _RemindersListScreenState();
}

class _RemindersListScreenState extends State<RemindersListScreen> {
  List<Task> _tasksWithReminders = [];
  bool _isLoading = true;
  final String baseUrl = 'https://sever-todo-app-1.onrender.com'; // Thay đổi nếu cần

  @override
  void initState() {
    super.initState();
    _fetchTasksWithReminders();
  }

  Future<void> _fetchTasksWithReminders() async {
    setState(() => _isLoading = true);
    const maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries && mounted) {
      try {
        // Giả sử backend hỗ trợ endpoint lọc task có reminder
        final response = await http.get(
          Uri.parse('$baseUrl/api/users/${widget.userId}/tasks-with-reminders'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final List<dynamic> tasksData = jsonDecode(response.body);
          setState(() {
            _tasksWithReminders =
                tasksData.map((json) => Task.fromJson(json)).toList();
            _isLoading = false;
          });
          return;
        } else {
          throw Exception('Failed to load tasks: ${response.statusCode}');
        }
      } catch (e) {
        retryCount++;
        if (retryCount == maxRetries) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Không thể tải danh sách: $e')),
            );
          }
          return;
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  Widget _getStatusLabel(String status) {
    Color color;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'completed':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'in_progress':
        color = Colors.blue;
        icon = Icons.pending;
        break;
      case 'overdue':
        color = Colors.red;
        icon = Icons.warning;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 20),
        Text(
          status.replaceAll('_', ' ').toUpperCase(),
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }

  void _navigateToRemindersScreen(int taskId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            RemindersScreen(userId: widget.userId, taskId: taskId),
      ),
    ).then((_) => _fetchTasksWithReminders());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách nhắc nhở'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasksWithReminders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Chưa có công việc nào có nhắc nhở',
                          style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchTasksWithReminders,
                        child: const Text('Tải lại'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchTasksWithReminders,
                  child: ListView.builder(
                    itemCount: _tasksWithReminders.length,
                    itemBuilder: (context, index) {
                      final task = _tasksWithReminders[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getPriorityColor(task.priority),
                            child: Text(
                              task.priority[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(task.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                task.description.length > 50
                                    ? '${task.description.substring(0, 50)}...'
                                    : task.description,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${task.deadline.day}/${task.deadline.month}/${task.deadline.year}',
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 12),
                                  ),
                                  _getStatusLabel(task.status),
                                ],
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              size: 16, color: Colors.grey),
                          onTap: () => _navigateToRemindersScreen(task.id),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
