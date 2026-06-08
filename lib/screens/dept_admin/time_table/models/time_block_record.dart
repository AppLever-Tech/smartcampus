import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartcampus/data/org_field.dart';

class TimeBlockRecord {
  final String id;
  final String orgId;
  final String timeTableUid;
  final String dayName;
  final String dayUid;
  final String timeSlotName;
  final String timeSlotUid;
  final String batch;
  final String section;
  final String courseId;
  final String courseName;
  final String facultyName;
  final String facultyUid;
  final DateTime? createdAt;

  const TimeBlockRecord({
    this.id = '',
    required this.orgId,
    required this.timeTableUid,
    required this.dayName,
    required this.dayUid,
    required this.timeSlotName,
    required this.timeSlotUid,
    required this.batch,
    required this.section,
    required this.courseId,
    required this.courseName,
    required this.facultyName,
    required this.facultyUid,
    this.createdAt,
  });

  factory TimeBlockRecord.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final createdAtRaw = data['created_at'];
    DateTime? createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    }

    return TimeBlockRecord(
      id: id,
      orgId: OrgField.readOrgId(data),
      timeTableUid: (data['time_table_uid'] ?? '').toString(),
      dayName: (data['Day_Name'] ?? '').toString(),
      dayUid: (data['Day_UID'] ?? '').toString(),
      timeSlotName: (data['Time_Slot_Name'] ?? '').toString(),
      timeSlotUid: (data['Time_Slot_UID'] ?? '').toString(),
      batch: (data['Batch'] ?? '').toString(),
      section: (data['Section'] ?? '').toString(),
      courseId: (data['Course_ID'] ?? '').toString(),
      courseName: (data['Course_Name'] ?? '').toString(),
      facultyName: (data['Faculty_Name'] ?? '').toString(),
      facultyUid: (data['Faculty_UID'] ?? '').toString(),
      createdAt: createdAt,
    );
  }

  String get cellKey => '$dayUid|$timeSlotUid';

  Map<String, dynamic> toMap() {
    return {
      'Day_Name': dayName,
      'Day_UID': dayUid,
      'Time_Slot_Name': timeSlotName,
      'Time_Slot_UID': timeSlotUid,
      'Batch': batch,
      'Section': section,
      'Course_ID': courseId,
      'Course_Name': courseName,
      'Faculty_Name': facultyName,
      'Faculty_UID': facultyUid,
      OrgField.orgIdKey: OrgField.normalize(orgId),
      'time_table_uid': timeTableUid,
      'created_at': FieldValue.serverTimestamp(),
    };
  }
}
