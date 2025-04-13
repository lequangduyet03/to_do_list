class Reminder {
  final int id;
  final int taskId;
  final int userId;
  final DateTime reminderTime;
  final bool isSent;

  Reminder({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.reminderTime,
    required this.isSent,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as int,
      taskId: json['task_id'] as int,
      userId: json['user_id'] as int,
      reminderTime: DateTime.parse(json['reminder_time'] as String),
      isSent: json['is_sent'] as bool, // Thay đổi: trực tiếp lấy bool
    );
  }

  Map<String, dynamic> toJson() {
    // Làm tròn thời gian để bỏ mili-giây
    final roundedTime = DateTime(
      reminderTime.year,
      reminderTime.month,
      reminderTime.day,
      reminderTime.hour,
      reminderTime.minute,
      reminderTime.second,
    );
    return {
      'id': id,
      'task_id': taskId,
      'user_id': userId,
      'reminder_time': '${roundedTime.toUtc().toIso8601String().split('.')[0]}Z', // Định dạng đúng: bỏ mili-giây và thêm Z
      'is_sent': isSent, // Gửi bool trực tiếp, backend Go sẽ hiểu
    };
  }
}