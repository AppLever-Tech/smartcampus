import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_time_slot.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_card.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/completed_class_record.dart';
import 'package:smartcampus/screens/student/student_class_management/student_class_detail_dialog.dart';
import 'package:smartcampus/screens/student/student_class_management/student_class_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class StudentActiveTab extends StatelessWidget {
  final StudentModel student;
  final List<CourseModel> enrolledCourses;
  final List<CompletedClassRecord> classRecords;
  final List<TimeTableTimeSlot> timeSlots;

  const StudentActiveTab({
    super.key,
    required this.student,
    required this.enrolledCourses,
    required this.classRecords,
    this.timeSlots = const [],
  });

  @override
  Widget build(BuildContext context) {
    final active = StudentClassFirestoreService.filterActiveForStudent(
      records: classRecords,
      student: student,
      enrolledCourses: enrolledCourses,
    );

    if (active.isEmpty) {
      return const FacultyClassesEmptyState(
        title: 'No active classes',
        message: 'Classes in progress for your batch and semester appear here.',
        icon: Icons.play_circle_outline_rounded,
      );
    }

    return ListView(
      children: [
        for (final record in active) ...[
          const smcText(
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
                studentsActionLabel: 'Info',
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
                onStudentsTap: () => StudentClassDetailDialog.show(
                  context: cardContext,
                  courseName: record.courseName,
                  courseId: record.courseId,
                  dayName: record.dayName,
                  timing: timing,
                  batch: record.batch,
                  section: record.section,
                  semester: record.semester,
                  facultyName: record.facultyName,
                  classDate: record.classDate,
                  student: student,
                  classRecord: record,
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
