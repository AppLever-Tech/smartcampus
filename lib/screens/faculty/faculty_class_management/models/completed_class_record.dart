import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartcampus/data/org_field.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_date_utils.dart';

class CompletedClassRecord {
  final String id;
  final String orgId;
  final String facultyUid;
  final String facultyName;
  final DateTime classDate;
  final String courseId;
  final String courseName;
  final String dayName;
  final String timeSlotName;
  final String timeTableUid;
  final String batch;
  final String section;
  final String semester;
  final String status;

  const CompletedClassRecord({
    this.id = '',
    required this.orgId,
    required this.facultyUid,
    required this.facultyName,
    required this.classDate,
    required this.courseId,
    required this.courseName,
    required this.dayName,
    required this.timeSlotName,
    required this.timeTableUid,
    required this.batch,
    required this.section,
    this.semester = '',
    this.status = 'completed',
  });

  factory CompletedClassRecord.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return CompletedClassRecord(
      id: id,
      orgId: OrgField.readOrgId(data),
      facultyUid: _readString(data, ['faculty_uid', 'Faculty_UID']),
      facultyName: _readString(data, ['faculty_name', 'Faculty_Name']),
      classDate: _readDate(data['class_date'] ?? data['classDate']),
      courseId: _readString(data, ['course_id', 'Course_ID']),
      courseName: _readString(data, ['course_name', 'Course_Name']),
      dayName: _readString(data, ['day_name', 'Day_Name']),
      timeSlotName: _readString(data, ['time_slot_name', 'Time_Slot_Name']),
      timeTableUid: _readString(data, ['time_table_uid']),
      batch: _readString(data, ['batch', 'Batch']),
      section: _readString(data, ['section', 'Section']),
      semester: _readString(data, ['semester']),
      status: _readString(data, ['status'], fallback: 'completed'),
    );
  }

  static String _readString(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) {
      return FacultyClassDateUtils.dateOnly(value.toDate());
    }
    if (value is DateTime) {
      return FacultyClassDateUtils.dateOnly(value);
    }
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) {
        return FacultyClassDateUtils.dateOnly(parsed);
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String get subtitle {
    final parts = <String>[
      if (dayName.isNotEmpty) dayName,
      if (timeSlotName.isNotEmpty) timeSlotName,
      if (batch.isNotEmpty) 'Batch $batch',
      if (section.isNotEmpty) 'Sec $section',
    ];
    return parts.join(' · ');
  }
}
