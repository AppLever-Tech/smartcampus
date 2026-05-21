import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartcampus/data/faculty_model.dart';

/// Handles all Firestore operations for the smcFacultyMaster collection.
class FacultyFirestoreService {
  static const String _collection = 'smcFacultyMaster';

  final FirebaseFirestore _db;

  FacultyFirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ── Create ─────────────────────────────────────────────────────

  /// Saves a new faculty record.  Throws if [facultyId] already exists for
  /// this [orgId] (checked client-side to give a meaningful error message).
  Future<void> createFaculty(FacultyModel faculty) async {
    // Optional duplicate check – you can remove this if Firestore rules
    // already enforce uniqueness on faculty_id + org_id.
    final existing = await _db
        .collection(_collection)
        .where('faculty_id', isEqualTo: faculty.facultyId)
        .where('org_id', isEqualTo: faculty.orgId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception(
        'Faculty ID "${faculty.facultyId}" already exists for this organisation.',
      );
    }

    await _db.collection(_collection).add(faculty.toMap());
  }

  // ── Read ───────────────────────────────────────────────────────

  /// Returns all faculty for a given department within an organisation.
  Future<List<FacultyModel>> listFacultyForDept({
    required String orgId,
    required String deptId,
  }) async {
    final snap = await _db
        .collection(_collection)
        .where('org_id', isEqualTo: orgId)
        .where('dept_id', isEqualTo: deptId)
        .get();

    return snap.docs
        .map((d) => FacultyModel.fromMap(d.data(), documentId: d.id))
        .toList();
  }

  /// Returns all faculty for a given organisation (all departments).
  Future<List<FacultyModel>> listFacultyForOrg(String orgId) async {
    final snap = await _db
        .collection(_collection)
        .where('org_id', isEqualTo: orgId)
        
        .get();

    return snap.docs
        .map((d) => FacultyModel.fromMap(d.data(), documentId: d.id))
        .toList();
  }

  // ── Update ─────────────────────────────────────────────────────

  /// Updates an existing faculty document identified by Firestore document ID.
  Future<void> updateFaculty({
    required String documentId,
    required FacultyModel updated,
  }) async {
    await _db
        .collection(_collection)
        .doc(documentId)
        .set(updated.toMap(), SetOptions(merge: true));
  }

  // ── Delete ─────────────────────────────────────────────────────

  Future<void> deleteFaculty(String documentId) async {
    await _db.collection(_collection).doc(documentId).delete();
  }
}
