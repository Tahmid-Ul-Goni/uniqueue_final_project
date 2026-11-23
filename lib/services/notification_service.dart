import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService(
      {FirebaseMessaging? messaging, FirebaseFirestore? firestore})
      : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _userNotificationSubscription;
  String? _listeningUserId;
  StreamSubscription<String>? _registrationSubscription;
  String? _registeredUserId;

  Future<void> initializeForegroundDisplay() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(settings: settings);
    _messageSubscription ??=
        FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null) return;
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'uniqueue_queue_updates',
          'Queue updates',
          channelDescription: 'Live updates about your UniQueue token.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );
      await _localNotifications.show(
        id: message.messageId.hashCode,
        title: notification.title ?? 'UniQueue update',
        body: notification.body ?? 'Your queue status changed.',
        notificationDetails: details,
        payload: message.data['entryId'] as String?,
      );
    });
  }

  /// Listens for new Firestore queue notifications and surfaces them locally.
  Future<void> attachToUser(String userId) async {
    if (_listeningUserId == userId && _userNotificationSubscription != null) {
      return;
    }
    await _userNotificationSubscription?.cancel();
    _listeningUserId = userId;
    var isInitialSnapshot = true;
    final seenIds = <String>{};
    _userNotificationSubscription = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .listen((snapshot) async {
      if (_listeningUserId != userId) return;
      if (isInitialSnapshot) {
        seenIds.addAll(snapshot.docs.map((document) => document.id));
        isInitialSnapshot = false;
        return;
      }
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added ||
            !seenIds.add(change.doc.id)) {
          continue;
        }
        final data = change.doc.data();
        if (data == null) continue;
        await _showLocalNotification(
          id: change.doc.id.hashCode,
          title: data['title'] as String? ?? 'UniQueue update',
          body: data['message'] as String? ?? 'Your queue status changed.',
          payload: data['entryId'] as String?,
        );
      }
    }, onError: (Object _) {});
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'uniqueue_queue_updates',
        'Queue updates',
        channelDescription: 'Live updates about your UniQueue token.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (_) {
      // Firestore in-app alerts remain available if OS notifications are disabled.
    }
  }

  Future<void> dispose() async {
    await _messageSubscription?.cancel();
    await _userNotificationSubscription?.cancel();
    await _registrationSubscription?.cancel();
    _userNotificationSubscription = null;
    _listeningUserId = null;
  }

  Future<void> clearCurrentUser(String userId) async {
    if (_listeningUserId == userId) {
      _listeningUserId = null;
      await _userNotificationSubscription?.cancel();
      _userNotificationSubscription = null;
    }
    if (_registeredUserId != userId) return;
    _registeredUserId = null;
    await _registrationSubscription?.cancel();
    _registrationSubscription = null;
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmInstallationId': FieldValue.delete(),
        'fcmUpdatedAt': FieldValue.delete(),
      });
      await _messaging.unregister();
    } on FirebaseException {
      // Signing out must remain possible if the device is offline.
    }
  }

  Future<bool> requestPermissionAndRegister(String userId) async {
    try {
      _registeredUserId = userId;
      _registrationSubscription ??=
          _messaging.onRegistered.listen((installationId) {
        final currentUserId = _registeredUserId;
        if (currentUserId != null) {
          unawaited(_saveInstallationId(currentUserId, installationId)
              .catchError((_) {}));
        }
      });
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return false;
      }

      final installationIdFuture =
          _messaging.onRegistered.first.timeout(const Duration(seconds: 20));
      await _messaging.register();
      final installationId = await installationIdFuture;
      if (installationId.isEmpty) return false;
      await _saveInstallationId(userId, installationId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveInstallationId(String userId, String installationId) async {
    await _firestore.collection('users').doc(userId).update({
      'fcmInstallationId': installationId,
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    });
  }
}
