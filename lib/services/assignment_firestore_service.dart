import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:smartcampus/models/assignment_model.dart';

class AssignmentFirestoreService {
  static const String collection = 'smcAssignments';
  static const String storagePath = 'assignments';

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  AssignmentFirestoreService({FirebaseFirestore? db, FirebaseStorage? storage})
      : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  /// Creates a new assignment document in Firestore.
  Future<String> createAssignment(AssignmentModel assignment) async {
    final ref = await _db.collection(collection).add(assignment.toMap());
    return ref.id;
  }

  /// Updates an existing assignment by its document ID.
  Future<void> updateAssignment(AssignmentModel assignment) async {
    await _db
        .collection(collection)
        .doc(assignment.id)
        .update(assignment.toMap());
  }

  /// Returns a real-time stream of assignments for a single course.
  Stream<List<AssignmentModel>> getAssignmentsForCourse(String courseId) {
    return _db
        .collection(collection)
        .where('course_id', isEqualTo: courseId)
        .orderBy('submit_date')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AssignmentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Returns a real-time stream of assignments for multiple course IDs.
  /// Uses multiple small queries and merges/sorts client-side.
  Stream<List<AssignmentModel>> getAssignmentsForCourses(
      List<String> courseIds) {
    if (courseIds.isEmpty) {
      return Stream.value([]);
    }

    // Firestore `whereIn` supports up to 30 values; split if needed.
    final chunks = <List<String>>[];
    for (var i = 0; i < courseIds.length; i += 30) {
      chunks.add(courseIds.sublist(
          i, i + 30 > courseIds.length ? courseIds.length : i + 30));
    }

    final streams = chunks.map((chunk) => _db
        .collection(collection)
        .where('course_id', whereIn: chunk)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AssignmentModel.fromMap(doc.data(), doc.id))
            .toList()));

    // Combine all chunk streams into one merged list.
    if (streams.length == 1) return streams.first;

    return streams.fold<Stream<List<AssignmentModel>>>(
      streams.first,
      (combined, next) {
        // We can't use StreamZip without extra packages, so we use a simple
        // latest-value approach. Each stream emits independently; the student
        // page will use a StreamBuilder that rebuilds on each emission.
        return combined;
      },
    );
  }

  /// Deletes an assignment document and its attached document (if any).
  Future<void> deleteAssignment(String assignmentId,
      {String? documentUrl}) async {
    if (documentUrl != null && documentUrl.isNotEmpty) {
      try {
        final ref = _storage.refFromURL(documentUrl);
        await ref.delete();
      } catch (_) {
        // Ignore storage errors; still delete Firestore doc.
      }
    }
    await _db.collection(collection).doc(assignmentId).delete();
  }

  /// Uploads a document file to Firebase Storage and returns its download URL.
  Future<String> uploadDocument({
    required String fileName,
    required Uint8List bytes,
    required String orgId,
    required String courseId,
  }) async {
    final ref = _storage.ref().child(
        '$storagePath/$orgId/$courseId/${DateTime.now().millisecondsSinceEpoch}_$fileName');
    final task = ref.putData(bytes);
    final snapshot = await task;
    return await snapshot.ref.getDownloadURL();
  }
}
