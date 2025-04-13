import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/category.dart';

class AddEditTaskScreen extends StatefulWidget {
  final int userId;
  final List<Category> categories;
  final Task? task;
  final Function(Task)? onTaskSaved;

  const AddEditTaskScreen({
    Key? key,
    required this.userId,
    required this.categories,
    this.task,
    this.onTaskSaved,
  }) : super(key: key);

  @override
  _AddEditTaskScreenState createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends State<AddEditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late int? _selectedCategoryId;
  late String _selectedPriority;
  late String _selectedStatus;
  bool _isLoading = false;


  final String apiBaseUrl = 'https://sever-todo-app-1.onrender.com';
  final List<String> _priorities = ['Thấp', 'Trung bình', 'Cao'];
  final List<String> _statuses = ['Chưa bắt đầu', 'Đang thực hiện', 'Hoàn thành', 'Quá hạn'];

  final Map<String, String> _priorityMapping = {
    'low': 'Thấp',
    'medium': 'Trung bình',
    'high': 'Cao',
  };
  final Map<String, String> _statusMapping = {
    'not_started': 'Chưa bắt đầu',
    'in_progress': 'Đang thực hiện',
    'completed': 'Hoàn thành',
    'overdue': 'Quá hạn',
  };

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _selectedDate = widget.task!.deadline.isBefore(now) ? now : widget.task!.deadline;
      _selectedTime = TimeOfDay.fromDateTime(widget.task!.deadline);
      final taskCategoryId = widget.task!.categoryId;
      _selectedCategoryId = widget.categories.any((c) => c.id == taskCategoryId)
          ? taskCategoryId
          : widget.categories.isNotEmpty
              ? widget.categories[0].id
              : null;
      _selectedPriority = _priorities.firstWhere(
        (p) => p.toLowerCase() == (_priorityMapping[widget.task!.priority.toLowerCase()] ?? widget.task!.priority).toLowerCase(),
        orElse: () => 'Trung bình',
      );
      _selectedStatus = _statuses.firstWhere(
        (s) => s.toLowerCase() == (_statusMapping[widget.task!.status.toLowerCase()] ?? widget.task!.status).toLowerCase(),
        orElse: () => 'Chưa bắt đầu',
      );
    } else {
      _selectedDate = now.add(const Duration(days: 1));
      _selectedTime = TimeOfDay.now();
      _selectedCategoryId = widget.categories.isNotEmpty ? widget.categories[0].id : null;
      _selectedPriority = 'Trung bình';
      _selectedStatus = 'Chưa bắt đầu';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, _selectedTime.hour, _selectedTime.minute);
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (pickedTime != null) {
      setState(() {
        _selectedTime = pickedTime;
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, pickedTime.hour, pickedTime.minute);
      });
    }
  }

  Future<bool> _checkReminderTimeExists(DateTime reminderTime) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/reminders?reminder_time=${reminderTime.toUtc().toIso8601String()}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) return jsonDecode(response.body).isNotEmpty;
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _createReminder(int taskId, DateTime reminderTime) async {
    if (await _checkReminderTimeExists(reminderTime)) {
      throw Exception('Thời gian nhắc nhở đã tồn tại.');
    }
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/reminders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'task_id': taskId,
          'user_id': widget.userId,
          'reminder_time': reminderTime.toUtc().toIso8601String(),
          'is_sent': false,
        }),
      );
      if (response.statusCode != 201) throw Exception('Failed to create reminder: ${response.statusCode}');
    } catch (e) {
      throw Exception('Lỗi khi tạo nhắc nhở: $e');
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) {
      if (_selectedCategoryId == null) _showError('Vui lòng chọn danh mục');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final deadline = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);
      final taskData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'deadline': deadline.toUtc().toIso8601String(),
        'priority': _priorityMapping.entries.firstWhere((e) => e.value == _selectedPriority).key,
        'status': _statusMapping.entries.firstWhere((e) => e.value == _selectedStatus).key,
        'category_id': _selectedCategoryId,
        if (widget.task == null) 'user_id': widget.userId,
      };
      final url = widget.task == null ? Uri.parse('$apiBaseUrl/api/tasks') : Uri.parse('$apiBaseUrl/api/tasks/${widget.task!.id}');
      final response = await (widget.task == null ? http.post : http.put)(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(taskData),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final savedTask = Task.fromJson(jsonDecode(response.body));
        if (widget.task == null) await _createReminder(savedTask.id, deadline);
        if (widget.onTaskSaved != null) widget.onTaskSaved!(savedTask);
        Navigator.pop(context, true);
      } else {
        throw Exception('Lỗi: ${response.statusCode}');
      }
    } catch (e) {
      _showError('$e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Thêm công việc' : 'Sửa công việc'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Tiêu đề',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.title, color: Colors.blue),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Vui lòng nhập tiêu đề' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Mô tả',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.description, color: Colors.blue),
                      ),
                      minLines: 3,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Danh mục',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.category, color: Colors.blue),
                      ),
                      value: _selectedCategoryId,
                      items: widget.categories.isEmpty
                          ? [const DropdownMenuItem<int>(value: null, child: Text('Không có danh mục'))]
                          : widget.categories.map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.categoryName))).toList(),
                      onChanged: widget.categories.isEmpty ? null : (value) => setState(() => _selectedCategoryId = value),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _selectDate,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Ngày hết hạn',
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                prefixIcon: const Icon(Icons.calendar_today, color: Colors.blue),
                              ),
                              child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: _selectTime,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Giờ',
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                prefixIcon: const Icon(Icons.access_time, color: Colors.blue),
                              ),
                              child: Text(_selectedTime.format(context)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Ưu tiên',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.priority_high, color: Colors.blue),
                      ),
                      value: _selectedPriority,
                      items: _priorities.map((p) => DropdownMenuItem<String>(value: p, child: Text(p))).toList(),
                      onChanged: (value) => setState(() => _selectedPriority = value!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Trạng thái',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.info, color: Colors.blue),
                      ),
                      value: _selectedStatus,
                      items: _statuses.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                      onChanged: (value) => setState(() => _selectedStatus = value!),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveTask,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(widget.task == null ? 'Thêm' : 'Cập nhật'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.blue),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Hủy', style: TextStyle(color: Colors.blue)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}