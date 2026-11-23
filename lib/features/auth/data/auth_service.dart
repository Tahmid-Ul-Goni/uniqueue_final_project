import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/app_user.dart';
import '../../../services/notification_service.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _notificationService = notificationService;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final NotificationService? _notificationService;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AppUser> profileFor(String uid) async {
    try {
      final reference = _firestore.collection('users').doc(uid);
      var snapshot = await reference.get();

      if (!snapshot.exists || snapshot.data() == null) {
        final authUser = _auth.currentUser;
        if (authUser == null || authUser.uid != uid) {
          throw const AuthFailure(
            'Your account is signed in, but its UniQueue profile could not be created. Sign out and sign in again.',
          );
        }

        final email = authUser.email?.trim() ?? '';
        if (email.isEmpty) {
          throw const AuthFailure(
            'Your account needs an email address before a UniQueue profile can be created.',
          );
        }
        final displayName = authUser.displayName?.trim();
        final emailName = email.split('@').first.trim();
        final name = displayName != null && displayName.length >= 2
            ? displayName
            : emailName.length >= 2
                ? emailName
                : 'UniQueue student';

        // A profile-less account may safely be provisioned as a student. Admin
        // privileges must come from an administrator-created Firestore profile.
        await _firestore.runTransaction((transaction) async {
          final current = await transaction.get(reference);
          if (!current.exists) {
            transaction.set(reference, {
              'name': name,
              'email': email,
              'role': 'student',
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        });
        snapshot = await reference.get();
      }

      final data = snapshot.data();
      if (data == null) {
        throw const AuthFailure(
          'Your UniQueue profile is empty. Ask an administrator to repair it.',
        );
      }
      return AppUser.fromMap(snapshot.id, data);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const AuthFailure(
          'Firestore denied access to your profile. Check the deployed user-profile rules, then retry.',
        );
      }
      throw const AuthFailure(
        'Could not load your profile. Check your connection and retry.',
      );
    } on FormatException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_friendlyAuthMessage(error.code));
    } on FirebaseException {
      throw const AuthFailure(
          'Sign-in is unavailable. Check your connection and try again.');
    }
  }

  Future<void> registerStudent({
    required String name,
    required String email,
    required String password,
  }) async {
    User? createdUser;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      createdUser = credential.user;
      if (createdUser == null) {
        throw const AuthFailure(
            'Account creation did not finish. Please try again.');
      }
      await _firestore.collection('users').doc(createdUser.uid).set({
        'name': name.trim(),
        'email': createdUser.email ?? email.trim(),
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_friendlyAuthMessage(error.code));
    } on FirebaseException {
      if (createdUser != null) {
        try {
          await createdUser.delete();
          await _auth.signOut();
        } catch (_) {
          // Surface the profile failure; a newly created account may need manual cleanup.
        }
      }
      throw const AuthFailure(
          'Could not finish setting up your profile. Check your connection and try again.');
    } on AuthFailure {
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_friendlyAuthMessage(error.code));
    } on FirebaseException {
      throw const AuthFailure(
          'Could not send the reset email. Check your connection and try again.');
    }
  }

  Future<void> signOut() async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      await _notificationService?.clearCurrentUser(userId);
    }
    await _auth.signOut();
  }

  String _friendlyAuthMessage(String code) => switch (code) {
        'email-already-in-use' =>
          'An account already exists for this email. Log in or reset its password.',
        'weak-password' => 'Choose a password with at least 8 characters.',
        'requires-recent-login' =>
          'Please sign in again and retry this action.',
        'invalid-email' => 'Enter a valid university email address.',
        'user-disabled' =>
          'This account is disabled. Contact an administrator.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Email or password is incorrect. Check your details and try again.',
        'too-many-requests' =>
          'Too many attempts. Wait a little, then try again.',
        'network-request-failed' =>
          'No connection. Check your internet and try again.',
        'operation-not-allowed' =>
          'Email sign-in is not enabled for this Firebase project.',
        _ => 'Unable to sign in right now. Please try again.',
      };
}
