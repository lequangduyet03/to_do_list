import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/task.dart';
import '../models/category.dart';
import 'add_edit_task_screen.dart';

class TasksPage extends StatefulWidget {
  final int userId;
  const TasksPage({Key? key, required this.userId}) : super(key: key);

  @override
  _TasksPageState createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Task> _tasks = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  final String apiBaseUrl = 'https://sever-todo-app-1.onrender.com';

  @override
  void initState() {
    super.initState();
    print('User ID: ${widget.userId}');
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([_fetchTasks(), _fetchCategories()]);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTasks() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/users/${widget.userId}/tasks'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final List<dynamic> taskData = json.decode(response.body);
      print('Task Data: $taskData');
      final tasks = taskData.map((json) => Task.fromJson(json)).toList();
      print('Mapped Tasks: $tasks');
      setState(() => _tasks = tasks);
    } else {
      throw Exception('Failed to load tasks: ${response.statusCode}');
    }
  }

  Future<void> _fetchCategories() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/users/${widget.userId}/categories'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      setState(() => _categories = (json.decode(response.body) as List).map((json) => Category.fromJson(json)).toList());
    } else {
      throw Exception('Failed to load categories: ${response.statusCode}');
    }
  }

  Future<void> _deleteTask(int taskId) async {
    final response = await http.delete(
      Uri.parse('$apiBaseUrl/api/tasks/$taskId'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi khi xóa')));
    }
  }

  void _addNewTask() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AddEditTaskScreen(userId: widget.userId, categories: _categories))).then((result) {
      if (result == true) _loadData();
    });
  }

  void _editTask(Task task) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AddEditTaskScreen(userId: widget.userId, categories: _categories, task: task))).then((result) {
      if (result == true) _loadData();
    });
  }

  void _deleteTaskDialog(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa công việc này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              await _deleteTask(task.id);
              Navigator.pop(context);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  List<Task> _getFilteredTasks() {
    print('All Tasks: $_tasks');
    switch (_tabController.index) {
      case 0:
        return _tasks;
      case 1:
        final filtered = _tasks.where((task) {
          print('Task Status (in_progress): ${task.status}');
          return task.status == 'In Progress';
        }).toList();
        print('Filtered Tasks (in_progress): $filtered');
        return filtered;
      case 2:
        final filtered = _tasks.where((task) {
          print('Task Status (completed): ${task.status}');
          return task.status == 'Completed';
        }).toList();
        print('Filtered Tasks (completed): $filtered');
        return filtered;
      default:
        return _tasks;
    }
  }

  Color _getCategoryColor(int? categoryId) {
    final category = _categories.firstWhere(
      (cat) => cat.id == categoryId,
      orElse: () => Category(id: 0, categoryName: 'Không xác định', color: '#000000', userId: widget.userId),
    );
    return category.getColorValue();
  }

  String _getPriorityLabel(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return 'Thấp';
      case 'medium':
        return 'Trung bình';
      case 'high':
        return 'Cao';
      default:
        return priority;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'Pending':
        return 'Chưa bắt đầu';
      case 'In Progress':
        return 'Đang thực hiện';
      case 'Completed':
        return 'Hoàn thành';
      case 'Overdue':
        return 'Quá hạn';
      default:
        return status;
    }
  }

  Widget _buildTaskCard(Task task) {
    final statusLabel = _getStatusLabel(task.status);
    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _editTask(task),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Sửa',
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
          ),
          SlidableAction(
            onPressed: (_) => _deleteTaskDialog(task),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Xóa',
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
          ),
        ],
      ),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 120),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: _getCategoryColor(task.categoryId),
                  radius: 10,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: task.priority.toLowerCase() == 'high'
                                  ? Colors.red[100]
                                  : task.priority.toLowerCase() == 'medium'
                                      ? Colors.blue[100]
                                      : Colors.green[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getPriorityLabel(task.priority).toLowerCase(),
                              style: TextStyle(
                                color: task.priority.toLowerCase() == 'high'
                                    ? Colors.red
                                    : task.priority.toLowerCase() == 'medium'
                                        ? Colors.blue
                                        : Colors.green,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (task.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            task.description,
                            style: const TextStyle(color: Colors.grey),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${DateFormat('dd/MM/yyyy').format(task.deadline)} ${DateFormat('HH:mm').format(task.deadline)}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: task.status == 'Completed'
                              ? Colors.green[100]
                              : task.status == 'In Progress'
                                  ? Colors.blue[100]
                                  : task.status == 'Overdue'
                                      ? Colors.red[100]
                                      : Colors.orange[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: task.status == 'Completed'
                                ? Colors.green
                                : task.status == 'In Progress'
                                    ? Colors.blue
                                    : task.status == 'Overdue'
                                        ? Colors.red
                                        : Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks) {
    print('Filtered Tasks in List: $tasks');
    if (tasks.isEmpty) {
      return const Center(child: Text('Chưa có công việc nào'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildTaskCard(task);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _getFilteredTasks();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Công việc'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelPadding: const EdgeInsets.symmetric(horizontal: 2.0), // Tăng chiều rộng
          tabs: const [
            Tab(
              child: Text(
                'Tất cả',
                softWrap: true,
                textAlign: TextAlign.center,
              ),
            ),
            Tab(
              child: Text(
                'Đang thực hiện',
                softWrap: true,
                textAlign: TextAlign.center,
              ),
            ),
            Tab(
              child: Text(
                'Hoàn thành',
                softWrap: true,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildTaskList(filteredTasks),
      floatingActionButton: _tabController.index != 2
          ? FloatingActionButton(
              onPressed: _addNewTask,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}