import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_block_record.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_day.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_resolver.dart';

class FacultyUpcomingClasses {
  static int countForNextFiveDays({
    required List<TimeBlockRecord> timeBlocks,
    required List<CourseModel> assignedCourses,
    required FacultyModel faculty,
    required List<TimeTableDay> timetableDays,
    DateTime? referenceDate,
  }) {
    if (assignedCourses.isEmpty || timeBlocks.isEmpty) {
      return 0;
    }

    final courseKeys = FacultyClassResolver.assignedCourseKeys(assignedCourses);
    final facultyKeys = FacultyClassResolver.facultyKeysFor(faculty);
    final dayUidToName = {
      for (final day in timetableDays)
        if (day.dayUid.trim().isNotEmpty) day.dayUid.trim(): day.dayName.trim(),
    };
    final targetWeekdays =
        _nextFiveWeekdaysExcludingSunday(referenceDate ?? DateTime.now());

    var count = 0;
    for (final block in timeBlocks) {
      if (FacultyClassResolver.isBreakBlock(block)) {
        continue;
      }
      if (!FacultyClassResolver.blockMatchesFaculty(
        block: block,
        courseKeys: courseKeys,
        facultyKeys: facultyKeys,
      )) {
        continue;
      }

      final dayName = _resolveDayName(block, dayUidToName);
      final weekday = _weekdayFromDayName(dayName);
      if (weekday != null && targetWeekdays.contains(weekday)) {
        count++;
      }
    }
    return count;
  }

  static String _resolveDayName(
    TimeBlockRecord block,
    Map<String, String> dayUidToName,
  ) {
    final directName = block.dayName.trim();
    if (directName.isNotEmpty) {
      return directName;
    }
    return dayUidToName[block.dayUid.trim()] ?? '';
  }

  static Set<int> _nextFiveWeekdaysExcludingSunday(DateTime from) {
    final weekdays = <int>{};
    var date = DateTime(from.year, from.month, from.day);

    while (weekdays.length < 5) {
      if (date.weekday != DateTime.sunday) {
        weekdays.add(date.weekday);
      }
      date = date.add(const Duration(days: 1));
    }
    return weekdays;
  }

  static int? _weekdayFromDayName(String dayName) {
    final normalized = dayName.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    const weekdayByName = {
      'monday': DateTime.monday,
      'mon': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'tue': DateTime.tuesday,
      'tues': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'wed': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'thu': DateTime.thursday,
      'thur': DateTime.thursday,
      'thurs': DateTime.thursday,
      'friday': DateTime.friday,
      'fri': DateTime.friday,
      'saturday': DateTime.saturday,
      'sat': DateTime.saturday,
    };

    return weekdayByName[normalized];
  }
}
