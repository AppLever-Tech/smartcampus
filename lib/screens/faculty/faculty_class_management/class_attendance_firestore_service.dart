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

    // Query by org only and filter in memory so we do not depend on a
    // Firestore composite index for faculty_uid + class_date + status.
    final snapshot = await _firestore
        .collection(collection)
        .where(OrgField.orgIdKey, isEqualTo: orgNorm)
        .get();

    final normalizedFacultyUid = facultyUid.trim();
    final targetDate = FacultyClassDateUtils.dateOnly(classDate);

    for (final doc in snapshot.docs) {
      final record = CompletedClassRecord.fromFirestore(doc.id, doc.data());
      if (!record.isActive) {
        continue;
      }
      if (record.facultyUid.trim() != normalizedFacultyUid) {
        continue;
      }
      if (!FacultyClassDateUtils.isSameDay(record.classDate, targetDate)) {
        continue;
      }
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

    CompletedClassRecord? existing;
    try {
      existing = await findActiveClassForSession(
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
    } catch (_) {
      // Duplicate lookup is best-effort; class creation must still proceed.
    }
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

  Future<CompletedClassRecord?> getClassRecord(String recordId) async {
    final id = recordId.trim();
    if (id.isEmpty) {
      return null;
    }

    final doc = await _firestore.collection(collection).doc(id).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return CompletedClassRecord.fromFirestore(doc.id, doc.data()!);
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
    });
  }

  Future<void> completeClass({required String recordId}) async {
    final recordRef = _firestore.collection(collection).doc(recordId.trim());
    if (recordId.trim().isEmpty) {
      throw Exception('Class record is required to complete a class.');
    }

    await recordRef.update({
      'status': 'completed',
      'completed_at': FieldValue.serverTimestamp(),
    });
  }
}
