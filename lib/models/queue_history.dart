import 'package:cloud_firestore/cloud_firestore.dart';

class QueueHistory {
  const QueueHistory({
    required this.id,
    required this.entryId,
    required this.studentId,
    required this.serviceId,
    required this.departmentId,
    required this.tokenCode,
    required this.outcome,
    required this.occurredAt,
  });

  final String id;
  final String entryId;
  final String studentId;
  final String serviceId;
  final String departmentId;
  final String tokenCode;
  final String outcome;
  final DateTime? occurredAt;

  factory QueueHistory.fromMap(String id, Map<String, dynamic> data) {
    final timestamp = data['completedAt'] ?? data['occurredAt'];
    return QueueHistory(
      id: id,
      entryId: data['entryId'] as String? ?? id,
      studentId: data['studentId'] as String? ?? '',
      serviceId: data['serviceId'] as String? ?? '',
      departmentId: data['departmentId'] as String? ?? '',
      tokenCode: data['tokenCode'] as String? ?? '',
      outcome: data['outcome'] as String? ?? 'completed',
      occurredAt: timestamp is Timestamp
          ? timestamp.toDate()
          : timestamp is DateTime
              ? timestamp
              : null,
    );
  }
}
