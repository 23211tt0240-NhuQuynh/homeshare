import 'package:cloud_firestore/cloud_firestore.dart';

/// Model quy định lỗi vi phạm và mức điểm uy tín trừ tương ứng
class ViolationRuleModel {
  final String id;
  final String title;
  final String description;
  final int defaultPoints;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ViolationRuleModel({
    required this.id,
    required this.title,
    required this.description,
    required this.defaultPoints,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'defaultPoints': defaultPoints,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ViolationRuleModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    return ViolationRuleModel(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      defaultPoints: (map['defaultPoints'] as num?)?.toInt() ?? 10,
      isActive: map['isActive'] != false,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  ViolationRuleModel copyWith({
    String? id,
    String? title,
    String? description,
    int? defaultPoints,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ViolationRuleModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      defaultPoints: defaultPoints ?? this.defaultPoints,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
