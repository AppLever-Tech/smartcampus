import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/data/mock_master_data.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/services/firebase_auth_service.dart';

class UserRoles {
  static const String systemAdmin = 'SYSTEM_ADMIN';
  static const String orgAdmin = 'ORG_ADMIN';
  static const String deptAdmin = 'DEPT_ADMIN';
  static const String faculty = 'FACULTY';
  static const String student = 'STUDENT';
  static const String unclassified = 'Unclassified';
}

class UserStatus {
  static const String pendingApproval = 'Pending Approval';
  static const String approved = 'Approved';
}

class UserMasterFirestoreService {
  static const String collection = 'smcUserMaster';

  final FirebaseFirestore _db;
  final FirebaseAuthService _authService;

  UserMasterFirestoreService({
    FirebaseFirestore? db,
    FirebaseAuthService? authService,
  })  : _db = db ?? FirebaseFirestore.instance,
        _authService = authService ?? FirebaseAuthService();

  String normalizeUuid(String input) =>
      _authService.normalizeUuidForCompare(input);

  Future<UserMasterItem?> getByUuid(String uuid) async {
    final normalized = normalizeUuid(uuid);
    if (normalized.isEmpty) {
      return null;
    }

    final doc = await _db.collection(collection).doc(normalized).get();
    if (doc.exists && doc.data() != null) {
      return UserMasterItem.fromMap(doc.data()!);
    }

    for (final candidate in _authService.uuidCandidates(uuid)) {
      final snap = await _db
          .collection(collection)
          .where('uuid', isEqualTo: candidate)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return UserMasterItem.fromMap(snap.docs.first.data());
      }
    }
    return null;
  }

  Future<void> upsertUser({
    required String uuid,
    required String userName,
    required String userRole,
    required String status,
    String orgId = '',
    String deptId = '',
  }) async {
    final normalized = normalizeUuid(uuid);
    if (normalized.isEmpty) {
      throw ArgumentError('A valid uuid/mobile is required.');
    }

    final user = UserMasterItem(
      uuid: normalized,
      userName: userName.trim(),
      userRole: userRole.trim(),
      status: status.trim(),
      orgId: orgId.trim().toUpperCase(),
      deptId: deptId.trim().toUpperCase(),
      mobile: normalized,
    );

    await _db.collection(collection).doc(normalized).set(
          {
            ...user.toCoreMap(),
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
  }

  Future<void> approveUser(String uuid) async {
    final normalized = normalizeUuid(uuid);
    await _db.collection(collection).doc(normalized).set(
      {
        'status': UserStatus.approved,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateUserRoleAndStatus({
    required String uuid,
    required String userRole,
    required String status,
  }) async {
    final normalized = normalizeUuid(uuid);
    await _db.collection(collection).doc(normalized).set(
      {
        'user_role': userRole.trim(),
        'status': status.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> classifyUser({
    required String uuid,
    required String userRole,
    required String orgId,
    required String deptId,
    String? userName,
  }) async {
    final normalized = normalizeUuid(uuid);
    final payload = <String, dynamic>{
      'user_role': userRole,
      'status': UserStatus.approved,
      'org_id': orgId.trim().toUpperCase(),
      'dept_id': deptId.trim().toUpperCase(),
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (userName != null && userName.trim().isNotEmpty) {
      payload['user_name'] = userName.trim();
    }
    await _db.collection(collection).doc(normalized).set(
          payload,
          SetOptions(merge: true),
        );
  }

  Future<List<UserMasterItem>> listForDepartment({
    required String orgId,
    required String deptId,
  }) async {
    final orgUpper = orgId.trim().toUpperCase();
    final deptUpper = deptId.trim().toUpperCase();

    final snap = await _db
        .collection(collection)
        .where('org_id', isEqualTo: orgUpper)
        .where('dept_id', isEqualTo: deptUpper)
        .get();

    if (snap.docs.isNotEmpty) {
      return snap.docs
          .map((doc) => UserMasterItem.fromMap(doc.data()))
          .where((user) => user.uuid.isNotEmpty)
          .toList();
    }

    final all = await _db.collection(collection).limit(800).get();
    return all.docs
        .map((doc) => UserMasterItem.fromMap(doc.data()))
        .where(
          (user) =>
              user.uuid.isNotEmpty &&
              user.orgId.toUpperCase() == orgUpper &&
              user.deptId.toUpperCase() == deptUpper,
        )
        .toList();
  }

  Future<void> syncFromStudent(StudentModel student) async {
    if (student.mobile.trim().isEmpty) {
      return;
    }
    await upsertUser(
      uuid: student.mobile,
      userName: student.fullName,
      userRole: UserRoles.student,
      status: UserStatus.approved,
      orgId: student.orgId,
      deptId: student.deptId,
    );
  }

  Future<void> syncFromFaculty(FacultyModel faculty) async {
    if (faculty.mobile.trim().isEmpty) {
      return;
    }
    await upsertUser(
      uuid: faculty.mobile,
      userName: faculty.fullName,
      userRole: UserRoles.faculty,
      status: UserStatus.approved,
      orgId: faculty.orgId,
      deptId: faculty.deptId,
    );
  }
}
