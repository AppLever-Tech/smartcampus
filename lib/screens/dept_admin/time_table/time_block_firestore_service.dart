import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartcampus/data/org_field.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_block_record.dart';

class TimeBlockFirestoreService {
  static const String collection = 'smcTimeBlocks';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createTimeBlock(TimeBlockRecord record) async {
    await _firestore.collection(collection).add(record.toMap());
  }

  Future<void> replaceTimeBlockForCell(TimeBlockRecord record) async {
    final orgNorm = OrgField.normalize(record.orgId);
    final tableUid = record.timeTableUid.trim();
    if (orgNorm.isEmpty || tableUid.isEmpty) {
      await createTimeBlock(record);
      return;
    }

    final snapshot = await _firestore
        .collection(collection)
        .where(OrgField.orgIdKey, isEqualTo: orgNorm)
        .where('time_table_uid', isEqualTo: tableUid)
        .get();

    final cellKey = record.cellKey;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      final existing = TimeBlockRecord.fromFirestore(doc.id, doc.data());
      if (existing.cellKey == cellKey) {
        batch.delete(doc.reference);
      }
    }
    batch.set(_firestore.collection(collection).doc(), record.toMap());
    await batch.commit();
  }

  Future<void> deleteTimeBlock(String id) async {
    final blockId = id.trim();
    if (blockId.isEmpty) {
      return;
    }
    await _firestore.collection(collection).doc(blockId).delete();
  }

  Stream<List<TimeBlockRecord>> watchTimeBlocksForOrg({
    required String orgId,
  }) {
    final orgNorm = OrgField.normalize(orgId);
    if (orgNorm.isEmpty) {
      return Stream.value(const <TimeBlockRecord>[]);
    }

    return _firestore
        .collection(collection)
        .where(OrgField.orgIdKey, isEqualTo: orgNorm)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => TimeBlockRecord.fromFirestore(doc.id, doc.data()),
          )
          .toList();
    });
  }

  Stream<List<TimeBlockRecord>> watchTimeBlocks({
    required String orgId,
    required String timeTableUid,
  }) {
    final orgNorm = OrgField.normalize(orgId);
    final tableUid = timeTableUid.trim();
    if (orgNorm.isEmpty || tableUid.isEmpty) {
      return Stream.value(const <TimeBlockRecord>[]);
    }

    return _firestore
        .collection(collection)
        .where(OrgField.orgIdKey, isEqualTo: orgNorm)
        .where('time_table_uid', isEqualTo: tableUid)
        .snapshots()
        .map((snapshot) {
      final blocks = snapshot.docs
          .map(
            (doc) => TimeBlockRecord.fromFirestore(doc.id, doc.data()),
          )
          .toList();
      blocks.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return blocks;
    });
  }

  static Map<String, TimeBlockRecord> mapBlocksByCell(
    List<TimeBlockRecord> blocks,
  ) {
    final map = <String, TimeBlockRecord>{};
    for (final block in blocks) {
      map[block.cellKey] = block;
    }
    return map;
  }
}
