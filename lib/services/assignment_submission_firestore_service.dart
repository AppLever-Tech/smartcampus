import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:smartcampus/models/assignment_submission_model.dart';

class AssignmentSubmissionFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference get _collection =>
      _firestore.collection('smcAssignmentSubmissions');

  Future<String> uploadSubmissionFile({
    required String fileName,
    required List<int> bytes,
    required String orgId,
    required String assignmentId,
    required String studentId,
  }) async {
    final path = 'organizations/$orgId/assignments/$assignmentId/submissions/$studentId/$fileName';
    final ref = _storage.ref().child(path);
    final uploadTask = ref.putData(Uint8List.fromList(bytes));
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> createSubmission(AssignmentSubmissionModel submission) async {
    await _collection.doc(submission.id).set(submission.toMap());
  }

  Future<AssignmentSubmissionModel?> getSubmissionByAssignmentAndStudent({
    required String assignmentId,
    required String studentId,
  }) async {
    final query = await _collection
        .where('assignment_id', isEqualTo: assignmentId)
        .where('student_id', isEqualTo: studentId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    final data = doc.data() as Map<String, dynamic>;
    return AssignmentSubmissionModel.fromMap(data, doc.id);
  }

  Stream<List<AssignmentSubmissionModel>> getSubmissionsByAssignment(
    String assignmentId,
  ) {
    return _collection
        .where('assignment_id', isEqualTo: assignmentId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AssignmentSubmissionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<List<AssignmentSubmissionModel>> getSubmissionsByStudent(
    String studentId,
  ) {
    return _collection
        .where('student_id', isEqualTo: studentId)
        .orderBy('submitted_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AssignmentSubmissionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }
}
