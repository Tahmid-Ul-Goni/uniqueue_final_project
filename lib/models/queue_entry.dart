import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/strings.dart';

enum QueueStatus {
  waiting,
  approaching,
  called,
  serving,
  onHold,
  completed,
  cancelled,
  expired
}

extension QueueStatusLabel on QueueStatus {
  String get label => switch (this) {
        QueueStatus.waiting => UniQueueStrings.statusWaiting,
        QueueStatus.approaching ||
        QueueStatus.called =>
          UniQueueStrings.statusApproaching,
        QueueStatus.serving => UniQueueStrings.statusServing,
        QueueStatus.onHold => UniQueueStrings.statusOnHold,
        QueueStatus.completed => UniQueueStrings.statusCompleted,
        QueueStatus.cancelled => UniQueueStrings.statusCancelled,
        QueueStatus.expired => UniQueueStrings.statusExpired,
      };
  bool get isActive => switch (this) {
        QueueStatus.waiting ||
        QueueStatus.approaching ||
        QueueStatus.called ||
        QueueStatus.serving ||
        QueueStatus.onHold =>
          true,
        QueueStatus.completed ||
        QueueStatus.cancelled ||
        QueueStatus.expired =>
          false,
      };

  static QueueStatus parse(String? value) => QueueStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => throw FormatException('Unknown queue status: $value'),
      );
}

class QueueEntry {
  const QueueEntry({
    required this.id,
    required this.studentId,
    required this.serviceId,
    required this.departmentId,
    required this.tokenCode,
    required this.tokenNumber,
    this.averageServiceTime = 5,
    required this.status,
    required this.qrPayload,
    required this.createdAt,
    required this.updatedAt,
    this.studentFirstName = '',
    this.calledAt,
    this.graceEndsAt,
    this.holdEndsAt,
    this.servedBy,
    this.startedAt,
    this.completedAt,
  });

  final String id;
  final String studentId;
  final String serviceId;
  final String departmentId;
  final String tokenCode;
  final int tokenNumber;
  final int averageServiceTime;
  final QueueStatus status;
  final String qrPayload;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String studentFirstName;
  final DateTime? calledAt;
  final DateTime? graceEndsAt;
  final DateTime? holdEndsAt;
  final String? servedBy;
  final DateTime? startedAt;
  final DateTime? completedAt;

  factory QueueEntry.fromMap(String id, Map<String, dynamic> data) {
    DateTime date(String key) {
      final value = data[key];
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    DateTime? optionalDate(String key) => data[key] == null ? null : date(key);

    return QueueEntry(
      id: id,
      studentId: data['studentId'] as String? ?? '',
      serviceId: data['serviceId'] as String? ?? '',
      departmentId: data['departmentId'] as String? ?? '',
      tokenCode: data['tokenCode'] as String? ?? '',
      tokenNumber: (data['tokenNumber'] as num?)?.toInt() ?? 0,
      averageServiceTime: (data['averageServiceTime'] as num?)?.toInt() ?? 5,
      status: QueueStatusLabel.parse(data['status'] as String?),
      qrPayload: data['qrPayload'] as String? ?? '',
      createdAt: date('createdAt'),
      updatedAt: date('updatedAt'),
      studentFirstName: data['studentFirstName'] as String? ?? '',
      calledAt: optionalDate('calledAt'),
      graceEndsAt: optionalDate('graceEndsAt'),
      holdEndsAt: optionalDate('holdEndsAt'),
      servedBy: data['servedBy'] as String?,
      startedAt: optionalDate('startedAt'),
      completedAt: optionalDate('completedAt'),
    );
  }
}
