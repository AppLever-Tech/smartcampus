import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartcampus/data/org_field.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_date_utils.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/completed_class_record.dart';

class ClassAttendanceFirestoreService {
  static const String collection = 'smcClasses';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<CompletedClassRecord>> watchClassesForOrg({
    required String orgId,
  }) {
    final orgNorm = OrgField.normalize(orgId);
    if (orgNorm.isEmpty) {
      return Stream.value(const <CompletedClassRecord>[]);
    }

    return _firestore
        .collection(collection)
        .where(OrgField.orgIdKey, isEqualTo: orgNorm)
        .snapshots()
        .map((snapshot) {
      final records = snapshot.docs
          .map(
            (doc) => CompletedClassRecord.fromFirestore(doc.id, doc.data()),
          )
          .toList();
      records.sort((a, b) {
        final dateCompare = b.classDate.compareTo(a.classDate);
        if (dateCompare != 0) {
          return dateCompare;
        }
        final startedA = a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final startedB = b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return startedB.compareTo(startedA);
      });
      return records;
    });
  }

  Future<CompletedClassRecord?> findActiveClassForSession({
    required String orgId,
    required String facultyUid,
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
  }) async {
    final orgNorm = OrgField.normalize(orgId);
    if (orgNorm.isEmpty) {
      return null;
    }

    final sessionKey = CompletedClassRecord.sessionKey(
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

    final snapshot = await _firestore
        .collection(collection)
        .where(OrgField.orgIdKey, isEqualTo: orgNorm)
        .where('faculty_uid', isEqualTo: facultyUid.trim())
        .where(
          'class_date',
          isEqualTo: Timestamp.fromDate(
            FacultyClassDateUtils.dateOnly(classDate),
          ),
        )
        .where('status', isEqualTo: 'active')
        .get();

    for (final doc in snapshot.docs) {
      final record = CompletedClassRecord.fromFirestore(doc.id, doc.data());
      if (record.sessionKeyValue == sessionKey) {
        return record;
      }
    }
    return null;
  }

  Future<String> startClass({
    required String orgId,
    required String facultyUid,
    required String facultyName,
    required DateTime classDate,
    required String courseId,
    required String courseName,
    required String dayName,
    required String dayUid,
    required String timeSlotName,
    required String timeSlotUid,
    required String timeTableUid,
    required String timeBlockUid,
    required String batch,
    required String section,
    required String semester,
  }) async {
    final orgNorm = OrgField.normalize(orgId);
    if (orgNorm.isEmpty) {
      throw Exception('Organisation is required to start a class.');
    }

    final existing = await findActiveClassForSession(
      orgId: orgId,
      facultyUid: facultyUid,
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
    if (existing != null) {
      return existing.id;
    }

    final docRef = await _firestore.collection(collection).add({
      ...OrgField.orgIdWrite(orgNorm),
      'faculty_uid': facultyUid.trim(),
      'faculty_name': facultyName.trim(),
      'class_date': Timestamp.fromDate(
        FacultyClassDateUtils.dateOnly(classDate),
      ),
      'course_id': courseId.trim(),
      'course_name': courseName.trim(),
      'day_name': dayName.trim(),
      'day_uid': dayUid.trim(),
      'time_slot_name': timeSlotName.trim(),
      'time_slot_uid': timeSlotUid.trim(),
      'time_table_uid': timeTableUid.trim(),
      'time_block_uid': timeBlockUid.trim(),
      'batch': batch.trim(),
      'section': section.trim(),
      'semester': semester.trim(),
      'status': 'active',
      'attendance': <String, bool>{},
      'started_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> saveAttendance({
    required String recordId,
    required Map<String, bool> attendanceByStudentKey,
  }) async {
    final recordRef = _firestore.collection(collection).doc(recordId.trim());
    if (recordId.trim().isEmpty) {
      throw Exception('Class record is required to save attendance.');
    }

    final attendance = <String, bool>{};
    for (final entry in attendanceByStudentKey.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) {
        continue;
      }
      attendance[key] = entry.value;
    }

    await recordRef.update({
      'attendance': attendance,
      'status': 'completed',
      'completed_at': FieldValue.serverTimestamp(),
    });
  }
}
