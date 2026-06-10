import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_time_slot.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/completed_class_firestore_service.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_card.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_students_page.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/completed_class_record.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class FacultyActiveTab extends StatelessWidget {
  final String orgId;
  final FacultyModel faculty;
  final List<CourseModel> assignedCourses;
  final List<CompletedClassRecord> classRecords;
  final List<TimeTableTimeSlot> timeSlots;

  const FacultyActiveTab({
    super.key,
    required this.orgId,
    required this.faculty,
    required this.assignedCourses,
    required this.classRecords,
    this.timeSlots = const [],
  });

  @override
  Widget build(BuildContext context) {
    final active = CompletedClassFirestoreService.filterActiveForFaculty(
      records: classRecords,
      faculty: faculty,
    );

    if (active.isEmpty) {
      return const FacultyClassesEmptyState(
        title: 'No active classes',
        message:
            'Classes you start today will appear here until you complete them.',
        icon: Icons.play_circle_outline_rounded,
      );
    }

    return ListView(
      children: [
        for (final record in active) ...[
          smcText(
            textToDisplay: 'In progress',
            textSize: 13,
            textBoldness: 4,
            colorOfText: ColorConst.textSecondary,
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (cardContext) {
              final timing = FacultyClassCard.resolveTimingLabel(
                timeSlotUid: record.timeSlotUid,
                timeSlotName: record.timeSlotName,
                timeSlots: timeSlots,
              );

              return FacultyClassCard(
                title: record.courseName.isNotEmpty
                    ? record.courseName
                    : record.courseId,
                courseCode: record.courseId.isNotEmpty &&
                        record.courseName.isNotEmpty
                    ? record.courseId
                    : null,
                dayName: record.dayName,
                timing: timing,
                batch: record.batch,
                section: record.section,
                semester: record.semester,
                icon: Icons.play_circle_outline_rounded,
                onStudentsTap: () => FacultyClassStudentsPage.open(
                  context: cardContext,
                  orgId: orgId,
                  faculty: faculty,
                  assignedCourses: assignedCourses,
                  courseId: record.courseId,
                  courseName: record.courseName,
                  batch: record.batch,
                  section: record.section,
                  semester: record.semester,
                  dayName: record.dayName,
                  timing: timing,
                  timeSlotName: record.timeSlotName,
                  timeSlotUid: record.timeSlotUid,
                  timeTableUid: record.timeTableUid,
                  timeBlockUid: record.timeBlockUid,
                  dayUid: record.dayUid,
                  classDate: record.classDate,
                  activeClassRecordId: record.id,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
