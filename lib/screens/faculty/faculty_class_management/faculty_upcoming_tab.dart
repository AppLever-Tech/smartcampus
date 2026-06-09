import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_day.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_time_slot.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/completed_class_firestore_service.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_card.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_date_utils.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_students_page.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_upcoming_class_resolver.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/completed_class_record.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/faculty_assigned_class.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/faculty_scheduled_class.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class FacultyUpcomingTab extends StatelessWidget {
  final String orgId;
  final FacultyModel faculty;
  final List<FacultyAssignedClass> assignedClasses;
  final List<CourseModel> assignedCourses;
  final List<TimeTableDay> timetableDays;
  final List<TimeTableTimeSlot> timeSlots;
  final List<CompletedClassRecord> classRecords;

  const FacultyUpcomingTab({
    super.key,
    required this.orgId,
    required this.faculty,
    required this.assignedClasses,
    required this.assignedCourses,
    required this.timetableDays,
    required this.timeSlots,
    this.classRecords = const [],
  });

  List<FacultyScheduledClass> _visibleClassesForDate(
    List<FacultyScheduledClass> classes,
    Set<String> activeSessionKeys,
  ) {
    return classes.where((scheduledClass) {
      final sessionKey = CompletedClassRecord.sessionKey(
        classDate: scheduledClass.scheduledDate,
        timeBlockUid: scheduledClass.assignedClass.block.id,
        timeTableUid: scheduledClass.assignedClass.block.timeTableUid,
        courseId: scheduledClass.courseId,
        batch: scheduledClass.assignedClass.batch,
        section: scheduledClass.assignedClass.section,
        semester: scheduledClass.assignedClass.semester,
        dayUid: scheduledClass.assignedClass.dayUid,
        dayName: scheduledClass.dayName,
        timeSlotUid: scheduledClass.assignedClass.timeSlotUid,
        timeSlotName: scheduledClass.timeSlotName,
      );
      return !activeSessionKeys.contains(sessionKey);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final today = FacultyClassDateUtils.dateOnly(DateTime.now());
    final grouped = FacultyUpcomingClassResolver.groupByDate(
      assignedClasses: assignedClasses,
      timetableDays: timetableDays,
      timeSlots: timeSlots,
      referenceDate: today,
    );

    final activeSessionKeys =
        CompletedClassFirestoreService.activeSessionKeysForFaculty(
      records: classRecords,
      faculty: faculty,
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

    final visibleSections = <DateTime, List<FacultyScheduledClass>>{};
    for (final date in windowDates) {
      final classes = grouped[date];
      if (classes == null) {
        continue;
      }
      final visible = _visibleClassesForDate(classes, activeSessionKeys);
      if (visible.isNotEmpty) {
        visibleSections[date] = visible;
      }
    }

    if (visibleSections.isEmpty) {
      return const FacultyClassesEmptyState(
        title: 'No upcoming classes',
        message:
            'All scheduled classes for this window have already been started.',
        icon: Icons.event_available_outlined,
      );
    }

    return ListView(
      children: [
        for (final date in windowDates)
          if (visibleSections.containsKey(date)) ...[
            smcText(
              textToDisplay: FacultyClassDateUtils.formatSectionLabel(
                date,
                today,
                count: visibleSections[date]!.length,
              ),
              textSize: 15,
              textBoldness: 5,
              colorOfText: ColorConst.textPrimary,
            ),
            const SizedBox(height: 10),
            ...visibleSections[date]!.map(
              (scheduledClass) {
                final assignedClass = scheduledClass.assignedClass;
                final classDate = scheduledClass.scheduledDate;
                final showCourseCode = assignedClass.courseId.isNotEmpty &&
                    assignedClass.courseName.isNotEmpty;

                final timing = FacultyClassCard.resolveTimingLabel(
                  timeSlotUid: assignedClass.timeSlotUid,
                  timeSlotName: assignedClass.timeSlotName,
                  timeSlots: timeSlots,
                );

                return FacultyClassCard(
                  title: assignedClass.courseName.isNotEmpty
                      ? assignedClass.courseName
                      : assignedClass.courseId,
                  courseCode:
                      showCourseCode ? assignedClass.courseId : null,
                  dayName: assignedClass.dayName,
                  timing: timing,
                  batch: assignedClass.batch,
                  section: assignedClass.section,
                  semester: assignedClass.semester,
                  onStudentsTap: () => FacultyClassStudentsPage.open(
                    context: context,
                    orgId: orgId,
                    faculty: faculty,
                    assignedCourses: assignedCourses,
                    courseId: assignedClass.courseId,
                    courseName: assignedClass.courseName,
                    batch: assignedClass.batch,
                    section: assignedClass.section,
                    semester: assignedClass.semester,
                    dayName: assignedClass.dayName,
                    timing: timing,
                    timeSlotName: assignedClass.timeSlotName,
                    timeSlotUid: assignedClass.timeSlotUid,
                    timeTableUid: assignedClass.block.timeTableUid,
                    timeBlockUid: assignedClass.block.id,
                    dayUid: assignedClass.dayUid,
                    classDate: classDate,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}
