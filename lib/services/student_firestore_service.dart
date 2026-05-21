import 'package:cloud_firestore/cloud_firestore.dart';
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
  Future<void> createStudent(StudentModel student) async {

    final existing = await _db
        .collection(_collection)
        .where('student_id', isEqualTo: student.studentId)
        .where('org_id', isEqualTo: student.orgId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception(
        'Student ID (USN) "${student.studentId}" already exists for this organisation.',
      );
    }

    await _db.collection(_collection).add(student.toMap());
  }

  // ── Read ───────────────────────────────────────────────────────

  /// Returns all students for a given department within an organisation.
  Future<List<StudentModel>> listStudentsForDept({
    required String orgId,
    required String deptId,
  }) async {
    final snap = await _db
        .collection(_collection)
        .where('org_id', isEqualTo: orgId)
        .where('dept_id', isEqualTo: deptId)
        .get();

    return snap.docs
        .map((d) => StudentModel.fromMap(d.data(), documentId: d.id))
        .toList();
  }

  /// Returns all students for a given organisation (all departments).
  Future<List<StudentModel>> listStudentsForOrg(String orgId) async {
    final snap = await _db
        .collection(_collection)
        .where('org_id', isEqualTo: orgId)
        .get();

    return snap.docs
        .map((d) => StudentModel.fromMap(d.data(), documentId: d.id))
        .toList();
  }

  // ── Update ─────────────────────────────────────────────────────

  /// Updates an existing student document identified by Firestore document ID.
  Future<void> updateStudent({
    required String documentId,
    required StudentModel updated,
  }) async {
    await _db
        .collection(_collection)
        .doc(documentId)
        .set(updated.toMap(), SetOptions(merge: true));
  }

  // ── Delete ─────────────────────────────────────────────────────

  Future<void> deleteStudent(String documentId) async {
    await _db.collection(_collection).doc(documentId).delete();
  }
}
