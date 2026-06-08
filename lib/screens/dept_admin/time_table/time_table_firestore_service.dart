import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartcampus/data/org_field.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_record.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_uid.dart';

class TimeTableFirestoreService {
  static const String collection = 'smcTimeTables';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<TimeTableRecord>> watchTimeTables({
    required String orgId,
  }) {
    final orgNorm = OrgField.normalize(orgId);
    if (orgNorm.isEmpty) {
      return Stream.value(const <TimeTableRecord>[]);
    }

    return _firestore
        .collection(collection)
        .where(OrgField.orgIdKey, isEqualTo: orgNorm)
        .snapshots()
        .map((snapshot) {
      final records = snapshot.docs
          .map(
            (doc) => TimeTableRecord.fromFirestore(doc.id, doc.data()),
          )
          .toList();
      records.sort((a, b) {
        final batchCompare = a.batch.compareTo(b.batch);
        if (batchCompare != 0) {
          return batchCompare;
        }
        final schemeCompare = a.scheme.compareTo(b.scheme);
        if (schemeCompare != 0) {
          return schemeCompare;
        }
        return a.section.compareTo(b.section);
      });
      return records;
    });
  }

  Future<void> createTimeTable({
    required String orgId,
    required String section,
    required String sectionUid,
    required String batch,
    required String scheme,
  }) async {
    final record = TimeTableRecord(
      id: '',
      timeTableUid: generateTimeTableUid(),
      orgId: orgId,
      section: section,
      sectionUid: sectionUid,
      batch: batch,
      scheme: scheme,
    );
    await _firestore.collection(collection).add(record.toMap());
  }
}
