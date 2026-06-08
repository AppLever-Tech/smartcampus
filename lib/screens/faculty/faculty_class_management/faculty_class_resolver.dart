import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_block_record.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_day.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_record.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_time_slot.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/faculty_assigned_class.dart';
import 'package:smartcampus/services/course_firestore_service.dart';

class FacultyClassResolver {
  static const Set<String> breakLabels = {
    'TEA BREAK',
    'LUNCH BREAK',
  };

  static List<FacultyAssignedClass> resolveAssignedClasses({
    required List<TimeBlockRecord> timeBlocks,
    required List<TimeTableRecord> timeTables,
    required FacultyModel faculty,
    required List<CourseModel> assignedCourses,
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
    final courseKeys = assignedCourseKeys(assignedCourses);
    final facultyKeys = facultyKeysFor(faculty);
    final dayOrderByUid = {
      for (final day in timetableDays)
        if (day.dayUid.trim().isNotEmpty) day.dayUid.trim(): day.dayOrder,
    };
    final dayOrderByName = {
      for (final day in timetableDays)
        if (day.dayName.trim().isNotEmpty)
          day.dayName.trim().toLowerCase(): day.dayOrder,
    };
    final slotOrderByUid = {
      for (final slot in timeSlots)
        if (slot.timeslotUid.trim().isNotEmpty)
          slot.timeslotUid.trim(): slot.timeslotOrder,
    };
    final slotOrderByName = {
      for (final slot in timeSlots)
        if (slot.timeslotName.trim().isNotEmpty)
          slot.timeslotName.trim().toLowerCase(): slot.timeslotOrder,
    };

    final classes = <FacultyAssignedClass>[];
    for (final block in timeBlocks) {
      if (isBreakBlock(block)) {
        continue;
      }
      if (!blockMatchesFaculty(
        block: block,
        courseKeys: courseKeys,
        facultyKeys: facultyKeys,
      )) {
        continue;
      }

      final table = tableByUid[block.timeTableUid.trim()];
      if (table == null) {
        continue;
      }

      classes.add(FacultyAssignedClass(block: block, timeTable: table));
    }

    classes.sort((a, b) {
      final semesterCompare = _compareSemester(a.semester, b.semester);
      if (semesterCompare != 0) {
        return semesterCompare;
      }

      final schemeCompare =
          a.scheme.toLowerCase().compareTo(b.scheme.toLowerCase());
      if (schemeCompare != 0) {
        return schemeCompare;
      }

      final batchCompare = a.batch.toLowerCase().compareTo(b.batch.toLowerCase());
      if (batchCompare != 0) {
        return batchCompare;
      }

      final sectionCompare =
          a.section.toLowerCase().compareTo(b.section.toLowerCase());
      if (sectionCompare != 0) {
        return sectionCompare;
      }

      final dayOrderA = _dayOrderForClass(
        assignedClass: a,
        dayOrderByUid: dayOrderByUid,
        dayOrderByName: dayOrderByName,
      );
      final dayOrderB = _dayOrderForClass(
        assignedClass: b,
        dayOrderByUid: dayOrderByUid,
        dayOrderByName: dayOrderByName,
      );
      if (dayOrderA != dayOrderB) {
        return dayOrderA.compareTo(dayOrderB);
      }

      final slotOrderA = _slotOrderForClass(
        assignedClass: a,
        slotOrderByUid: slotOrderByUid,
        slotOrderByName: slotOrderByName,
      );
      final slotOrderB = _slotOrderForClass(
        assignedClass: b,
        slotOrderByUid: slotOrderByUid,
        slotOrderByName: slotOrderByName,
      );
      if (slotOrderA != slotOrderB) {
        return slotOrderA.compareTo(slotOrderB);
      }

      final courseCompare =
          a.courseName.toLowerCase().compareTo(b.courseName.toLowerCase());
      if (courseCompare != 0) {
        return courseCompare;
      }

      return a.courseId.toLowerCase().compareTo(b.courseId.toLowerCase());
    });

    return classes;
  }

  static Map<String, List<FacultyAssignedClass>> groupBySemester(
    List<FacultyAssignedClass> classes,
  ) {
    final grouped = <String, List<FacultyAssignedClass>>{};
    for (final assignedClass in classes) {
      final key = assignedClass.semester.isEmpty
          ? 'Unassigned Semester'
          : assignedClass.semester;
      grouped.putIfAbsent(key, () => []).add(assignedClass);
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == 'Unassigned Semester') {
          return 1;
        }
        if (b == 'Unassigned Semester') {
          return -1;
        }
        return _compareSemester(a, b);
      });

    return {
      for (final key in sortedKeys) key: grouped[key]!,
    };
  }

  static Set<String> assignedCourseKeys(List<CourseModel> courses) {
    final keys = <String>{};
    for (final course in courses) {
      final code = course.courseCode.trim();
      final id = course.id.trim();
      if (code.isNotEmpty) {
        keys.add(code);
      }
      if (id.isNotEmpty) {
        keys.add(id);
      }
    }
    return keys;
  }

  static Set<String> facultyKeysFor(FacultyModel faculty) {
    return {
      CourseFirestoreService.facultyAssignmentKey(faculty),
      faculty.facultyId.trim(),
      if (faculty.documentId?.trim().isNotEmpty == true)
        faculty.documentId!.trim(),
    }..removeWhere((key) => key.isEmpty);
  }

  static bool blockMatchesFaculty({
    required TimeBlockRecord block,
    required Set<String> courseKeys,
    required Set<String> facultyKeys,
  }) {
    final courseId = block.courseId.trim();
    if (courseId.isNotEmpty && courseKeys.contains(courseId)) {
      return true;
    }

    final facultyUid = block.facultyUid.trim();
    if (facultyUid.isNotEmpty && facultyKeys.contains(facultyUid)) {
      return true;
    }

    return false;
  }

  static bool isBreakBlock(TimeBlockRecord block) {
    final courseId = block.courseId.trim().toUpperCase();
    final courseName = block.courseName.trim().toUpperCase();
    return breakLabels.contains(courseId) || breakLabels.contains(courseName);
  }

  static int _compareSemester(String a, String b) {
    final aNum = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), ''));
    final bNum = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), ''));
    if (aNum != null && bNum != null && aNum != bNum) {
      return aNum.compareTo(bNum);
    }
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  static int _dayOrderForClass({
    required FacultyAssignedClass assignedClass,
    required Map<String, int> dayOrderByUid,
    required Map<String, int> dayOrderByName,
  }) {
    final uid = assignedClass.dayUid;
    if (uid.isNotEmpty && dayOrderByUid.containsKey(uid)) {
      return dayOrderByUid[uid]!;
    }
    final name = assignedClass.dayName.toLowerCase();
    if (name.isNotEmpty && dayOrderByName.containsKey(name)) {
      return dayOrderByName[name]!;
    }
    return 999;
  }

  static int _slotOrderForClass({
    required FacultyAssignedClass assignedClass,
    required Map<String, int> slotOrderByUid,
    required Map<String, int> slotOrderByName,
  }) {
    final uid = assignedClass.timeSlotUid;
    if (uid.isNotEmpty && slotOrderByUid.containsKey(uid)) {
      return slotOrderByUid[uid]!;
    }
    final name = assignedClass.timeSlotName.toLowerCase();
    if (name.isNotEmpty && slotOrderByName.containsKey(name)) {
      return slotOrderByName[name]!;
    }
    return 999;
  }
}
