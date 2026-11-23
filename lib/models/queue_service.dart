import 'package:cloud_firestore/cloud_firestore.dart';

class QueueService {
  const QueueService({
    required this.id,
    required this.departmentId,
    required this.name,
    required this.averageServiceTime,
    required this.gracePeriodMin,
    required this.holdWindowMin,
    required this.counterStatus,
    required this.lastTokenNumber,
    required this.prefix,
    this.breakUntil,
    this.breakStartedAt,
  });

  final String id;
  final String departmentId;
  final String name;
  final int averageServiceTime;
  final int gracePeriodMin;
  final int holdWindowMin;
  final String counterStatus;
  final int lastTokenNumber;
  final String prefix;
  final DateTime? breakUntil;
  final DateTime? breakStartedAt;

  bool get isOpen => counterStatus == 'open';
  bool get acceptsTokens => counterStatus == 'open' || counterStatus == 'break';

  factory QueueService.fromMap(String id, Map<String, dynamic> data) =>
      QueueService(
        id: id,
        departmentId: data['departmentId'] as String? ?? '',
        name: data['name'] as String? ?? 'Service',
        averageServiceTime: (data['averageServiceTime'] as num?)?.toInt() ?? 5,
        gracePeriodMin: (data['gracePeriodMin'] as num?)?.toInt() ?? 5,
        holdWindowMin: (data['holdWindowMin'] as num?)?.toInt() ?? 10,
        counterStatus: data['counterStatus'] as String? ?? 'closed',
        lastTokenNumber: (data['lastTokenNumber'] as num?)?.toInt() ?? 0,
        prefix: data['prefix'] as String? ?? 'F',
        breakUntil: data['breakUntil'] is Timestamp
            ? (data['breakUntil'] as Timestamp).toDate()
            : data['breakUntil'] as DateTime?,
        breakStartedAt: data['breakStartedAt'] is Timestamp
            ? (data['breakStartedAt'] as Timestamp).toDate()
            : data['breakStartedAt'] as DateTime?,
      );
}
