import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/data/org_field.dart';
import 'package:smartcampus/services/firebase_auth_service.dart';

/// Handles all Firestore operations for the smcFacultyMaster collection.
class FacultyFirestoreService {
  static const String _collection = 'smcFacultyMaster';

  final FirebaseFirestore _db;

  FacultyFirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ── Create ─────────────────────────────────────────────────────

  /// Saves a new faculty record.  Throws if [facultyId] already exists for
  /// this [orgId] (checked client-side to give a meaningful error message).
  static String normalizeOrgId(String orgId) => OrgField.normalize(orgId);

  static String normalizeDeptId(String deptId) => OrgField.normalize(deptId);

  Future<void> createFaculty(FacultyModel faculty) async {
    final orgId = normalizeOrgId(faculty.orgId);
    final deptId = normalizeDeptId(faculty.deptId);
    final existing = await _db
        .collection(_collection)
        .where('faculty_id', isEqualTo: faculty.facultyId)
        .where(OrgField.orgIdKey, isEqualTo: orgId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception(
        'Faculty ID "${faculty.facultyId}" already exists for this organisation.',
      );
    }

    await _db.collection(_collection).add(
          faculty.copyWith(orgId: orgId, deptId: deptId).toMap(),
        );
  }

  // ── Read ───────────────────────────────────────────────────────

  /// Organisation-wide faculty — scoped by [org_id] only.
  Future<List<FacultyModel>> listFacultyForOrg(String orgId) async {
    final orgNorm = normalizeOrgId(orgId);
    if (orgNorm.isEmpty) {
      return const [];
    }
    final snap = await _db
        .collection(_collection)
        .where(OrgField.orgIdKey, isEqualTo: orgNorm)
        .get();

    return snap.docs
        .map((d) => FacultyModel.fromMap(d.data(), documentId: d.id))
        .toList();
  }

  /// Alias kept for call sites — uses [org_id] only (ignores department).
  Future<List<FacultyModel>> listFacultyForDept({
    required String orgId,
    String deptId = '',
  }) {
    return listFacultyForOrg(orgId);
  }

  /// Finds a faculty record by login mobile / phone variants.
  Future<FacultyModel?> getFacultyByMobile(String mobileOrUuid) async {
    final authService = FirebaseAuthService();
    final candidates = authService.uuidCandidates(mobileOrUuid);
    final mobileVariants = <String>{};

    for (final candidate in candidates) {
      mobileVariants.add(candidate);
      final digits = candidate.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10) {
        final last10 = digits.substring(digits.length - 10);
        mobileVariants.add(last10);
        mobileVariants.add('91$last10');
        mobileVariants.add('+91$last10');
        mobileVariants.add(digits);
      }
    }

    for (final mobile in mobileVariants) {
      if (mobile.isEmpty) {
        continue;
      }
      final snap = await _db
          .collection(_collection)
          .where('mobile', isEqualTo: mobile)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        return FacultyModel.fromMap(doc.data(), documentId: doc.id);
      }
    }
    return null;
  }

  /// Resolves the faculty profile for a logged-in user.
  Future<FacultyModel?> resolveFacultyForUser({
    required String orgId,
    required String deptId,
    required String displayName,
    required String uuid,
    FacultyModel? prefetched,
  }) async {
    if (prefetched != null) {
      return prefetched;
    }

    final byMobile = await getFacultyByMobile(uuid);
    if (byMobile != null) {
      if (orgId.isEmpty ||
          normalizeOrgId(byMobile.orgId) == normalizeOrgId(orgId)) {
        return byMobile;
      }
    }

    final trimmedName = displayName.trim();
    if (orgId.isNotEmpty && deptId.isNotEmpty) {
      final deptFaculty = await listFacultyForDept(
        orgId: orgId,
        deptId: deptId,
      );
      for (final faculty in deptFaculty) {
        if (faculty.fullName == trimmedName ||
            faculty.facultyId == trimmedName) {
          return faculty;
        }
      }
    }

    if (orgId.isNotEmpty) {
      final orgFaculty = await listFacultyForOrg(orgId);
      for (final faculty in orgFaculty) {
        if (faculty.fullName == trimmedName ||
            faculty.facultyId == trimmedName) {
          return faculty;
        }
      }
    }

    return null;
  }

  // ── Update ─────────────────────────────────────────────────────

  /// Updates an existing faculty document identified by Firestore document ID.
  Future<void> updateFaculty({
    required String documentId,
    required FacultyModel updated,
  }) async {
    final orgId = normalizeOrgId(updated.orgId);
    final deptId = normalizeDeptId(updated.deptId);
    await _db
        .collection(_collection)
        .doc(documentId)
        .set(
          updated.copyWith(orgId: orgId, deptId: deptId).toMap(),
          SetOptions(merge: true),
        );
  }

  // ── Delete ─────────────────────────────────────────────────────

  Future<void> deleteFaculty(String documentId) async {
    await _db.collection(_collection).doc(documentId).delete();
  }
}
