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
  final String dayUid;
  final String timeSlotName;
  final String timeSlotUid;
  final String timeTableUid;
  final String timeBlockUid;
  final String batch;
  final String section;
  final String semester;
  final String status;
  final Map<String, bool> attendance;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const CompletedClassRecord({
    this.id = '',
    required this.orgId,
    required this.facultyUid,
    required this.facultyName,
    required this.classDate,
    required this.courseId,
    required this.courseName,
    required this.dayName,
    this.dayUid = '',
    required this.timeSlotName,
    this.timeSlotUid = '',
    required this.timeTableUid,
    this.timeBlockUid = '',
    required this.batch,
    required this.section,
    this.semester = '',
    this.status = 'completed',
    this.attendance = const {},
    this.startedAt,
    this.completedAt,
  });

  bool get isActive => status.trim().toLowerCase() == 'active';

  bool get isCompleted => status.trim().toLowerCase() == 'completed';

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
      dayUid: _readString(data, ['day_uid', 'Day_UID']),
      timeSlotName: _readString(data, ['time_slot_name', 'Time_Slot_Name']),
      timeSlotUid: _readString(data, ['time_slot_uid', 'Time_Slot_UID']),
      timeTableUid: _readString(data, ['time_table_uid']),
      timeBlockUid: _readString(data, ['time_block_uid']),
      batch: _readString(data, ['batch', 'Batch']),
      section: _readString(data, ['section', 'Section']),
      semester: _readString(data, ['semester']),
      status: _readString(data, ['status'], fallback: 'completed'),
      attendance: _readAttendance(data['attendance']),
      startedAt: _readOptionalDate(data['started_at']),
      completedAt: _readOptionalDate(data['completed_at']),
    );
  }

  static String sessionKey({
    required DateTime classDate,
    required String timeBlockUid,
    required String timeTableUid,
    required String courseId,
    required String batch,
    required String section,
    required String semester,
    required String dayUid,
    required String dayName,
    required String timeSlotUid,
    required String timeSlotName,
  }) {
    final blockUid = timeBlockUid.trim();
    if (blockUid.isNotEmpty) {
      return '${FacultyClassDateUtils.dateOnly(classDate).toIso8601String()}|$blockUid';
    }

    final parts = [
      FacultyClassDateUtils.dateOnly(classDate).toIso8601String(),
      timeTableUid.trim(),
      courseId.trim(),
      batch.trim(),
      section.trim(),
      semester.trim(),
      dayUid.trim().isNotEmpty ? dayUid.trim() : dayName.trim().toLowerCase(),
      timeSlotUid.trim().isNotEmpty
          ? timeSlotUid.trim()
          : timeSlotName.trim().toLowerCase(),
    ];
    return parts.join('|');
  }

  String get sessionKeyValue => sessionKey(
        classDate: classDate,
        timeBlockUid: timeBlockUid,
        timeTableUid: timeTableUid,
        courseId: courseId,
        batch: batch,
        section: section,
        semester: semester,
        dayUid: dayUid,
        dayName: dayName,
        timeSlotUid: timeSlotUid,
        timeSlotName: timeSlotName,
      );

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

  static DateTime? _readOptionalDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  static Map<String, bool> _readAttendance(dynamic value) {
    if (value is! Map) {
      return const {};
    }

    final attendance = <String, bool>{};
    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty) {
        continue;
      }
      attendance[key] = entry.value == true;
    }
    return attendance;
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
