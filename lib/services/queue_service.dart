import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';
import '../models/queue_history.dart';
import '../models/queue_entry.dart';
import '../models/queue_service.dart' as model;

class QueueFailure implements Exception {
  const QueueFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class QueuePosition {
  const QueuePosition(
      {required this.position,
      required this.peopleAhead,
      required this.waitMinutes});

  final int position;
  final int peopleAhead;
  final int waitMinutes;
}

class QueueServiceRepository {
  QueueServiceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _activeStatuses = ['waiting', 'approaching', 'called'];

  Stream<List<model.QueueService>> watchServices(String departmentId) =>
      _firestore
          .collection('services')
          .where('departmentId', isEqualTo: departmentId)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => model.QueueService.fromMap(doc.id, doc.data()))
              .toList(growable: false));

  Stream<List<QueueEntry>> watchQueue(String serviceId,
      {String? departmentId}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('queueEntries')
        .where('serviceId', isEqualTo: serviceId);
    if (departmentId != null) {
      query = query.where('departmentId', isEqualTo: departmentId);
    }
    return query.orderBy('tokenNumber').snapshots().map((snapshot) => snapshot
        .docs
        .map((doc) => QueueEntry.fromMap(doc.id, doc.data()))
        .toList(growable: false));
  }

  Stream<List<Map<String, dynamic>>> watchPublicQueue(String serviceId) =>
      _firestore
          .collection('queuePublic')
          .where('serviceId', isEqualTo: serviceId)
          .orderBy('tokenNumber')
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => doc.data()).toList(growable: false));

  Stream<model.QueueService?> watchService(String serviceId) => _firestore
      .collection('services')
      .doc(serviceId)
      .snapshots()
      .map((snapshot) => snapshot.exists && snapshot.data() != null
          ? model.QueueService.fromMap(snapshot.id, snapshot.data()!)
          : null);

  Stream<List<QueueEntry>> watchStudentEntries(String studentId) => _firestore
      .collection('queueEntries')
      .where('studentId', isEqualTo: studentId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => QueueEntry.fromMap(doc.id, doc.data()))
          .toList(growable: false));

  Stream<QueueEntry?> watchEntry(String entryId) => _firestore
      .collection('queueEntries')
      .doc(entryId)
      .snapshots()
      .map((snapshot) => snapshot.exists && snapshot.data() != null
          ? QueueEntry.fromMap(snapshot.id, snapshot.data()!)
          : null);

  Stream<List<AppNotification>> watchNotifications(String userId) => _firestore
      .collection('notifications')
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
          .toList(growable: false));
  Future<void> markNotificationRead(String notificationId) => _firestore
      .collection('notifications')
      .doc(notificationId)
      .update({'isRead': true});

  Stream<List<QueueHistory>> watchHistory({
    required bool forStudent,
    required String userId,
    String? departmentId,
  }) {
    final query = forStudent
        ? _firestore
            .collection('queueHistory')
            .where('studentId', isEqualTo: userId)
        : _firestore
            .collection('queueHistory')
            .where('departmentId', isEqualTo: departmentId);
    return query.orderBy('completedAt', descending: true).snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => QueueHistory.fromMap(doc.id, doc.data()))
            .toList(growable: false));
  }

  Stream<QueuePosition> watchPosition(QueueEntry entry,
          [int? averageServiceTime]) =>
      _firestore
          .collection('queuePublic')
          .where('serviceId', isEqualTo: entry.serviceId)
          .where('status', whereIn: _activeStatuses)
          .snapshots()
          .map((snapshot) {
        final ahead = snapshot.docs
            .where((doc) =>
                (doc.data()['tokenNumber'] as num).toInt() < entry.tokenNumber)
            .length;
        return QueuePosition(
          position: ahead + 1,
          peopleAhead: ahead,
          waitMinutes: ahead * (averageServiceTime ?? entry.averageServiceTime),
        );
      });

  Future<QueueEntry> validateQrPayload(
    String payload, {
    required String departmentId,
    required String serviceId,
  }) async {
    Map<String, dynamic> decoded;
    try {
      final value = jsonDecode(payload);
      if (value is! Map<String, dynamic>) throw const FormatException();
      decoded = value;
    } on FormatException {
      throw const QueueFailure(
          'This QR code is not a UniQueue token. Ask the student to open their latest token.');
    }

    final entryId = decoded['entryId'];
    if (entryId is! String || entryId.isEmpty) {
      throw const QueueFailure(
          'This QR code is incomplete. Ask the student to open their latest token.');
    }

    try {
      final snapshot =
          await _firestore.collection('queueEntries').doc(entryId).get();
      if (!snapshot.exists || snapshot.data() == null) {
        throw const QueueFailure(
            'This token could not be found. Ask the student to refresh their token.');
      }
      final data = snapshot.data()!;
      if (data['departmentId'] != departmentId ||
          data['serviceId'] != serviceId) {
        throw const QueueFailure(
            'This token is for a different counter. Select the matching service.');
      }
      if (decoded['serviceId'] != serviceId ||
          decoded['tokenCode'] != data['tokenCode'] ||
          decoded['nonce'] != data['qrNonce']) {
        throw const QueueFailure(
            'This token is not valid. Ask the student to open the latest token.');
      }

      final status = QueueStatusLabel.parse(data['status'] as String?);
      if (status == QueueStatus.completed || status == QueueStatus.serving) {
        throw const QueueFailure('This token has already been used.');
      }
      if (status == QueueStatus.cancelled || status == QueueStatus.expired) {
        throw const QueueFailure(
            'This token has expired or was cancelled. Ask the student to get a new token.');
      }
      if (status == QueueStatus.onHold) {
        throw const QueueFailure(
            'This token is on hold. Ask the student to resume it first.');
      }
      if (status != QueueStatus.called) {
        throw const QueueFailure(
            'This student is not next yet. Continue serving the queue.');
      }

      final graceEndsAt = data['graceEndsAt'];
      if (graceEndsAt is Timestamp &&
          graceEndsAt.toDate().isBefore(DateTime.now())) {
        await transition(entryId, QueueStatus.onHold);
        throw const QueueFailure(
            'The grace period ended. This token is now on hold.');
      }
      return QueueEntry.fromMap(snapshot.id, data);
    } on QueueFailure {
      rethrow;
    } on FirebaseException {
      throw const QueueFailure(
          'Could not validate this QR code. Check your connection and scan again.');
    }
  }

  Future<void> startBreak(String serviceId,
      {required Duration duration}) async {
    final serviceRef = _firestore.collection('services').doc(serviceId);
    final now = DateTime.now();
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(serviceRef);
        final data = snapshot.data();
        if (data == null || !snapshot.exists) {
          throw const QueueFailure(
              'The service is unavailable. Refresh and try again.');
        }
        if (data['counterStatus'] == 'break') {
          throw const QueueFailure('This counter is already on break.');
        }
        transaction.update(serviceRef, {
          'counterStatus': 'break',
          'breakStartedAt': Timestamp.fromDate(now),
          'breakUntil': Timestamp.fromDate(now.add(duration)),
        });
      });
      await _notifyServiceStudents(
        serviceId,
        title: 'Counter on break',
        message: 'The counter is on break. Your place is safe.',
      );
    } on QueueFailure {
      rethrow;
    } on FirebaseException {
      throw const QueueFailure(
          'Could not start the break. Check your connection and retry.');
    }
  }

  Future<void> endBreak(String serviceId) async {
    final serviceRef = _firestore.collection('services').doc(serviceId);
    DateTime? startedAt;
    try {
      final serviceSnapshot = await serviceRef.get();
      final serviceData = serviceSnapshot.data();
      if (!serviceSnapshot.exists ||
          serviceData == null ||
          serviceData['counterStatus'] != 'break') {
        return;
      }
      final startValue = serviceData['breakStartedAt'];
      if (startValue is Timestamp) startedAt = startValue.toDate();
      final pause = startedAt == null
          ? Duration.zero
          : DateTime.now().difference(startedAt);
      final entries = await _firestore
          .collection('queueEntries')
          .where('serviceId', isEqualTo: serviceId)
          .where('departmentId', isEqualTo: serviceData['departmentId'])
          .where('status', whereIn: const ['called', 'onHold']).get();
      final now = DateTime.now();

      for (var offset = 0; offset < entries.docs.length; offset += 400) {
        final batch = _firestore.batch();
        final chunk = entries.docs.skip(offset).take(400);
        for (final doc in chunk) {
          final updates = <String, dynamic>{
            'updatedAt': Timestamp.fromDate(now)
          };
          final grace = doc.data()['graceEndsAt'];
          final hold = doc.data()['holdEndsAt'];
          if (grace is Timestamp) {
            updates['graceEndsAt'] =
                Timestamp.fromDate(grace.toDate().add(pause));
          }
          if (hold is Timestamp) {
            updates['holdEndsAt'] =
                Timestamp.fromDate(hold.toDate().add(pause));
          }
          batch.update(doc.reference, updates);
          final notification = _firestore.collection('notifications').doc();
          batch.set(notification, {
            'userId': doc.data()['studentId'],
            'entryId': doc.id,
            'title': 'Counter resumed',
            'message':
                'The counter is open again. Your queue timer has resumed.',
            'isRead': false,
            'createdAt': Timestamp.fromDate(now),
          });
        }
        await batch.commit();
      }

      await _firestore.runTransaction((transaction) async {
        final current = await transaction.get(serviceRef);
        if (current.data()?['counterStatus'] != 'break') return;
        transaction.update(serviceRef, {
          'counterStatus': 'open',
          'breakUntil': FieldValue.delete(),
          'breakStartedAt': FieldValue.delete(),
        });
      });
    } on FirebaseException {
      throw const QueueFailure(
          'Could not resume the queue. Reconnect and try again.');
    }
  }

  Future<void> checkTimers(String serviceId) async {
    final serviceRef = _firestore.collection('services').doc(serviceId);
    final serviceSnapshot = await serviceRef.get();
    final data = serviceSnapshot.data();
    if (!serviceSnapshot.exists || data == null) return;
    if (data['counterStatus'] == 'break') {
      final breakUntil = data['breakUntil'];
      if (breakUntil is Timestamp &&
          !breakUntil.toDate().isAfter(DateTime.now())) {
        await endBreak(serviceId);
      } else {
        return;
      }
    }

    final entries = await _firestore
        .collection('queueEntries')
        .where('serviceId', isEqualTo: serviceId)
        .where('departmentId', isEqualTo: data['departmentId'])
        .where('status', whereIn: const ['called', 'onHold']).get();
    final now = DateTime.now();
    for (final doc in entries.docs) {
      final entryData = doc.data();
      final status = QueueStatusLabel.parse(entryData['status'] as String?);
      final deadline = status == QueueStatus.called
          ? entryData['graceEndsAt']
          : entryData['holdEndsAt'];
      if (status == QueueStatus.called &&
          deadline is Timestamp &&
          entryData['graceWarningSent'] != true) {
        final secondsLeft = deadline.toDate().difference(now).inSeconds;
        if (secondsLeft > 0 && secondsLeft <= 60) {
          await _sendGraceEndingReminder(doc.reference, doc.id);
        }
      }
      if (deadline is Timestamp && !deadline.toDate().isAfter(now)) {
        final next = status == QueueStatus.called
            ? QueueStatus.onHold
            : QueueStatus.expired;
        try {
          await transition(doc.id, next);
        } on QueueFailure {
          // Another connected client may have completed the same timer transition.
        }
      }
    }

    final upcoming = await _firestore
        .collection('queueEntries')
        .where('serviceId', isEqualTo: serviceId)
        .where('departmentId', isEqualTo: data['departmentId'])
        .where('status', whereIn: _activeStatuses)
        .orderBy('tokenNumber')
        .get();
    var ahead = 0;
    for (final doc in upcoming.docs) {
      final status = QueueStatusLabel.parse(doc.data()['status'] as String?);
      if (status == QueueStatus.waiting && ahead <= 5) {
        try {
          await transition(doc.id, QueueStatus.approaching);
        } on QueueFailure {
          // Another connected client may have advanced this entry already.
        }
      }
      if ({QueueStatus.waiting, QueueStatus.approaching, QueueStatus.called}
          .contains(status)) {
        ahead++;
      }
    }
  }

  Future<void> _sendGraceEndingReminder(
    DocumentReference<Map<String, dynamic>> entryRef,
    String entryId,
  ) async {
    final notificationRef = _firestore.collection('notifications').doc();
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(entryRef);
      final data = snapshot.data();
      final deadline = data?['graceEndsAt'];
      if (data == null ||
          data['status'] != QueueStatus.called.name ||
          data['graceWarningSent'] == true ||
          deadline is! Timestamp) {
        return;
      }
      final remaining = deadline.toDate().difference(DateTime.now()).inSeconds;
      if (remaining <= 0 || remaining > 60) return;
      transaction.update(entryRef, {'graceWarningSent': true});
      transaction.set(notificationRef, {
        'userId': data['studentId'],
        'entryId': entryId,
        'title': 'One minute left',
        'message': 'Please reach the counter now to keep your queue place.',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _notifyServiceStudents(
    String serviceId, {
    required String title,
    required String message,
  }) async {
    final service =
        await _firestore.collection('services').doc(serviceId).get();
    final departmentId = service.data()?['departmentId'];
    if (departmentId is! String || departmentId.isEmpty) return;
    final entries = await _firestore
        .collection('queueEntries')
        .where('serviceId', isEqualTo: serviceId)
        .where('departmentId', isEqualTo: departmentId)
        .where('status', whereIn: const [
      'waiting',
      'approaching',
      'called',
      'onHold'
    ]).get();
    for (var offset = 0; offset < entries.docs.length; offset += 450) {
      final batch = _firestore.batch();
      for (final doc in entries.docs.skip(offset).take(450)) {
        final notification = _firestore.collection('notifications').doc();
        batch.set(notification, {
          'userId': doc.data()['studentId'],
          'entryId': doc.id,
          'title': title,
          'message': message,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Future<QueueEntry> createToken({
    required String studentId,
    required String studentFirstName,
    required String serviceId,
  }) async {
    final serviceRef = _firestore.collection('services').doc(serviceId);
    final claimId =
        '${Uri.encodeComponent(studentId)}__${Uri.encodeComponent(serviceId)}';
    final claimRef = _firestore.collection('activeTokens').doc(claimId);
    final entryRef = _firestore.collection('queueEntries').doc();
    final now = DateTime.now();

    try {
      await _firestore.runTransaction((transaction) async {
        final serviceSnapshot = await transaction.get(serviceRef);
        final claimSnapshot = await transaction.get(claimRef);
        if (!serviceSnapshot.exists || serviceSnapshot.data() == null) {
          throw const QueueFailure(
              'This service is unavailable. Choose another service.');
        }

        final service =
            model.QueueService.fromMap(serviceId, serviceSnapshot.data()!);
        if (!service.acceptsTokens) {
          throw const QueueFailure(
              'This counter is closed. Choose another available service.');
        }

        if (claimSnapshot.exists) {
          final oldEntryId = claimSnapshot.data()?['entryId'] as String?;
          if (oldEntryId != null) {
            final oldEntryRef =
                _firestore.collection('queueEntries').doc(oldEntryId);
            final oldEntrySnapshot = await transaction.get(oldEntryRef);
            final oldStatus = oldEntrySnapshot.data()?['status'] as String?;
            if (oldEntrySnapshot.exists &&
                QueueStatusLabel.parse(oldStatus).isActive) {
              throw const QueueFailure(
                  'You already have an active token for this service.');
            }
          }
        }

        final number = service.lastTokenNumber + 1;
        final tokenCode =
            '${service.prefix}-${number.toString().padLeft(3, '0')}';
        final nonce = _newNonce();
        final qrPayload = jsonEncode({
          'entryId': entryRef.id,
          'tokenCode': tokenCode,
          'serviceId': serviceId,
          'nonce': nonce,
        });
        final entry = <String, dynamic>{
          'studentId': studentId,
          'studentFirstName': studentFirstName,
          'serviceId': serviceId,
          'departmentId': service.departmentId,
          'tokenCode': tokenCode,
          'tokenNumber': number,
          'averageServiceTime': service.averageServiceTime,
          'status': QueueStatus.waiting.name,
          'qrPayload': qrPayload,
          'qrNonce': nonce,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        };
        transaction.update(serviceRef, {
          'lastTokenNumber': number,
          'lastIssuedEntryId': entryRef.id,
        });
        transaction.set(entryRef, entry);
        transaction.set(_firestore.collection('queuePublic').doc(entryRef.id), {
          'serviceId': serviceId,
          'departmentId': service.departmentId,
          'tokenCode': tokenCode,
          'tokenNumber': number,
          'status': QueueStatus.waiting.name,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
        transaction.set(claimRef, {
          'studentId': studentId,
          'serviceId': serviceId,
          'departmentId': service.departmentId,
          'entryId': entryRef.id,
        });
        final notificationRef = _firestore.collection('notifications').doc();
        transaction.set(notificationRef, {
          'userId': studentId,
          'entryId': entryRef.id,
          'title': 'You’re in the queue',
          'message': '$tokenCode is waiting.',
          'isRead': false,
          'createdAt': Timestamp.fromDate(now),
        });
      });

      final created = await entryRef.get();
      return QueueEntry.fromMap(entryRef.id, created.data()!);
    } on QueueFailure {
      rethrow;
    } on FirebaseException {
      throw const QueueFailure(
          'Could not get a token. Check your connection and try again.');
    }
  }

  Future<void> transition(String entryId, QueueStatus nextStatus,
      {String? staffId}) async {
    final entryRef = _firestore.collection('queueEntries').doc(entryId);
    final now = DateTime.now();
    try {
      await _firestore.runTransaction((transaction) async {
        final entrySnapshot = await transaction.get(entryRef);
        if (!entrySnapshot.exists || entrySnapshot.data() == null) {
          throw const QueueFailure(
              'This token could not be found. Refresh the queue and try again.');
        }
        final data = entrySnapshot.data()!;
        final currentStatus = QueueStatusLabel.parse(data['status'] as String?);
        if (currentStatus == QueueStatus.onHold &&
            nextStatus == QueueStatus.called) {
          final holdEndsAt = data['holdEndsAt'];
          if (holdEndsAt is Timestamp && !holdEndsAt.toDate().isAfter(now)) {
            throw const QueueFailure(
              'Your hold time has ended. Get a new token to join the queue again.',
            );
          }
        }
        if (!_canTransition(currentStatus, nextStatus)) {
          throw QueueFailure(
              'This token can’t move from ${currentStatus.label} to ${nextStatus.label}.');
        }

        final serviceRef =
            _firestore.collection('services').doc(data['serviceId'] as String);
        final serviceSnapshot = await transaction.get(serviceRef);
        if (!serviceSnapshot.exists || serviceSnapshot.data() == null) {
          throw const QueueFailure(
              'The queue service is unavailable. Try again.');
        }
        final service =
            model.QueueService.fromMap(serviceRef.id, serviceSnapshot.data()!);
        final publicRef = _firestore.collection('queuePublic').doc(entryId);
        final publicSnapshot = await transaction.get(publicRef);
        if (!publicSnapshot.exists) {
          throw const QueueFailure(
              'Queue display data is missing. Ask an administrator to check the queue.');
        }

        DocumentReference<Map<String, dynamic>>? claimRef;
        DocumentSnapshot<Map<String, dynamic>>? claimSnapshot;
        if ({QueueStatus.completed, QueueStatus.cancelled, QueueStatus.expired}
            .contains(nextStatus)) {
          claimRef = _firestore.collection('activeTokens').doc(
                '${Uri.encodeComponent(data['studentId'] as String)}__'
                '${Uri.encodeComponent(data['serviceId'] as String)}',
              );
          claimSnapshot = await transaction.get(claimRef);
        }

        final updates = <String, dynamic>{
          'status': nextStatus.name,
          'updatedAt': Timestamp.fromDate(now),
        };
        if (nextStatus == QueueStatus.called) {
          updates['calledAt'] = Timestamp.fromDate(now);
          updates['graceEndsAt'] = Timestamp.fromDate(
              now.add(Duration(minutes: service.gracePeriodMin)));
          updates['holdEndsAt'] = FieldValue.delete();
          updates['graceWarningSent'] = FieldValue.delete();
        } else if (nextStatus == QueueStatus.onHold) {
          updates['holdEndsAt'] = Timestamp.fromDate(
              now.add(Duration(minutes: service.holdWindowMin)));
        } else if (nextStatus == QueueStatus.serving) {
          updates['startedAt'] = Timestamp.fromDate(now);
          if (staffId != null) updates['servedBy'] = staffId;
        } else if (nextStatus == QueueStatus.completed) {
          updates['completedAt'] = Timestamp.fromDate(now);
        }

        transaction.update(entryRef, updates);
        transaction.update(publicRef, {
          'status': nextStatus.name,
          'updatedAt': Timestamp.fromDate(now),
        });
        final message = _notificationFor(
            nextStatus, data['tokenCode'] as String? ?? 'your token');
        final notificationRef = _firestore.collection('notifications').doc();
        transaction.set(notificationRef, {
          'userId': data['studentId'],
          'entryId': entryId,
          'title': message.$1,
          'message': message.$2,
          'isRead': false,
          'createdAt': Timestamp.fromDate(now),
        });

        if ({QueueStatus.completed, QueueStatus.cancelled, QueueStatus.expired}
            .contains(nextStatus)) {
          if (claimSnapshot?.data()?['entryId'] == entryId &&
              claimRef != null) {
            transaction.delete(claimRef);
          }

          final historyRef = _firestore.collection('queueHistory').doc(entryId);
          transaction.set(historyRef, {
            'entryId': entryId,
            'studentId': data['studentId'],
            'serviceId': data['serviceId'],
            'departmentId': data['departmentId'],
            'tokenCode': data['tokenCode'],
            'outcome': nextStatus.name,
            'completedAt': Timestamp.fromDate(now),
          });
        }
      });
    } on QueueFailure {
      rethrow;
    } on FirebaseException {
      throw const QueueFailure('Queue update failed. Reconnect and try again.');
    }
  }

  bool _canTransition(QueueStatus from, QueueStatus to) => switch (from) {
        QueueStatus.waiting =>
          to == QueueStatus.approaching || to == QueueStatus.cancelled,
        QueueStatus.approaching =>
          to == QueueStatus.called || to == QueueStatus.cancelled,
        QueueStatus.called =>
          to == QueueStatus.serving || to == QueueStatus.onHold,
        QueueStatus.onHold => to == QueueStatus.called ||
            to == QueueStatus.expired ||
            to == QueueStatus.cancelled,
        QueueStatus.serving => to == QueueStatus.completed,
        QueueStatus.completed ||
        QueueStatus.cancelled ||
        QueueStatus.expired =>
          false,
      };

  (String, String) _notificationFor(QueueStatus status, String token) =>
      switch (status) {
        QueueStatus.approaching => (
            'You’re getting closer',
            '$token is approaching the counter.'
          ),
        QueueStatus.called => (
            'It’s your turn',
            'Show $token at the counter within the grace period.'
          ),
        QueueStatus.serving => (
            'Service started',
            '$token is now being served.'
          ),
        QueueStatus.onHold => (
            'Token on hold',
            '$token is on hold. Resume when you arrive.'
          ),
        QueueStatus.completed => (
            'Service complete',
            '$token has been completed.'
          ),
        QueueStatus.cancelled => (
            'Token cancelled',
            '$token has been cancelled.'
          ),
        QueueStatus.expired => (
            'Token expired',
            '$token has expired. Get a new token to rejoin.'
          ),
        QueueStatus.waiting => ('You’re in the queue', '$token is waiting.'),
      };

  String _newNonce() {
    final random = Random.secure();
    return List<int>.generate(24, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
