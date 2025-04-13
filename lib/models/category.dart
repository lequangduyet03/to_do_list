import 'package:flutter/material.dart';

class Category {
  final int id;
  final String categoryName;
  final String color;
  final int userId;

  Category({
    required this.id,
    required this.categoryName,
    required this.color,
    required this.userId,
  });

  // Phương thức để chuyển đổi chuỗi màu thành Color
  Color getColorValue() {
    try {
      return Color(int.parse(color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF4285F4); // Màu mặc định nếu không parse được
    }
  }

  // Constructor từ JSON
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['category_id'] ?? json['id'] ?? 0,
      categoryName: json['category_name'] ?? json['categoryName'] ?? 'Khác',
      color: json['color'] ?? '#4285F4',
      userId: json['user_id'] ?? json['userId'] ?? 0,
    );
  }

  // Chuyển đổi Category thành JSON
  Map<String, dynamic> toJson() {
    return {
      'category_id': id,
      'category_name': categoryName,
      'color': color,
      'user_id': userId,
    };
  }
}