import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:smartcampus/models/assessment_model.dart';

class AssessmentFirestoreService {
  static const String collection = 'smcAssessments';
  static const String submissionsCollection = 'smcAssessmentSubmissions';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<AssessmentModel>> getAssessmentsForFaculty({
    required String facultyId,
  }) {
    return _firestore.collection(collection).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => AssessmentModel.fromFirestore(doc.id, doc.data()))
          .where((a) => a.facultyId == facultyId)
          .toList();
      list.sort((a, b) => b.createdOn.compareTo(a.createdOn));
      print('Assessments for faculty $facultyId: ${list.length} found');
      return list;
    });
  }

  Stream<List<AssessmentModel>> getAssessmentsForStudent({
    required String studentId,
    required List<String> sections,
    required String batch,
    required String semester,
    List<String> enrolledCourseIds = const [],
  }) {
    return _firestore.collection(collection).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => AssessmentModel.fromFirestore(doc.id, doc.data()))
          .where((a) {
        // Handle new scheme/semester based assessments
        if (a.scheme.isNotEmpty && a.semester.isNotEmpty) {
          // Check if assessment matches student's batch (scheme) and semester
          // Use startsWith to handle year vs year-range formats
          final schemeMatch = batch.startsWith(a.scheme) || a.scheme.startsWith(batch);
          final semesterMatch = a.semester == semester;
          
          if (!schemeMatch || !semesterMatch) return false;
          
          if (a.allStudentsInSection) {
            return enrolledCourseIds.contains(a.courseId);
          } else {
            return a.selectedStudentIds.contains(studentId);
          }
        }
        
        // Handle legacy section-based assessments
        if (a.allStudentsInSection) {
          if (sections.contains(a.section)) return true;
          if (enrolledCourseIds.contains(a.courseId)) return true;
          return false;
        } else {
          if (a.selectedStudentIds.contains(studentId)) return true;
          if (enrolledCourseIds.contains(a.courseId) && sections.contains(a.section)) return true;
          return false;
        }
      }).toList();
      list.sort((a, b) => b.createdOn.compareTo(a.createdOn));
      return list;
    });
  }

  Future<AssessmentModel?> getAssessmentById(String id) async {
    final doc = await _firestore.collection(collection).doc(id).get();
    if (!doc.exists) return null;
    return AssessmentModel.fromFirestore(doc.id, doc.data()!);
  }

  Future<String> createAssessment(AssessmentModel assessment) async {
    final docRef =
        await _firestore.collection(collection).add(assessment.toMap());
    return docRef.id;
  }

  Future<void> updateAssessment(AssessmentModel assessment) async {
    await _firestore
        .collection(collection)
        .doc(assessment.id)
        .update(assessment.toMap());
  }

  Future<void> updateMarksEntries({
    required String assessmentId,
    required List<AssessmentMarkEntry> entries,
  }) async {
    await _firestore.collection(collection).doc(assessmentId).update({
      'marksEntries': entries.map((e) => e.toMap()).toList(),
      'updatedOn': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteAssessment(String id) async {
    await _firestore.collection(collection).doc(id).delete();
  }

  // Assessment Submission Methods
  Future<String> uploadAssessmentSubmissionFile({
    required String fileName,
    required List<int> bytes,
    required String orgId,
    required String assessmentId,
    required String studentId,
  }) async {
    final path = 'organizations/$orgId/assessments/submissions/$assessmentId/$studentId/$fileName';
    final ref = _storage.ref().child(path);
    final uploadTask = ref.putData(Uint8List.fromList(bytes));
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> createAssessmentSubmission(AssessmentSubmissionModel submission) async {
    await _firestore.collection(submissionsCollection).doc(submission.id).set(submission.toMap());
  }

  Future<AssessmentSubmissionModel?> getAssessmentSubmissionByAssessmentAndStudent({
    required String assessmentId,
    required String studentId,
  }) async {
    final query = await _firestore
        .collection(submissionsCollection)
        .where('assessment_id', isEqualTo: assessmentId)
        .where('student_id', isEqualTo: studentId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    final data = doc.data() as Map<String, dynamic>;
    return AssessmentSubmissionModel.fromMap(data, doc.id);
  }

  Stream<List<AssessmentSubmissionModel>> getAssessmentSubmissionsByAssessment(
    String assessmentId,
  ) {
    return _firestore
        .collection(submissionsCollection)
        .where('assessment_id', isEqualTo: assessmentId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AssessmentSubmissionModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<AssessmentSubmissionModel>> getAssessmentSubmissionsByStudent(
    String studentId,
  ) {
    return _firestore
        .collection(submissionsCollection)
        .where('student_id', isEqualTo: studentId)
        .orderBy('submitted_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AssessmentSubmissionModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
