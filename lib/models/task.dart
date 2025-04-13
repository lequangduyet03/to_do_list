class Task {
  final int id;
  final String title;
  final String description;
  final DateTime deadline;
  final String priority;
  final String status;
  final int categoryId;
  final int userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.deadline,
    required this.priority,
    required this.status,
    required this.categoryId,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    String apiStatus = json['status'] as String;
    String displayStatus;

    // Chỉ ánh xạ trạng thái từ API, không tính toán "Overdue"
    switch (apiStatus) {
      case 'not_started':
        displayStatus = 'Pending';
        break;
      case 'in_progress':
        displayStatus = 'In Progress';
        break;
      case 'completed':
        displayStatus = 'Completed';
        break;
        
      default:
        displayStatus = 'Pending';
    }

    return Task(
      id: json['task_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      deadline: DateTime.parse(json['deadline'] as String),
      priority: json['priority'] as String,
      status: displayStatus,
      categoryId: json['category_id'] as int,
      userId: json['user_id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    String apiStatus;
    switch (status) {
      case 'Pending':
        apiStatus = 'not_started';
        break;
      case 'In Progress':
        apiStatus = 'in_progress';
        break;
      case 'Completed':
        apiStatus = 'completed';
        break;
      default:
        apiStatus = 'not_started';
    }

    return {
      'task_id': id,
      'title': title,
      'description': description,
      'deadline': deadline.toIso8601String(),
      'priority': priority,
      'status': apiStatus,
      'category_id': categoryId,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
  
bool get isOverdue {
  return status != 'Completed' && DateTime.now().isAfter(deadline);
}

String get effectiveStatus {
  if (isOverdue) {
    return 'Overdue';
  }
  return status;
}
}