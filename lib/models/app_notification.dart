import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.entryId,
  });

  final String id;
  final String userId;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;
  final String? entryId;

  factory AppNotification.fromMap(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    return AppNotification(
      id: id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? 'Queue update',
      message: data['message'] as String? ?? '',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: created is Timestamp
          ? created.toDate()
          : created is DateTime
              ? created
              : null,
      entryId: data['entryId'] as String?,
    );
  }
}
