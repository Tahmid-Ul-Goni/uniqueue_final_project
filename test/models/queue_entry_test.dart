import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniqueue/models/queue_entry.dart';

void main() {
  group('QueueStatusLabel', () {
    test('parses every persisted status name', () {
      for (final status in QueueStatus.values) {
        expect(QueueStatusLabel.parse(status.name), status);
      }
    });

    test('rejects unknown persisted status names', () {
      expect(
        () => QueueStatusLabel.parse('inProgress'),
        throwsA(isA<FormatException>()),
      );
    });

    test('marks only queue states that can still progress as active', () {
      for (final status in const [
        QueueStatus.waiting,
        QueueStatus.approaching,
        QueueStatus.called,
        QueueStatus.serving,
        QueueStatus.onHold,
      ]) {
        expect(status.isActive, isTrue, reason: status.name);
      }

      for (final status in const [
        QueueStatus.completed,
        QueueStatus.cancelled,
        QueueStatus.expired,
      ]) {
        expect(status.isActive, isFalse, reason: status.name);
      }
    });
  });

  group('QueueEntry.fromMap', () {
    test('converts Firestore timestamps and numeric values', () {
      final createdAt = DateTime.utc(2026, 11, 20, 9);
      final updatedAt = DateTime.utc(2026, 11, 20, 9, 5);
      final entry = QueueEntry.fromMap('entry-1', {
        'studentId': 'student-1',
        'serviceId': 'finance',
        'departmentId': 'admin',
        'tokenCode': 'F-014',
        'tokenNumber': 14.0,
        'averageServiceTime': 6.0,
        'status': 'waiting',
        'qrPayload': '{"entryId":"entry-1"}',
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      });

      expect(entry.id, 'entry-1');
      expect(entry.tokenNumber, 14);
      expect(entry.averageServiceTime, 6);
      expect(entry.status, QueueStatus.waiting);
      // Firestore Timestamp.toDate() returns a local DateTime, so compare instants.
      expect(entry.createdAt.isAtSameMomentAs(createdAt), isTrue);
      expect(entry.updatedAt.isAtSameMomentAs(updatedAt), isTrue);
      expect(entry.studentFirstName, isEmpty);
      expect(entry.calledAt, isNull);
    });

    test('uses documented defaults for absent optional and date values', () {
      final entry = QueueEntry.fromMap('entry-2', {'status': 'completed'});

      expect(entry.averageServiceTime, 5);
      expect(entry.tokenNumber, 0);
      expect(entry.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
      expect(entry.updatedAt, DateTime.fromMillisecondsSinceEpoch(0));
      expect(entry.studentFirstName, isEmpty);
      expect(entry.status, QueueStatus.completed);
    });
  });
}
