import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartcampus/data/org_field.dart';
import 'package:smartcampus/data/student_model.dart';

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

  Future<void> createStudent(StudentModel student) async {
    final orgId = normalizeOrgId(student.orgId);
    final deptId = normalizeDeptId(student.deptId);

    final existing = await _db
        .collection(_collection)
        .where('student_id', isEqualTo: student.studentId)
        .where(OrgField.orgIdKey, isEqualTo: orgId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception(
        'Student ID (USN) "${student.studentId}" already exists for this organisation.',
      );
    }

    await _db.collection(_collection).add(
          student.copyWith(orgId: orgId, deptId: deptId).toMap(),
        );
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
  // ── Delete ─────────────────────────────────────────────────────

  Future<void> deleteStudent(String documentId) async {
    await _db.collection(_collection).doc(documentId).delete();
  }
}
