import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_block_record.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_day.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_record.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_time_slot.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_resolver.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/faculty_assigned_class.dart';
import 'package:smartcampus/services/course_firestore_service.dart';

class StudentClassResolver {
  static const Map<String, String> _romanToDigit = {
    'I': '1',
    'II': '2',
    'III': '3',
    'IV': '4',
  };

  static String normalizeSemester(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final upper = trimmed.toUpperCase();
    if (_romanToDigit.containsKey(upper)) {
      return _romanToDigit[upper]!;
    }

    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      return digits;
    }

    return upper;
  }

  static bool semestersMatch(String a, String b) {
    final left = normalizeSemester(a);
    final right = normalizeSemester(b);
    if (left.isEmpty || right.isEmpty) {
      return false;
    }
    return left == right;
  }

  static bool batchesMatch(String a, String b) {
    final left = a.trim();
    final right = b.trim();
    if (left.isEmpty || right.isEmpty) {
      return false;
    }
    return left.toLowerCase() == right.toLowerCase();
  }

  static Set<String> enrolledCourseKeys(List<CourseModel> courses) {
    return FacultyClassResolver.assignedCourseKeys(courses);
  }

  static bool timetableMatchesStudent({
    required TimeTableRecord table,
    required StudentModel student,
  }) {
    if (!batchesMatch(table.batch, student.batch)) {
      return false;
    }
    return semestersMatch(table.semester, student.currentSemester);
  }

  static bool blockMatchesStudent({
    required TimeBlockRecord block,
    required Set<String> courseKeys,
  }) {
    final courseId = block.courseId.trim();
    if (courseId.isEmpty) {
      return false;
    }
    return courseKeys.contains(courseId);
  }

  static List<FacultyAssignedClass> resolveAssignedClasses({
    required List<TimeBlockRecord> timeBlocks,
    required List<TimeTableRecord> timeTables,
    required StudentModel student,
    required List<CourseModel> enrolledCourses,
    List<TimeTableDay> timetableDays = const [],
    List<TimeTableTimeSlot> timeSlots = const [],
  }) {
    if (timeBlocks.isEmpty || timeTables.isEmpty) {
      return const [];
    }

    final tableByUid = {
      for (final table in timeTables)
        if (table.timeTableUid.trim().isNotEmpty)
          table.timeTableUid.trim(): table,
    };
    final courseKeys = enrolledCourseKeys(enrolledCourses);

    final classes = <FacultyAssignedClass>[];
    for (final block in timeBlocks) {
      if (FacultyClassResolver.isBreakBlock(block)) {
        continue;
      }
      if (!blockMatchesStudent(block: block, courseKeys: courseKeys)) {
        continue;
      }

      final table = tableByUid[block.timeTableUid.trim()];
      if (table == null) {
        continue;
      }
      if (!timetableMatchesStudent(table: table, student: student)) {
        continue;
      }

      classes.add(FacultyAssignedClass(block: block, timeTable: table));
    }

    classes.sort((a, b) {
      final courseCompare =
          a.courseName.toLowerCase().compareTo(b.courseName.toLowerCase());
      if (courseCompare != 0) {
        return courseCompare;
      }
      return a.courseId.toLowerCase().compareTo(b.courseId.toLowerCase());
    });

    return classes;
  }

  static String studentAttendanceKey(StudentModel student) {
    return CourseFirestoreService.studentEnrollmentKey(student);
  }
}
