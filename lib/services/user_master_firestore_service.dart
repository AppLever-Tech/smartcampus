import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/data/mock_master_data.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/data/user_org_scope.dart';
import 'package:smartcampus/data/org_field.dart';
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

  /// Returns org/dept scope from smcUserMaster for artifact queries.
  Future<UserOrgScope?> resolveOrgScope(String uuid) async {
    final user = await getByUuid(uuid);
    if (user == null || user.orgId.trim().isEmpty) {
      return null;
    }
    return UserOrgScope.fromUser(user);
  }

  /// Resolves scope for the signed-in user using Firebase uid and phone variants.
  Future<UserOrgScope?> resolveOrgScopeForSignedInUser() async {
    final user = await getSignedInUserMaster();
    if (user == null || user.orgId.trim().isEmpty) {
      return null;
    }
    return UserOrgScope.fromUser(user);
  }

  /// Loads smcUserMaster for the signed-in Firebase user (uid or phone).
  Future<UserMasterItem?> getSignedInUserMaster() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      return null;
    }

    final candidates = <String>{
      authUser.uid,
      if (authUser.phoneNumber != null) authUser.phoneNumber!,
      ..._authService.uuidCandidates(authUser.uid),
      if (authUser.phoneNumber != null)
        ..._authService.uuidCandidates(authUser.phoneNumber!),
    };

    for (final candidate in candidates) {
      final user = await getByUuid(candidate);
      if (user != null) {
        return user;
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
      orgId: OrgField.normalize(orgId),
      deptId: OrgField.normalize(deptId),
      mobile: normalized,
    );

    await _db.collection(collection).doc(normalized).set(
          {
            ...user.toCoreMap(),
            OrgField.legacyOrgIdKey: FieldValue.delete(),
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
    final orgNorm = OrgField.normalize(orgId);
    final deptNorm = OrgField.normalize(deptId);
    final payload = <String, dynamic>{
      'user_role': userRole,
      'status': UserStatus.approved,
      ...OrgField.orgIdWrite(orgNorm),
      if (deptNorm.isNotEmpty) OrgField.deptIdKey: deptNorm,
      OrgField.legacyOrgIdKey: FieldValue.delete(),
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

  Future<List<UserMasterItem>> listAll() async {
    final snap = await _db.collection(collection).limit(800).get();
    return snap.docs
        .map((doc) => UserMasterItem.fromMap(doc.data()))
        .where((user) => user.uuid.isNotEmpty)
        .toList();
  }

  Future<List<UserMasterItem>> listPendingOrgAdmins() async {
    final all = await listAll();
    return all
        .where(
          (u) =>
              u.normalizedUserRole == UserRoles.orgAdmin.toUpperCase() &&
              u.isPendingApproval,
        )
        .toList();
  }

  Future<List<UserMasterItem>> listPendingDeptAdminsForOrg(String orgId) async {
    final norm = orgId.trim().toUpperCase();
    final all = await listAll();
    return all.where((u) {
      if (u.normalizedUserRole != UserRoles.deptAdmin.toUpperCase() ||
          !u.isPendingApproval) {
        return false;
      }
      final org = u.orgId.isNotEmpty ? u.orgId : u.requestedOrgId;
      return org.trim().toUpperCase() == norm;
    }).toList();
  }

  Future<List<UserMasterItem>> listFacultyAndStudentsForOrg(String orgId) async {
    final norm = orgId.trim().toUpperCase();
    final all = await listAll();
    return all.where((u) {
      final role = u.normalizedUserRole;
      final roleOk = role == UserRoles.faculty.toUpperCase() ||
          role == UserRoles.student.toUpperCase();
      return roleOk && u.orgId.trim().toUpperCase() == norm;
    }).toList();
  }

  Future<int> countAssignedDepartmentsForOrg(String orgId) async {
    final norm = orgId.trim().toUpperCase();
    final all = await listAll();
    final ids = <String>{};
    for (final user in all) {
      if (user.normalizedUserRole != UserRoles.deptAdmin.toUpperCase() ||
          !user.isApproved ||
          user.orgId.trim().toUpperCase() != norm) {
        continue;
      }
      final dept = user.deptId.trim().toUpperCase();
      if (dept.isNotEmpty) {
        ids.add(dept);
      }
    }
    return ids.length;
  }

  Future<List<UserMasterItem>> listRegisteredUsersForOrgAssignment(
    String orgId,
  ) async {
    final normOrg = orgId.trim().toUpperCase();
    final all = await listAll();
    return all
        .where(
          (u) =>
              u.uuid.isNotEmpty &&
              u.isPendingApproval &&
              u.normalizedUserRole.isEmpty &&
              u.requestedOrgId.trim().toUpperCase() == normOrg,
        )
        .toList();
  }

  Future<void> assignOrgAdminToOrganization({
    required String uuid,
    required OrganizationItem organization,
    String? userName,
  }) async {
    final normalized = normalizeUuid(uuid);
    final existing = await getByUuid(normalized);
    final name = (userName ?? existing?.displayName ?? '').trim();
    await _db.collection(collection).doc(normalized).set(
      {
        'uuid': normalized,
        if (name.isNotEmpty) 'user_name': name,
        'user_role': UserRoles.orgAdmin,
        'status': UserStatus.approved,
        ...OrgField.orgIdWrite(organization.orgId),
        'requested_org_id': OrgField.normalize(organization.orgId),
        'requested_org_name': organization.orgName.trim(),
        OrgField.legacyOrgIdKey: FieldValue.delete(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> assignDeptAdminToDepartment({
    required String uuid,
    required DepartmentMasterItem department,
    required String orgId,
    String? userName,
  }) async {
    final normalized = normalizeUuid(uuid);
    final existing = await getByUuid(normalized);
    final name = (userName ?? existing?.displayName ?? '').trim();
    await _db.collection(collection).doc(normalized).set(
      {
        'uuid': normalized,
        if (name.isNotEmpty) 'user_name': name,
        'user_role': UserRoles.deptAdmin,
        'status': UserStatus.approved,
        ...OrgField.orgIdWrite(orgId),
        OrgField.deptIdKey: OrgField.normalize(department.deptId),
        OrgField.legacyOrgIdKey: FieldValue.delete(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> assignFacultyOrStudentDepartment({
    required String uuid,
    required DepartmentMasterItem department,
    required String orgId,
  }) async {
    final normalized = normalizeUuid(uuid);
    final existing = await getByUuid(normalized);
    if (existing == null) {
      throw StateError('User not found in smcUserMaster');
    }
    await _db.collection(collection).doc(normalized).set(
      {
        OrgField.deptIdKey: OrgField.normalize(department.deptId),
        ...OrgField.orgIdWrite(orgId),
        OrgField.legacyOrgIdKey: FieldValue.delete(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
