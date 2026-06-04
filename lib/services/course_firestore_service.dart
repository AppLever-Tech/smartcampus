import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course_model.dart';
import '../data/faculty_model.dart';

class CourseFirestoreService {
  static const String collection = 'smcCoursesMaster';

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Stream<List<CourseModel>> getCourses() {
    return _firestore
        .collection(collection)
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
        .collection(collection)
        .add(course.toMap());
  }

  Future<void> deleteCourse(
      String id,
      ) async {

    await _firestore
        .collection(collection)
        .doc(id)
        .delete();
  }

  Future<void> updateCourseFields(
    String id,
    Map<String, dynamic> fields,
  ) async {
    await _firestore.collection(collection).doc(id).update(fields);
  }

  Future<void> enrollStudents(String courseId, List<String> studentKeys) async {
    if (studentKeys.isEmpty) {
      return;
    }
    await _firestore.collection(collection).doc(courseId).update({
      'enrolled_student_ids': FieldValue.arrayUnion(studentKeys),
    });
  }

  static bool isCourseAssignedToFaculty(
    CourseModel course,
    FacultyModel faculty,
  ) {
    final String facultyField = course.faculty.trim();
    if (facultyField.isEmpty) {
      return false;
    }
    return facultyField == faculty.fullName ||
        facultyField == faculty.facultyId ||
        facultyField.contains(faculty.fullName) ||
        facultyField.contains(faculty.facultyId);
  }

  static List<CourseModel> filterCoursesForFaculty(
    List<CourseModel> courses,
    FacultyModel faculty,
  ) {
    return courses
        .where((course) => isCourseAssignedToFaculty(course, faculty))
        .toList();
  }
}