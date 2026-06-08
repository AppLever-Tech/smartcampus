import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_day.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_time_slot.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_card.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_date_utils.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_upcoming_class_resolver.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/faculty_assigned_class.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class FacultyUpcomingTab extends StatelessWidget {
  final List<FacultyAssignedClass> assignedClasses;
  final List<TimeTableDay> timetableDays;
  final List<TimeTableTimeSlot> timeSlots;

  const FacultyUpcomingTab({
    super.key,
    required this.assignedClasses,
    required this.timetableDays,
    required this.timeSlots,
  });

  @override
  Widget build(BuildContext context) {
    final today = FacultyClassDateUtils.dateOnly(DateTime.now());
    final grouped = FacultyUpcomingClassResolver.groupByDate(
      assignedClasses: assignedClasses,
      timetableDays: timetableDays,
      timeSlots: timeSlots,
      referenceDate: today,
    );

    if (grouped.isEmpty) {
      return FacultyClassesEmptyState(
        title: 'No upcoming classes',
        message:
            'No classes are scheduled for today, tomorrow, or the next three days.',
        icon: Icons.event_available_outlined,
      );
    }

    final windowDates = FacultyClassDateUtils.upcomingWindowDates(
      referenceDate: today,
    );

    return ListView(
      children: [
        for (final date in windowDates)
          if (grouped.containsKey(date)) ...[
            smcText(
              textToDisplay: FacultyClassDateUtils.formatSectionLabel(date, today),
              textSize: 15,
              textBoldness: 5,
              colorOfText: ColorConst.textPrimary,
            ),
            const SizedBox(height: 10),
            ...grouped[date]!.map(
              (scheduledClass) {
                final assignedClass = scheduledClass.assignedClass;
                final showCourseCode = assignedClass.courseId.isNotEmpty &&
                    assignedClass.courseName.isNotEmpty;

                return FacultyClassCard(
                  title: assignedClass.courseName.isNotEmpty
                      ? assignedClass.courseName
                      : assignedClass.courseId,
                  courseCode:
                      showCourseCode ? assignedClass.courseId : null,
                  dayName: assignedClass.dayName,
                  timing: FacultyClassCard.resolveTimingLabel(
                    timeSlotUid: assignedClass.timeSlotUid,
                    timeSlotName: assignedClass.timeSlotName,
                    timeSlots: timeSlots,
                  ),
                  batch: assignedClass.batch,
                  section: assignedClass.section,
                  footer: assignedClass.timeTableLabel,
                );
              },
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}
