import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartcampus/data/mock_master_data.dart';
import 'package:smartcampus/services/firebase_auth_service.dart';

class OrgRoleFirestoreService {
  OrgRoleFirestoreService({FirebaseAuthService? authService})
      : authService = authService ?? FirebaseAuthService();

  final FirebaseAuthService authService;

  static const String mappingCollection = 'smcOrgUserRoleMapping';
  static const String userMasterCollection = 'smcUserMaster';
  static const String orgCollection = 'smcOrganizations';
  static const String deptCollection = 'smcDepartments';

  Future<List<OrgUserRoleMappingItem>> getAllRoleMappingsForUuid(
    String uuid,
  ) async {
    final seen = <String>{};
    final out = <OrgUserRoleMappingItem>[];
    for (final candidate in authService.uuidCandidates(uuid)) {
      final snap = await FirebaseFirestore.instance
          .collection(mappingCollection)
          .where('uuid', isEqualTo: candidate)
          .get();
      for (final doc in snap.docs) {
        if (seen.add(doc.id)) {
          out.add(
            OrgUserRoleMappingItem.fromMap(doc.data(), documentId: doc.id),
          );
        }
      }
    }
    if (out.isNotEmpty) {
      return out;
    }
    final all = await FirebaseFirestore.instance
        .collection(mappingCollection)
        .limit(500)
        .get();
    final targets = authService
        .uuidCandidates(uuid)
        .map(authService.normalizeUuidForCompare)
        .toSet();
    for (final doc in all.docs) {
      final data = doc.data();
      final dbUuid = authService.normalizeUuidForCompare(data['uuid']);
      if (dbUuid.isEmpty) {
        continue;
      }
      if (targets.contains(dbUuid) && seen.add(doc.id)) {
        out.add(OrgUserRoleMappingItem.fromMap(data, documentId: doc.id));
      }
    }
    return out;
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
    final snap =
        await FirebaseFirestore.instance.collection(mappingCollection).get();
    return snap.docs
        .map(
          (d) => OrgUserRoleMappingItem.fromMap(d.data(), documentId: d.id),
        )
        .where(
          (m) => m.normalizedRoleId == 'ORG_ADMIN' && m.isRegisteredPending,
        )
        .toList();
  }

  Future<List<OrgUserRoleMappingItem>> listPendingDeptAdminsForOrg(
    String orgId,
  ) async {
    final norm = orgId.trim().toUpperCase();
    final snap =
        await FirebaseFirestore.instance.collection(mappingCollection).get();
    return snap.docs
        .map(
          (d) => OrgUserRoleMappingItem.fromMap(d.data(), documentId: d.id),
        )
        .where(
          (m) =>
              m.normalizedRoleId == 'DEPT_ADMIN' &&
              m.isRegisteredPending &&
              m.orgId.trim().toUpperCase() == norm,
        )
        .toList();
  }

  Future<List<OrgUserRoleMappingItem>> listFacultyAndStudentsForOrg(
    String orgId,
  ) async {
    final norm = orgId.trim().toUpperCase();
    final snap =
        await FirebaseFirestore.instance.collection(mappingCollection).get();
    return snap.docs
        .map(
          (d) => OrgUserRoleMappingItem.fromMap(d.data(), documentId: d.id),
        )
        .where((m) {
          final r = m.normalizedRoleId;
          final roleOk = r == 'FACULTY' || r == 'STUDENT';
          return roleOk && m.orgId.trim().toUpperCase() == norm;
        })
        .toList();
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

  Future<void> createOrUpdateDepartment({
    required String orgId,
    required String deptId,
    required String deptName,
    String establishedYear = '',
    String deptType = '',
    List<String> programsOffered = const [],
    String affiliation = '',
    String accreditationStatus = '',
    String createdBy = '',
  }) async {
    final String orgUpper = orgId.trim().toUpperCase();
    final String deptUpper = deptId.trim().toUpperCase();

    if (orgUpper.isEmpty || deptUpper.isEmpty) {
      throw StateError('Organization ID and Department ID are required.');
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
      'dept_name': deptName.trim(),
      'established_year': establishedYear.trim(),
      'dept_type': deptType.trim(),
      'programs_offered': programsOffered,
      'affiliation': affiliation.trim(),
      'accreditation_status': accreditationStatus.trim(),
      'created_by': createdBy,
      'updated_at': FieldValue.serverTimestamp(),
    };

    // ✅ Only set created_at during CREATE
    if (existing.docs.isEmpty) {
      payload['created_at'] = FieldValue.serverTimestamp();
    }

    await ref.set(payload, SetOptions(merge: true));
  }

  Future<int> countAssignedDepartmentsForOrg(String orgId) async {
    final norm = orgId.trim().toUpperCase();
    final snap = await FirebaseFirestore.instance.collection(mappingCollection).get();
    final ids = <String>{};
    for (final doc in snap.docs) {
      final m = OrgUserRoleMappingItem.fromMap(doc.data(), documentId: doc.id);
      if (m.normalizedRoleId == 'DEPT_ADMIN' &&
          m.orgId.trim().toUpperCase() == norm &&
          m.deptId.trim().isNotEmpty) {
        ids.add(m.deptId.trim().toUpperCase());
      }
    }
    return ids.length;
  }

  Future<UserMasterItem?> getUserMaster(String uuid) {
    return authService.getUserByUuid(uuid);
  }

  Future<List<UserMasterItem>> listRegisteredUsersForOrgAssignment(
    String orgId,
  ) async {
    final normOrg = orgId.trim().toUpperCase();
    try {
      final query = await FirebaseFirestore.instance
          .collection(userMasterCollection)
          .where('status', isEqualTo: 'Registered')
          .where('requested_org_id', isEqualTo: normOrg)
          .limit(300)
          .get();
      return query.docs
          .map((doc) => UserMasterItem.fromMap(doc.data()))
          .where((u) => u.uuid.isNotEmpty && u.roleId.trim().isEmpty)
          .toList();
    } catch (_) {
      final all = await FirebaseFirestore.instance
          .collection(userMasterCollection)
          .limit(500)
          .get();
      return all.docs
          .map((doc) => UserMasterItem.fromMap(doc.data()))
          .where(
            (u) =>
                u.uuid.isNotEmpty &&
                u.roleId.trim().isEmpty &&
                u.status.trim().toLowerCase() == 'registered' &&
                u.requestedOrgId.trim().toUpperCase() == normOrg,
          )
          .toList();
    }
  }

  Future<List<UserMasterItem>> listAllUsers() async {
    final snap = await FirebaseFirestore.instance
        .collection(userMasterCollection)
        .limit(800)
        .get();
    return snap.docs
        .map((doc) => UserMasterItem.fromMap(doc.data()))
        .where((u) => u.uuid.isNotEmpty)
        .toList();
  }

  String mappingDocumentId(OrgUserRoleMappingItem m, String suffixOrgOrRole) {
    if (m.documentId.isNotEmpty) {
      return m.documentId;
    }
    return '${m.uuid}_${suffixOrgOrRole}_${m.normalizedRoleId}';
  }

  Future<void> assignOrgAdminToOrganization({
    required OrgUserRoleMappingItem mapping,
    required OrganizationItem organization,
  }) async {
    final user = await getUserMaster(mapping.uuid);
    if (user == null) {
      throw StateError('User not found in smcUserMaster');
    }
    final batch = FirebaseFirestore.instance.batch();
    final orgIdUpper = organization.orgId.trim().toUpperCase();
    String? docId = mapping.documentId.trim().isNotEmpty
        ? mapping.documentId.trim()
        : null;
    if (docId == null) {
      docId = await findExistingMappingDocumentId(
        uuid: mapping.uuid,
        orgIdUpper: orgIdUpper,
      );
    }
    if (docId == null || docId.isEmpty) {
      throw StateError(
        'Existing mapping document not found for this user. Cannot assign org admin.',
      );
    }
    final mapRef =
        FirebaseFirestore.instance.collection(mappingCollection).doc(docId);
    final merged = mapping
        .copyWith(
          orgId: orgIdUpper,
          orgUniqueId: organization.orgUniqueId,
          status: 'Approved',
          roleId: 'ORG_ADMIN',
        )
        .toMap();
    batch.set(mapRef, {
      ...merged,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final userRef = FirebaseFirestore.instance
        .collection(userMasterCollection)
        .doc(user.uuid);
    batch.set(
      userRef,
      {
        ...user
            .copyWith(
              roleId: 'ORG_ADMIN',
              orgId: orgIdUpper,
              requestedOrgId: orgIdUpper,
              requestedOrgName: organization.orgName,
              status: 'Approved',
            )
            .toMap(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<String?> findExistingMappingDocumentId({
    required String uuid,
    required String orgIdUpper,
  }) async {
    final candidates = authService.uuidCandidates(uuid);
    for (final candidate in candidates) {
      final snap = await FirebaseFirestore.instance
          .collection(mappingCollection)
          .where('uuid', isEqualTo: candidate)
          .limit(20)
          .get();
      if (snap.docs.isEmpty) {
        continue;
      }
      final sameOrg = snap.docs.where((doc) {
        final data = doc.data();
        return (data['org_id'] ?? '').toString().trim().toUpperCase() == orgIdUpper;
      });
      if (sameOrg.isNotEmpty) {
        return sameOrg.first.id;
      }
      final registeredPending = snap.docs.where((doc) {
        final data = doc.data();
        return (data['role_id'] ?? '').toString().trim().isEmpty &&
            (data['status'] ?? '').toString().trim().toLowerCase() == 'registered';
      });
      if (registeredPending.isNotEmpty) {
        return registeredPending.first.id;
      }
      return snap.docs.first.id;
    }
    return null;
  }

  Future<void> assignDeptAdminToDepartment({
    required OrgUserRoleMappingItem mapping,
    required DepartmentMasterItem department,
  }) async {
    final user = await getUserMaster(mapping.uuid);
    if (user == null) {
      throw StateError('User not found in smcUserMaster');
    }
    final batch = FirebaseFirestore.instance.batch();
    final orgUpper = mapping.orgId.trim().toUpperCase();
    String? docId = mapping.documentId.trim().isNotEmpty
        ? mapping.documentId.trim()
        : null;
    if (docId == null) {
      docId = await findExistingMappingDocumentId(
        uuid: mapping.uuid,
        orgIdUpper: orgUpper,
      );
    }
    if (docId == null || docId.isEmpty) {
      throw StateError(
        'Existing mapping document not found for this user. Cannot assign department.',
      );
    }
    final mapRef =
        FirebaseFirestore.instance.collection(mappingCollection).doc(docId);
    batch.set(
      mapRef,
      {
        ...mapping
            .copyWith(
              deptId: department.deptId.trim(),
              status: 'Approved',
            )
            .toMap(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final userRef = FirebaseFirestore.instance
        .collection(userMasterCollection)
        .doc(user.uuid);
    batch.set(
      userRef,
      {
        ...user
            .copyWith(
              deptId: department.deptId.trim(),
              status: 'Approved',
            )
            .toMap(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> assignFacultyOrStudentDepartment({
    required OrgUserRoleMappingItem mapping,
    required DepartmentMasterItem department,
  }) async {
    final user = await getUserMaster(mapping.uuid);
    if (user == null) {
      throw StateError('User not found in smcUserMaster');
    }
    final batch = FirebaseFirestore.instance.batch();
    final orgUpper = mapping.orgId.trim().toUpperCase();
    final docId = mappingDocumentId(mapping, orgUpper);
    final mapRef =
        FirebaseFirestore.instance.collection(mappingCollection).doc(docId);
    batch.set(
      mapRef,
      {
        ...mapping.copyWith(deptId: department.deptId.trim()).toMap(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final userRef = FirebaseFirestore.instance
        .collection(userMasterCollection)
        .doc(user.uuid);
    batch.set(
      userRef,
      {
        ...user.copyWith(deptId: department.deptId.trim()).toMap(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
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
