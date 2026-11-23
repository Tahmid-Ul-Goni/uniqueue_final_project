import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/department.dart';
import '../models/queue_service.dart';

class CatalogService {
  CatalogService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Adds a small, clearly named demo catalog for an empty project.
  Future<void> createDemoCatalog() async {
    final departmentRef =
        _firestore.collection('departments').doc('finance-office');
    final serviceRef = _firestore.collection('services').doc('finance-enquiry');
    await _firestore.runTransaction((transaction) async {
      final department = await transaction.get(departmentRef);
      final service = await transaction.get(serviceRef);
      if (!department.exists) {
        transaction.set(departmentRef, {
          'name': 'Finance Office (Demo)',
          'iconKey': 'account_balance',
          'active': true,
        });
      }
      if (!service.exists) {
        transaction.set(serviceRef, {
          'departmentId': departmentRef.id,
          'name': 'Fee Enquiry (Demo)',
          'prefix': 'F',
          'averageServiceTime': 5,
          'gracePeriodMin': 5,
          'holdWindowMin': 10,
          'counterStatus': 'open',
          'lastTokenNumber': 0,
        });
      }
    });
  }

  /// Adds the demo data once, from an admin session, when the catalog is empty.
  Future<void> ensureSampleCatalogIfEmpty() async {
    final existing = await _firestore.collection('departments').limit(1).get();
    if (existing.docs.isEmpty) await createDemoCatalog();
  }

  /// Ensures active departments each have at least one service. Called only by
  /// the admin dashboard so student clients never receive catalog write access.
  Future<void> ensureServicesForEmptyDepartments() async {
    final departments = await _firestore.collection('departments').get();
    for (final document in departments.docs) {
      final department = Department.fromMap(document.id, document.data());
      if (!department.active) continue;
      await ensureStarterServiceForDepartment(department);
    }
  }

  Future<void> ensureStarterServiceForDepartment(Department department) async {
    final services = _firestore.collection('services');
    final existing = await services
        .where('departmentId', isEqualTo: department.id)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    final words = department.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    var prefix = words.take(3).map((word) => word[0]).join().toUpperCase();
    if (prefix.isEmpty) prefix = 'Q';
    if (prefix.length > 3) prefix = prefix.substring(0, 3);

    final serviceRef = services.doc('${department.id}-general-enquiry');
    await _firestore.runTransaction((transaction) async {
      final current = await transaction.get(serviceRef);
      if (current.exists) return;
      transaction.set(serviceRef, {
        'departmentId': department.id,
        'name': 'General Enquiry',
        'prefix': prefix,
        'averageServiceTime': 5,
        'gracePeriodMin': 5,
        'holdWindowMin': 10,
        'counterStatus': 'open',
        'lastTokenNumber': 0,
      });
    });
  }

  Future<void> createDepartment({
    required String id,
    required String name,
    required String iconKey,
  }) async {
    final reference = _firestore.collection('departments').doc(id);
    await _firestore.runTransaction((transaction) async {
      if ((await transaction.get(reference)).exists) {
        throw StateError('A department with this ID already exists.');
      }
      transaction.set(reference, {
        'name': name,
        'iconKey': iconKey,
        'active': true,
      });
    });
    await ensureStarterServiceForDepartment(
      Department(id: id, name: name, active: true, iconKey: iconKey),
    );
  }

  Future<void> createService({
    required String id,
    required String departmentId,
    required String name,
    required String prefix,
    required int averageServiceTime,
    required int gracePeriodMin,
    required int holdWindowMin,
  }) async {
    final reference = _firestore.collection('services').doc(id);
    await _firestore.runTransaction((transaction) async {
      if ((await transaction.get(reference)).exists) {
        throw StateError('A service with this ID already exists.');
      }
      transaction.set(reference, {
        'departmentId': departmentId,
        'name': name,
        'prefix': prefix,
        'averageServiceTime': averageServiceTime,
        'gracePeriodMin': gracePeriodMin,
        'holdWindowMin': holdWindowMin,
        'counterStatus': 'open',
        'lastTokenNumber': 0,
      });
    });
  }

  Future<void> createUserProfile({
    required String userId,
    required String name,
    required String email,
    required String role,
    String? departmentId,
  }) async {
    final reference = _firestore.collection('users').doc(userId);
    await _firestore.runTransaction((transaction) async {
      if ((await transaction.get(reference)).exists) {
        throw StateError('A UniQueue profile already exists for this UID.');
      }
      transaction.set(reference, {
        'name': name,
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        if (role == 'receptionist' && departmentId != null)
          'departmentId': departmentId,
      });
    });
  }

  Stream<List<Department>> watchDepartments() =>
      _firestore.collection('departments').snapshots().map((snapshot) {
        final departments = snapshot.docs
            .map((doc) => Department.fromMap(doc.id, doc.data()))
            .where((department) => department.active)
            .toList();
        departments.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return List<Department>.unmodifiable(departments);
      });
  Stream<Department?> watchDepartment(String departmentId) => _firestore
      .collection('departments')
      .doc(departmentId)
      .snapshots()
      .map((snapshot) => snapshot.exists && snapshot.data() != null
          ? Department.fromMap(snapshot.id, snapshot.data()!)
          : null);

  Stream<List<QueueService>> watchDepartmentServices(String departmentId) =>
      _firestore
          .collection('services')
          .where('departmentId', isEqualTo: departmentId)
          .snapshots()
          .map((snapshot) {
        final services = snapshot.docs
            .map((doc) => QueueService.fromMap(doc.id, doc.data()))
            .toList();
        services.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return List<QueueService>.unmodifiable(services);
      });
}
