import 'dart:typed_data';

import 'package:excel/excel.dart' as excel;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_date_utils.dart';

class FacultyClassAttendanceExport {
  FacultyClassAttendanceExport._();

  static Future<void> exportToExcel({
    required BuildContext context,
    required String courseId,
    required String courseName,
    required DateTime classDate,
    required String batch,
    required String section,
    required String semester,
    String? dayName,
    String? timing,
    required List<StudentModel> students,
    required Map<String, bool> attendanceByStudentKey,
    required String Function(StudentModel student) studentKeyFor,
  }) async {
    final workbook = excel.Excel.createExcel();
    final sheet = workbook['Attendance'];

    sheet.appendRow(['Course', _displayCourse(courseId, courseName)]);
    sheet.appendRow([
      'Class Date',
      FacultyClassDateUtils.formatCompletedDate(classDate),
    ]);
    if (dayName?.trim().isNotEmpty ?? false) {
      sheet.appendRow(['Day', dayName!.trim()]);
    }
    if (timing?.trim().isNotEmpty ?? false) {
      sheet.appendRow(['Timing', timing!.trim()]);
    }
    if (batch.trim().isNotEmpty) {
      sheet.appendRow(['Batch', batch.trim()]);
    }
    if (section.trim().isNotEmpty) {
      sheet.appendRow(['Section', section.trim()]);
    }
    if (semester.trim().isNotEmpty) {
      sheet.appendRow(['Semester', semester.trim()]);
    }
    sheet.appendRow(const []);

    sheet.appendRow([
      'S.No',
      'USN / ID',
      'Name',
      'Email',
      'Mobile',
      'Batch',
      'Gender',
      'Attendance',
    ]);

    final sortedStudents = List<StudentModel>.from(students)
      ..sort(
        (a, b) =>
            a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );

    for (var index = 0; index < sortedStudents.length; index++) {
      final student = sortedStudents[index];
      final key = studentKeyFor(student);
      final attendance = attendanceByStudentKey[key];

      sheet.appendRow([
        '${index + 1}',
        student.studentId,
        student.fullName.trim().isEmpty ? student.studentId : student.fullName,
        student.email,
        student.mobile,
        student.batch,
        student.gender,
        attendance == null
            ? ''
            : (attendance ? 'Present' : 'Absent'),
      ]);
    }

    final bytes = workbook.encode();
    if (bytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate Excel file.')),
        );
      }
      return;
    }

    await FileSaver.instance.saveFile(
      name: _fileName(courseId: courseId, classDate: classDate),
      bytes: Uint8List.fromList(bytes),
      ext: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance exported to Excel.')),
    );
  }

  static String _displayCourse(String courseId, String courseName) {
    final id = courseId.trim();
    final name = courseName.trim();
    if (name.isNotEmpty && id.isNotEmpty) {
      return '$name ($id)';
    }
    return name.isNotEmpty ? name : id;
  }

  static String _fileName({
    required String courseId,
    required DateTime classDate,
  }) {
    final dateLabel = FacultyClassDateUtils.dateOnly(classDate)
        .toIso8601String()
        .split('T')
        .first;
    final safeCourse = courseId.trim().isEmpty
        ? 'class'
        : courseId.trim().replaceAll(RegExp(r'[^\w\-]+'), '_');
    return 'Attendance_${safeCourse}_$dateLabel';
  }
}
