import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course_model.dart';

class CourseFirestoreService {

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Stream<List<CourseModel>> getCourses() {
    return _firestore
        .collection('courses')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CourseModel.fromFirestore(
          doc.id,
          doc.data(),
        );
      }).toList();
    });
  }

  Future<void> addCourse(
      CourseModel course,
      ) async {

    await _firestore
        .collection('courses')
        .add(course.toMap());
  }

  Future<void> deleteCourse(
      String id,
      ) async {

    await _firestore
        .collection('courses')
        .doc(id)
        .delete();
  }

  Future<void> updateCourseFields(
    String id,
    Map<String, dynamic> fields,
  ) async {
    await _firestore.collection('courses').doc(id).update(fields);
  }

  Future<void> enrollStudents(String courseId, List<String> studentKeys) async {
    if (studentKeys.isEmpty) {
      return;
    }
    await _firestore.collection('courses').doc(courseId).update({
      'enrolled_student_ids': FieldValue.arrayUnion(studentKeys),
    });
  }
}