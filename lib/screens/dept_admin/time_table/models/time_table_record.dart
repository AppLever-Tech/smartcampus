import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartcampus/data/org_field.dart';

class TimeTableRecord {
  final String id;
  final String timeTableUid;
  final String orgId;
  final String section;
  final String sectionUid;
  final String batch;
  final String scheme;
  final String semester;

  const TimeTableRecord({
    required this.id,
    required this.timeTableUid,
    required this.orgId,
    required this.section,
    required this.sectionUid,
    required this.batch,
    required this.scheme,
    this.semester = '',
  });

  factory TimeTableRecord.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return TimeTableRecord(
      id: id,
      timeTableUid: (data['time_table_uid'] ?? '').toString(),
      orgId: OrgField.readOrgId(data),
      section: (data['section'] ?? '').toString(),
      sectionUid: (data['section_uid'] ?? '').toString(),
      batch: (data['batch'] ?? '').toString(),
      scheme: (data['scheme'] ?? '').toString(),
      semester: (data['semester'] ?? '').toString(),
    );
  }

  String get displayLabel {
    return [
      scheme,
      batch,
      if (semester.trim().isNotEmpty) 'Sem: $semester',
      section,
    ].where((value) => value.trim().isNotEmpty).join(' - ');
  }

  Map<String, dynamic> toMap() {
    return {
      'time_table_uid': timeTableUid,
      OrgField.orgIdKey: OrgField.normalize(orgId),
      'section': section,
      'section_uid': sectionUid,
      'batch': batch,
      'scheme': scheme,
      'semester': semester,
      'created_at': FieldValue.serverTimestamp(),
    };
  }
}
