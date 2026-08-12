class NotificationModel {
  final String id;
  final String businessId;
  final String userId;
  final String title;
  final String message;
  final String notificationType;
  final String? referenceType;
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.title,
    required this.message,
    required this.notificationType,
    this.referenceType,
    this.referenceId,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      notificationType: json['notification_type'] as String,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'user_id': userId,
      'title': title,
      'message': message,
      'notification_type': notificationType,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? businessId,
    String? userId,
    String? title,
    String? message,
    String? notificationType,
    String? referenceType,
    String? referenceId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      notificationType: notificationType ?? this.notificationType,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationModel &&
        other.id == id &&
        other.businessId == businessId &&
        other.userId == userId &&
        other.title == title &&
        other.message == message &&
        other.notificationType == notificationType &&
        other.referenceType == referenceType &&
        other.referenceId == referenceId &&
        other.isRead == isRead &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      businessId,
      userId,
      title,
      message,
      notificationType,
      referenceType,
      referenceId,
      isRead,
      createdAt,
    );
  }
}
