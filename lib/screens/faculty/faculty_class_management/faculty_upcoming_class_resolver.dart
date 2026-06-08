import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_day.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_time_slot.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_date_utils.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/faculty_assigned_class.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/faculty_scheduled_class.dart';

class FacultyUpcomingClassResolver {
  static Map<DateTime, List<FacultyScheduledClass>> groupByDate({
    required List<FacultyAssignedClass> assignedClasses,
    required List<TimeTableDay> timetableDays,
    List<TimeTableTimeSlot> timeSlots = const [],
    DateTime? referenceDate,
  }) {
    final today = FacultyClassDateUtils.dateOnly(referenceDate ?? DateTime.now());
    final windowDates = FacultyClassDateUtils.upcomingWindowDates(
      referenceDate: today,
    );
    final dayUidToName = {
      for (final day in timetableDays)
        if (day.dayUid.trim().isNotEmpty) day.dayUid.trim(): day.dayName.trim(),
    };
    final slotContext = _TimeSlotSortContext.from(timeSlots);

    final grouped = {
      for (final date in windowDates) date: <FacultyScheduledClass>[],
    };

    for (final assignedClass in assignedClasses) {
      final dayName = FacultyClassDateUtils.resolveDayName(
        dayName: assignedClass.dayName,
        dayUid: assignedClass.dayUid,
        dayUidToName: dayUidToName,
      );
      final weekday = FacultyClassDateUtils.weekdayFromDayName(dayName);
      if (weekday == null) {
        continue;
      }

      for (final date in windowDates) {
        if (date.weekday != weekday) {
          continue;
        }
        grouped[date]!.add(
          FacultyScheduledClass(
            assignedClass: assignedClass,
            scheduledDate: date,
          ),
        );
      }
    }

    for (final entry in grouped.entries) {
      entry.value.sort(
        (a, b) => _compareScheduledClasses(a, b, slotContext),
      );
    }

    return Map.fromEntries(
      grouped.entries.where((entry) => entry.value.isNotEmpty),
    );
  }

  static List<FacultyScheduledClass> flattenUpcoming({
    required List<FacultyAssignedClass> assignedClasses,
    required List<TimeTableDay> timetableDays,
    List<TimeTableTimeSlot> timeSlots = const [],
    DateTime? referenceDate,
  }) {
    final grouped = groupByDate(
      assignedClasses: assignedClasses,
      timetableDays: timetableDays,
      timeSlots: timeSlots,
      referenceDate: referenceDate,
    );
    final today = FacultyClassDateUtils.dateOnly(referenceDate ?? DateTime.now());
    final windowDates = FacultyClassDateUtils.upcomingWindowDates(
      referenceDate: today,
    );

    final flattened = <FacultyScheduledClass>[];
    for (final date in windowDates) {
      final classes = grouped[date];
      if (classes != null) {
        flattened.addAll(classes);
      }
    }
    return flattened;
  }

  static int _compareScheduledClasses(
    FacultyScheduledClass a,
    FacultyScheduledClass b,
    _TimeSlotSortContext slotContext,
  ) {
    final startCompare = slotContext
        .startMinutesFor(a)
        .compareTo(slotContext.startMinutesFor(b));
    if (startCompare != 0) {
      return startCompare;
    }

    final orderCompare =
        slotContext.orderFor(a).compareTo(slotContext.orderFor(b));
    if (orderCompare != 0) {
      return orderCompare;
    }

    final slotNameCompare = a.timeSlotName
        .toLowerCase()
        .compareTo(b.timeSlotName.toLowerCase());
    if (slotNameCompare != 0) {
      return slotNameCompare;
    }

    return a.courseName.toLowerCase().compareTo(b.courseName.toLowerCase());
  }
}

class _TimeSlotSortContext {
  final Map<String, String> startTimeByUid;
  final Map<String, String> startTimeByName;
  final Map<String, int> orderByUid;
  final Map<String, int> orderByName;

  const _TimeSlotSortContext({
    required this.startTimeByUid,
    required this.startTimeByName,
    required this.orderByUid,
    required this.orderByName,
  });

  factory _TimeSlotSortContext.from(List<TimeTableTimeSlot> timeSlots) {
    final startTimeByUid = <String, String>{};
    final startTimeByName = <String, String>{};
    final orderByUid = <String, int>{};
    final orderByName = <String, int>{};

    for (final slot in timeSlots) {
      final uid = slot.timeslotUid.trim();
      final name = slot.timeslotName.trim().toLowerCase();
      if (uid.isNotEmpty) {
        startTimeByUid[uid] = slot.timeslotStartTime;
        orderByUid[uid] = slot.timeslotOrder;
      }
      if (name.isNotEmpty) {
        startTimeByName[name] = slot.timeslotStartTime;
        orderByName[name] = slot.timeslotOrder;
      }
    }

    return _TimeSlotSortContext(
      startTimeByUid: startTimeByUid,
      startTimeByName: startTimeByName,
      orderByUid: orderByUid,
      orderByName: orderByName,
    );
  }

  int startMinutesFor(FacultyScheduledClass scheduledClass) {
    final uid = scheduledClass.assignedClass.timeSlotUid.trim();
    if (uid.isNotEmpty && startTimeByUid.containsKey(uid)) {
      return FacultyClassDateUtils.timeToMinutes(startTimeByUid[uid]!);
    }

    final name = scheduledClass.timeSlotName.trim().toLowerCase();
    if (name.isNotEmpty && startTimeByName.containsKey(name)) {
      return FacultyClassDateUtils.timeToMinutes(startTimeByName[name]!);
    }

    return 9999;
  }

  int orderFor(FacultyScheduledClass scheduledClass) {
    final uid = scheduledClass.assignedClass.timeSlotUid.trim();
    if (uid.isNotEmpty && orderByUid.containsKey(uid)) {
      return orderByUid[uid]!;
    }

    final name = scheduledClass.timeSlotName.trim().toLowerCase();
    if (name.isNotEmpty && orderByName.containsKey(name)) {
      return orderByName[name]!;
    }

    return 9999;
  }
}
