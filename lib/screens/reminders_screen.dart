import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart'; // Import thư viện
import '../models/reminder.dart';

class RemindersScreen extends StatefulWidget {
  final int userId;
  final int taskId;

  const RemindersScreen({Key? key, required this.userId, required this.taskId})
      : super(key: key);

  @override
  _RemindersScreenState createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Reminder> _reminders = [];
  bool _isLoading = true;
  final String baseUrl = 'https://sever-todo-app-1.onrender.com';

  @override
  void initState() {
    super.initState();
    _fetchReminders();
  }

  Future<void> _fetchReminders() async {
    setState(() => _isLoading = true);
    const maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries && mounted) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/tasks/${widget.taskId}/reminders'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          if (mounted) {
            setState(() {
              _reminders = data.map((json) => Reminder.fromJson(json)).toList();
              _isLoading = false;
            });
          }
          return;
        } else {
          throw Exception('Failed to load reminders: ${response.statusCode}');
        }
      } catch (e) {
        retryCount++;
        if (retryCount == maxRetries) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Không thể tải nhắc nhở: $e')),
            );
          }
          return;
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  bool _isReminderTimeDuplicate(DateTime reminderTime, {int? excludeId}) {
    final roundedTime = DateTime(
      reminderTime.year,
      reminderTime.month,
      reminderTime.day,
      reminderTime.hour,
      reminderTime.minute,
      reminderTime.second,
    );
    return _reminders.any((r) =>
        DateTime(
          r.reminderTime.year,
          r.reminderTime.month,
          r.reminderTime.day,
          r.reminderTime.hour,
          r.reminderTime.minute,
          r.reminderTime.second,
        ) == roundedTime &&
        (excludeId == null || r.id != excludeId));
  }

  Future<void> _createReminder(DateTime reminderTime) async {
    final roundedTime = DateTime(
      reminderTime.year,
      reminderTime.month,
      reminderTime.day,
      reminderTime.hour,
      reminderTime.minute,
      reminderTime.second,
    );

    if (_isReminderTimeDuplicate(roundedTime)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thời gian nhắc nhở đã tồn tại, vui lòng chọn thời gian khác'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final reminder = Reminder(
        id: 0,
        taskId: widget.taskId,
        userId: widget.userId,
        reminderTime: roundedTime,
        isSent: false,
      );

      print('Reminder data being sent: ${reminder.toJson()}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/reminders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(reminder.toJson()),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        await _fetchReminders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thêm nhắc nhở thành công'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final errorMessage = jsonDecode(response.body)['message'] ?? 'Lỗi không xác định';
        throw Exception('Failed to create reminder: ${response.statusCode} - $errorMessage');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi thêm nhắc nhở: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateReminder(Reminder reminder) async {
    final roundedTime = DateTime(
      reminder.reminderTime.year,
      reminder.reminderTime.month,
      reminder.reminderTime.day,
      reminder.reminderTime.hour,
      reminder.reminderTime.minute,
      reminder.reminderTime.second,
    );

    if (_isReminderTimeDuplicate(roundedTime, excludeId: reminder.id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thời gian nhắc nhở đã tồn tại, vui lòng chọn thời gian khác'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final updatedReminder = Reminder(
        id: reminder.id,
        taskId: reminder.taskId,
        userId: reminder.userId,
        reminderTime: roundedTime,
        isSent: reminder.isSent,
      );

      final response = await http.put(
        Uri.parse('$baseUrl/api/reminders/${reminder.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updatedReminder.toJson()),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await _fetchReminders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật nhắc nhở thành công'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final errorMessage = jsonDecode(response.body)['message'] ?? 'Lỗi không xác định';
        throw Exception('Failed to update reminder: ${response.statusCode} - $errorMessage');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cập nhật nhắc nhở: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa nhắc nhở này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/reminders/${reminder.id}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await _fetchReminders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Xóa nhắc nhở thành công'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to delete reminder: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa nhắc nhở: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReminderDialog({Reminder? reminder}) {
    final isEdit = reminder != null;
    DateTime _reminderTime = isEdit
        ? reminder.reminderTime
        : DateTime.now().add(const Duration(hours: 1));
    if (!isEdit) {
      while (_isReminderTimeDuplicate(_reminderTime)) {
        _reminderTime = _reminderTime.add(const Duration(minutes: 1));
      }
    }
    bool _isSent = isEdit ? reminder.isSent : false;
    bool _isTimeDuplicate = false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Cập nhật nhắc nhở' : 'Thêm nhắc nhở'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Thời gian: ${DateFormat('dd/MM/yyyy HH:mm').format(_reminderTime)}',
                  style: TextStyle(
                    color: _isTimeDuplicate ? Colors.red : Colors.black,
                  ),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _reminderTime,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_reminderTime),
                    );
                    if (pickedTime != null) {
                      final newTime = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                      setStateDialog(() {
                        _reminderTime = newTime;
                        _isTimeDuplicate = _isReminderTimeDuplicate(
                          _reminderTime,
                          excludeId: isEdit ? reminder.id : null,
                        );
                      });
                    }
                  }
                },
              ),
              if (_isTimeDuplicate)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Thời gian này đã tồn tại, vui lòng chọn thời gian khác',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              if (isEdit)
                SwitchListTile(
                  title: const Text('Đã gửi'),
                  value: _isSent,
                  onChanged: (value) => setStateDialog(() => _isSent = value),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: _isTimeDuplicate
                ? null
                : () async {
                    if (isEdit) {
                      final updatedReminder = Reminder(
                        id: reminder.id,
                        taskId: reminder.taskId,
                        userId: reminder.userId,
                        reminderTime: _reminderTime,
                        isSent: _isSent,
                      );
                      await _updateReminder(updatedReminder);
                    } else {
                      await _createReminder(_reminderTime);
                    }
                    Navigator.pop(context);
                  },
            child: Text(isEdit ? 'Cập nhật' : 'Thêm'),
          ),
        ],
      ),
    );
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
          : _reminders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Chưa có nhắc nhở nào',
                          style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchReminders,
                        child: const Text('Tải lại'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _reminders.length,
                  itemBuilder: (context, index) {
                    final reminder = _reminders[index];
                    return Slidable(
                      // Hành động khi vuốt sang phải (endActionPane)
                      endActionPane: ActionPane(
                        motion: const ScrollMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (_) => _showReminderDialog(reminder: reminder),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            icon: Icons.edit,
                            label: 'Sửa',
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                          ),
                          SlidableAction(
                            onPressed: (_) => _deleteReminder(reminder),
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            icon: Icons.delete,
                            label: 'Xóa',
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                          ),
                        ],
                      ),
                      child: Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(
                            'Nhắc nhở: ${DateFormat('dd/MM/yyyy HH:mm').format(reminder.reminderTime)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Công việc ID: ${reminder.taskId} - ${reminder.isSent ? 'Đã gửi' : 'Chưa gửi'}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showReminderDialog(),
        tooltip: 'Thêm nhắc nhở',
        child: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.blue.shade700,
      ),
    );
  }
}