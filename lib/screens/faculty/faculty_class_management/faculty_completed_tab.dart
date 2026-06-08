import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/completed_class_firestore_service.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_time_slot.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_card.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_date_utils.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/completed_class_record.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class FacultyCompletedTab extends StatelessWidget {
  final String orgId;
  final FacultyModel faculty;
  final List<TimeTableTimeSlot> timeSlots;

  const FacultyCompletedTab({
    super.key,
    required this.orgId,
    required this.faculty,
    this.timeSlots = const [],
  });

  @override
  Widget build(BuildContext context) {
    final service = CompletedClassFirestoreService();

    return StreamBuilder<List<CompletedClassRecord>>(
      stream: service.watchCompletedClassesForOrg(orgId: orgId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final completed = CompletedClassFirestoreService.filterForFaculty(
          records: snapshot.data ?? const [],
          faculty: faculty,
        );

        if (completed.isEmpty) {
          return const FacultyClassesEmptyState(
            title: 'No completed classes',
            message:
                'Past classes recorded in smcClasses will appear here once completed.',
            icon: Icons.history_rounded,
          );
        }

        return ListView(
          children: [
            for (final record in completed) ...[
              smcText(
                textToDisplay:
                    FacultyClassDateUtils.formatCompletedDate(record.classDate),
                textSize: 13,
                textBoldness: 4,
                colorOfText: ColorConst.textSecondary,
              ),
              const SizedBox(height: 8),
              FacultyClassCard(
                title: record.courseName.isNotEmpty
                    ? record.courseName
                    : record.courseId,
                courseCode: record.courseId.isNotEmpty &&
                        record.courseName.isNotEmpty
                    ? record.courseId
                    : null,
                dayName: record.dayName,
                timing: FacultyClassCard.resolveTimingLabel(
                  timeSlotUid: '',
                  timeSlotName: record.timeSlotName,
                  timeSlots: timeSlots,
                ),
                batch: record.batch,
                section: record.section,
                semester: record.semester,
                icon: Icons.check_circle_outline_rounded,
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}
