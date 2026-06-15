import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_date_utils.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/completed_class_record.dart';
import 'package:smartcampus/screens/student/student_class_management/student_class_firestore_service.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class StudentClassDetailDialog extends StatelessWidget {
  final String courseName;
  final String courseId;
  final String? dayName;
  final String? timing;
  final String batch;
  final String section;
  final String semester;
  final String? facultyName;
  final DateTime classDate;
  final StudentModel student;
  final CompletedClassRecord? classRecord;

  const StudentClassDetailDialog({
    super.key,
    required this.courseName,
    required this.courseId,
    this.dayName,
    this.timing,
    this.batch = '',
    this.section = '',
    this.semester = '',
    this.facultyName,
    required this.classDate,
    required this.student,
    this.classRecord,
  });

  static Future<void> show({
    required BuildContext context,
    required String courseName,
    required String courseId,
    String? dayName,
    String? timing,
    String batch = '',
    String section = '',
    String semester = '',
    String? facultyName,
    required DateTime classDate,
    required StudentModel student,
    CompletedClassRecord? classRecord,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: StudentClassDetailDialog(
            courseName: courseName,
            courseId: courseId,
            dayName: dayName,
            timing: timing,
            batch: batch,
            section: section,
            semester: semester,
            facultyName: facultyName,
            classDate: classDate,
            student: student,
            classRecord: classRecord,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = courseName.trim().isNotEmpty ? courseName.trim() : courseId;
    final attendance = classRecord == null
        ? null
        : StudentClassFirestoreService.attendanceStatusForStudent(
            record: classRecord!,
            student: student,
          );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: smcText(
                  textToDisplay: title,
                  textSize: 18,
                  textBoldness: 5,
                  colorOfText: ColorConst.textPrimary,
                  maxLines: 2,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: ColorConst.textSecondary,
              ),
            ],
          ),
          if (courseId.trim().isNotEmpty && courseName.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            smcText(
              textToDisplay: courseId.trim(),
              textSize: 13,
              colorOfText: ColorConst.textSecondary,
            ),
          ],
          const SizedBox(height: 16),
          _detailRow(
            'Date',
            FacultyClassDateUtils.formatCompletedDate(classDate),
          ),
          if (dayName?.trim().isNotEmpty ?? false)
            _detailRow('Day', dayName!.trim()),
          if (timing?.trim().isNotEmpty ?? false)
            _detailRow('Timing', timing!.trim()),
          if (facultyName?.trim().isNotEmpty ?? false)
            _detailRow('Faculty', facultyName!.trim()),
          if (batch.trim().isNotEmpty) _detailRow('Batch', batch.trim()),
          if (section.trim().isNotEmpty) _detailRow('Section', section.trim()),
          if (semester.trim().isNotEmpty)
            _detailRow('Semester', semester.trim()),
          if (classRecord != null) ...[
            const SizedBox(height: 12),
            _attendanceBadge(attendance),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: smcText(
              textToDisplay: label,
              textSize: 13,
              textBoldness: 4,
              colorOfText: ColorConst.textSecondary,
            ),
          ),
          Expanded(
            child: smcText(
              textToDisplay: value,
              textSize: 13,
              colorOfText: ColorConst.textPrimary,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _attendanceBadge(String? attendance) {
    late final String label;
    late final Color background;
    late final Color foreground;

    if (attendance == null) {
      label = 'Attendance not marked';
      background = const Color(0xFFF4F7FF);
      foreground = ColorConst.textSecondary;
    } else if (attendance == 'Present') {
      label = 'Present';
      background = const Color(0xFFE8F5E9);
      foreground = const Color(0xFF2E7D32);
    } else {
      label = 'Absent';
      background = const Color(0xFFFFEBEE);
      foreground = const Color(0xFFC62828);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: smcText(
        textToDisplay: 'Your attendance: $label',
        textSize: 13,
        textBoldness: 4,
        colorOfText: foreground,
      ),
    );
  }
}
