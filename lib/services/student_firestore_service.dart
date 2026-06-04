import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartcampus/data/org_field.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/services/firebase_auth_service.dart';

/// Handles all Firestore operations for the smcStudentMaster collection.
class StudentFirestoreService {
  static const String _collection = 'smcStudentMaster';

  final FirebaseFirestore _db;

  StudentFirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ── Create ─────────────────────────────────────────────────────

  /// Saves a new student record. Throws if [studentId] already exists for
  /// this [orgId].
  static String normalizeOrgId(String orgId) => OrgField.normalize(orgId);

  static String normalizeDeptId(String deptId) => OrgField.normalize(deptId);

  StudentModel _withResolvedUuid(StudentModel student) {
    final resolved = student.resolvedUuid;
    return student.copyWith(
      orgId: normalizeOrgId(student.orgId),
      deptId: normalizeDeptId(student.deptId),
      uuid: resolved,
    );
  }

  Future<void> createStudent(StudentModel student) async {
    final persisted = _withResolvedUuid(student);
    final orgId = persisted.orgId;

    final existing = await _db
        .collection(_collection)
        .where('student_id', isEqualTo: persisted.studentId)
        .where(OrgField.orgIdKey, isEqualTo: orgId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception(
        'Student ID (USN) "${persisted.studentId}" already exists for this organisation.',
      );
    }

    await _db.collection(_collection).add(persisted.toMap());
  }

  // ── Read ───────────────────────────────────────────────────────

  /// Organisation-wide students — scoped by [org_id] only.
  Future<List<StudentModel>> listStudentsForOrg(String orgId) async {
    final orgNorm = normalizeOrgId(orgId);
    if (orgNorm.isEmpty) {
      return const [];
    }
    final snap = await _db
        .collection(_collection)
        .where(OrgField.orgIdKey, isEqualTo: orgNorm)
        .get();

    return snap.docs
        .map((d) => StudentModel.fromMap(d.data(), documentId: d.id))
        .toList();
  }

  /// Alias kept for call sites — uses [org_id] only (ignores department).
  Future<List<StudentModel>> listStudentsForDept({
    required String orgId,
    String deptId = '',
  }) {
    return listStudentsForOrg(orgId);
  }

  // ── Update ─────────────────────────────────────────────────────

  /// Updates an existing student document identified by Firestore document ID.
  Future<void> updateStudent({
    required String documentId,
    required StudentModel updated,
  }) async {
    final persisted = _withResolvedUuid(updated);
    await _db
        .collection(_collection)
        .doc(documentId)
        .set(persisted.toMap(), SetOptions(merge: true));
  }

  Future<StudentModel?> findStudent({
    required String orgId,
    required String studentId,
  }) async {
    final orgUpper = normalizeOrgId(orgId);
    final snap = await _db
        .collection(_collection)
        .where(OrgField.orgIdKey, isEqualTo: orgUpper)
        .where('student_id', isEqualTo: studentId)
        .limit(1)
        .get();

    if(snap.docs.isEmpty){
      return null;
    }

    return StudentModel.fromMap(
      snap.docs.first.data(),
      documentId: snap.docs.first.id,
    );
  }

  /// Finds a student by [uuid] (country-code mobile without +).
  Future<StudentModel?> getStudentByUuid(String mobileOrUuid) async {
    final authService = FirebaseAuthService();
    final uuidCandidates = <String>{
      StudentModel.normalizeUuid(mobileOrUuid),
    };
    for (final candidate in authService.uuidCandidates(mobileOrUuid)) {
      final normalized = StudentModel.normalizeUuid(candidate);
      if (normalized.isNotEmpty) {
        uuidCandidates.add(normalized);
      }
    }

    for (final uuid in uuidCandidates) {
      if (uuid.isEmpty) {
        continue;
      }
      final snap = await _db
          .collection(_collection)
          .where('uuid', isEqualTo: uuid)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        return StudentModel.fromMap(doc.data(), documentId: doc.id);
      }
    }

    return null;
  }

  /// Resolves the student profile for a logged-in user.
  Future<StudentModel?> resolveStudentForUser({
    required String orgId,
    required String deptId,
    required String displayName,
    required String uuid,
    StudentModel? prefetched,
  }) async {
    if (prefetched != null) {
      return prefetched;
    }

    final byUuid = await getStudentByUuid(uuid);
    if (byUuid == null) {
      return null;
    }
    if (orgId.isNotEmpty &&
        normalizeOrgId(byUuid.orgId) != normalizeOrgId(orgId)) {
      return null;
    }
    return byUuid;
  }

  // ── Delete ─────────────────────────────────────────────────────

  Future<void> deleteStudent(String documentId) async {
    await _db.collection(_collection).doc(documentId).delete();
  }
}
