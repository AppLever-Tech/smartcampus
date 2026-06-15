import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_date_utils.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/completed_class_record.dart';
import 'package:smartcampus/screens/student/student_class_management/student_class_resolver.dart';

class StudentClassFirestoreService {
  static bool recordMatchesStudent({
    required CompletedClassRecord record,
    required StudentModel student,
    List<CourseModel> enrolledCourses = const [],
  }) {
    if (!StudentClassResolver.batchesMatch(record.batch, student.batch)) {
      return false;
    }
    if (!StudentClassResolver.semestersMatch(
      record.semester,
      student.currentSemester,
    )) {
      return false;
    }

    if (enrolledCourses.isEmpty) {
      return true;
    }

    final courseKeys = StudentClassResolver.enrolledCourseKeys(enrolledCourses);
    final courseId = record.courseId.trim();
    return courseKeys.contains(courseId);
  }

  static List<CompletedClassRecord> filterForStudent({
    required List<CompletedClassRecord> records,
    required StudentModel student,
    List<CourseModel> enrolledCourses = const [],
  }) {
    return records
        .where(
          (record) => recordMatchesStudent(
            record: record,
            student: student,
            enrolledCourses: enrolledCourses,
          ),
        )
        .toList();
  }

  static List<CompletedClassRecord> filterActiveForStudent({
    required List<CompletedClassRecord> records,
    required StudentModel student,
    List<CourseModel> enrolledCourses = const [],
    DateTime? referenceDate,
  }) {
    final today = FacultyClassDateUtils.dateOnly(referenceDate ?? DateTime.now());

    return filterForStudent(
      records: records,
      student: student,
      enrolledCourses: enrolledCourses,
    ).where((record) {
      return record.isActive &&
          FacultyClassDateUtils.isSameDay(record.classDate, today);
    }).toList();
  }

  static List<CompletedClassRecord> filterCompletedForStudent({
    required List<CompletedClassRecord> records,
    required StudentModel student,
    List<CourseModel> enrolledCourses = const [],
  }) {
    return filterForStudent(
      records: records,
      student: student,
      enrolledCourses: enrolledCourses,
    ).where((record) => record.isCompleted).toList();
  }

  static Set<String> sessionKeysExcludedFromUpcoming({
    required List<CompletedClassRecord> records,
    required StudentModel student,
    List<CourseModel> enrolledCourses = const [],
  }) {
    return filterForStudent(
      records: records,
      student: student,
      enrolledCourses: enrolledCourses,
    )
        .where((record) => record.isActive || record.isCompleted)
        .map((record) => record.sessionKeyValue)
        .toSet();
  }

  static String? attendanceStatusForStudent({
    required CompletedClassRecord record,
    required StudentModel student,
  }) {
    final key = StudentClassResolver.studentAttendanceKey(student);
    if (!record.attendance.containsKey(key)) {
      return null;
    }
    return record.attendance[key] == true ? 'Present' : 'Absent';
  }
}
