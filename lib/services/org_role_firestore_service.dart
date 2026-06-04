import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartcampus/data/mock_master_data.dart';
import 'package:smartcampus/services/firebase_auth_service.dart';
import 'package:smartcampus/services/user_master_firestore_service.dart';

class OrgRoleFirestoreService {
  OrgRoleFirestoreService({
    FirebaseAuthService? authService,
    UserMasterFirestoreService? userMasterService,
  })  : authService = authService ?? FirebaseAuthService(),
        _userMaster = userMasterService ??
            UserMasterFirestoreService(authService: authService);

  final FirebaseAuthService authService;
  final UserMasterFirestoreService _userMaster;

  static const String orgCollection = 'smcOrganizations';
  static const String deptCollection = 'smcDepartments';

  Future<List<OrgUserRoleMappingItem>> getAllRoleMappingsForUuid(
    String uuid,
  ) async {
    final user = await _userMaster.getByUuid(uuid);
    if (user == null || user.normalizedUserRole.isEmpty) {
      return <OrgUserRoleMappingItem>[];
    }
    return <OrgUserRoleMappingItem>[OrgUserRoleMappingItem.fromUserMaster(user)];
  }

  OrgUserRoleMappingItem pickPrimaryRole(List<OrgUserRoleMappingItem> list) {
    if (list.isEmpty) {
      throw StateError('pickPrimaryRole: empty list');
    }
    const order = <String>[
      'SYSTEM_ADMIN',
      'ORG_ADMIN',
      'DEPT_ADMIN',
      'FACULTY',
      'STUDENT',
    ];
    for (final role in order) {
      for (final m in list) {
        if (m.normalizedRoleId == role) {
          return m;
        }
      }
    }
    return list.first;
  }

  Future<List<OrgUserRoleMappingItem>> listPendingOrgAdmins() async {
    final users = await _userMaster.listPendingOrgAdmins();
    return users.map(OrgUserRoleMappingItem.fromUserMaster).toList();
  }

  Future<List<OrgUserRoleMappingItem>> listPendingDeptAdminsForOrg(
    String orgId,
  ) async {
    final users = await _userMaster.listPendingDeptAdminsForOrg(orgId);
    return users.map(OrgUserRoleMappingItem.fromUserMaster).toList();
  }

  Future<List<OrgUserRoleMappingItem>> listFacultyAndStudentsForOrg(
    String orgId,
  ) async {
    final users = await _userMaster.listFacultyAndStudentsForOrg(orgId);
    return users.map(OrgUserRoleMappingItem.fromUserMaster).toList();
  }

  Future<List<OrganizationItem>> loadAllOrganizations() async {
    final map = <String, OrganizationItem>{};
    for (final col in [orgCollection]) {
      try {
        final snap = await FirebaseFirestore.instance.collection(col).get();
        for (final doc in snap.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data.putIfAbsent('org_unique_id', () => doc.id);
          final item = OrganizationItem.fromMap(data, documentId: doc.id);
          if (item.orgId.isNotEmpty) {
            map[item.orgId.toUpperCase()] = item;
          }
        }
      } catch (_) {
        continue;
      }
    }
    return map.values.toList();
  }

  Future<List<DepartmentMasterItem>> loadDepartmentsForOrg(String orgId) async {
    final norm = orgId.trim().toUpperCase();
    for (final col in [deptCollection]) {
      try {
        final byField = await FirebaseFirestore.instance
            .collection(col)
            .where('org_id', isEqualTo: norm)
            .limit(200)
            .get();
        if (byField.docs.isNotEmpty) {
          return byField.docs
              .map((d) => DepartmentMasterItem.fromMap(d.data(), documentId: d.id))
              .toList();
        }
      } catch (_) {
        // ignore query errors (missing index etc.)
      }
      try {
        final all = await FirebaseFirestore.instance.collection(col).limit(400).get();
        final rows = all.docs
            .map((d) => DepartmentMasterItem.fromMap(d.data(), documentId: d.id))
            .where((d) => d.orgId.toUpperCase() == norm)
            .toList();
        if (rows.isNotEmpty) {
          return rows;
        }
      } catch (_) {
        continue;
      }
    }
    return <DepartmentMasterItem>[];
  }

  /// Normalizes user input to a 4-digit access code string (e.g. "0123").
  static String normalizeDeptAccessCode(String code) {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return '';
    }
    return digits.padLeft(4, '0').substring(0, 4);
  }

  Future<DepartmentMasterItem?> findDepartmentByAccessCode(String code) async {
    final accessCode = normalizeDeptAccessCode(code);
    if (accessCode.length != 4) {
      return null;
    }

    for (final col in [deptCollection]) {
      try {
        final byAccessCode = await FirebaseFirestore.instance
            .collection(col)
            .where('dept_access_code', isEqualTo: accessCode)
            .limit(1)
            .get();
        if (byAccessCode.docs.isNotEmpty) {
          return DepartmentMasterItem.fromMap(
            byAccessCode.docs.first.data(),
            documentId: byAccessCode.docs.first.id,
          );
        }

        final all = await FirebaseFirestore.instance.collection(col).limit(500).get();
        for (final doc in all.docs) {
          final dept = DepartmentMasterItem.fromMap(doc.data(), documentId: doc.id);
          final stored = normalizeDeptAccessCode(dept.deptAccessCode);
          if (stored == accessCode) {
            return dept;
          }
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<bool> isDeptAccessCodeTakenInOrg({
    required String orgId,
    required String accessCode,
    String? excludeDeptId,
  }) async {
    final normalized = normalizeDeptAccessCode(accessCode);
    if (normalized.length != 4) {
      return false;
    }
    final exclude = excludeDeptId?.trim().toUpperCase() ?? '';
    final departments = await loadDepartmentsForOrg(orgId);
    for (final dept in departments) {
      if (exclude.isNotEmpty && dept.deptId.toUpperCase() == exclude) {
        continue;
      }
      if (normalizeDeptAccessCode(dept.deptAccessCode) == normalized) {
        return true;
      }
    }
    return false;
  }

  Future<void> createOrUpdateDepartment({
    required String orgId,
    required String deptId,
    required String deptName,
    required String deptAccessCode,
    String establishedYear = '',
    String deptType = '',
    List<String> programsOffered = const [],
    String affiliation = '',
    String accreditationStatus = '',
    String createdBy = '',
  }) async {
    final String orgUpper = orgId.trim().toUpperCase();
    final String deptUpper = deptId.trim().toUpperCase();
    final String accessCode = normalizeDeptAccessCode(deptAccessCode);

    if (orgUpper.isEmpty || deptUpper.isEmpty) {
      throw StateError('Organization ID and Department ID are required.');
    }
    if (accessCode.length != 4) {
      throw StateError('A valid 4-digit department access code is required.');
    }

    if (await isDeptAccessCodeTakenInOrg(
      orgId: orgUpper,
      accessCode: accessCode,
      excludeDeptId: deptUpper,
    )) {
      throw StateError(
        'This access code is already used by another department in this organisation.',
      );
    }

    final col = FirebaseFirestore.instance.collection(deptCollection);

    final existing = await col
        .where('org_id', isEqualTo: orgUpper)
        .where('dept_id', isEqualTo: deptUpper)
        .limit(1)
        .get();

    final ref = existing.docs.isNotEmpty
        ? existing.docs.first.reference
        : col.doc();

    final payload = {
      'org_id': orgUpper,
      'dept_id': deptUpper,
      'dept_unique_id': ref.id,
      'dept_access_code': accessCode,
      'dept_name': deptName.trim(),
      'established_year': establishedYear.trim(),
      'dept_type': deptType.trim(),
      'programs_offered': programsOffered,
      'affiliation': affiliation.trim(),
      'accreditation_status': accreditationStatus.trim(),
      'created_by': createdBy,
      'updated_at': FieldValue.serverTimestamp(),
    };

    if (existing.docs.isEmpty) {
      payload['created_at'] = FieldValue.serverTimestamp();
    }

    await ref.set(payload, SetOptions(merge: true));
  }

  Future<int> countAssignedDepartmentsForOrg(String orgId) {
    return _userMaster.countAssignedDepartmentsForOrg(orgId);
  }

  Future<UserMasterItem?> getUserMaster(String uuid) {
    return _userMaster.getByUuid(uuid);
  }

  Future<List<UserMasterItem>> listRegisteredUsersForOrgAssignment(
    String orgId,
  ) {
    return _userMaster.listRegisteredUsersForOrgAssignment(orgId);
  }

  Future<List<UserMasterItem>> listAllUsers() {
    return _userMaster.listAll();
  }

  Future<void> assignOrgAdminToOrganization({
    required OrgUserRoleMappingItem mapping,
    required OrganizationItem organization,
  }) {
    return _userMaster.assignOrgAdminToOrganization(
      uuid: mapping.uuid,
      organization: organization,
      userName: mapping.name,
    );
  }

  Future<void> assignDeptAdminToDepartment({
    required OrgUserRoleMappingItem mapping,
    required DepartmentMasterItem department,
  }) {
    final orgId = mapping.orgId.isNotEmpty
        ? mapping.orgId
        : department.orgId;
    return _userMaster.assignDeptAdminToDepartment(
      uuid: mapping.uuid,
      department: department,
      orgId: orgId,
      userName: mapping.name,
    );
  }

  Future<void> assignFacultyOrStudentDepartment({
    required OrgUserRoleMappingItem mapping,
    required DepartmentMasterItem department,
  }) {
    final orgId = mapping.orgId.isNotEmpty
        ? mapping.orgId
        : department.orgId;
    return _userMaster.assignFacultyOrStudentDepartment(
      uuid: mapping.uuid,
      department: department,
      orgId: orgId,
    );
  }

  Future<void> createOrUpdateOrganization({
    required String orgIdSix,
    required String orgName,
    required String orgType,
    required String orgAddress,
    required String orgWebsite,
  }) async {
    final trimmedId = orgIdSix.trim().toUpperCase();
    final collectionRef = FirebaseFirestore.instance.collection(orgCollection);
    final existing = await collectionRef
        .where('org_id', isEqualTo: trimmedId)
        .limit(1)
        .get();
    final DocumentReference<Map<String, dynamic>> docRef = existing.docs.isNotEmpty
        ? existing.docs.first.reference
        : collectionRef.doc();
    final payload = {
      'org_id': trimmedId,
      'org_unique_id': docRef.id,
      'org_name': orgName.trim(),
      'org_type': orgType.trim(),
      'org_address': orgAddress.trim(),
      'org_website': orgWebsite.trim(),
      'updated_at': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    };
    await docRef.set(payload, SetOptions(merge: true));
  }
}
