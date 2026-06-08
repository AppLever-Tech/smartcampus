import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/data/org_field.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_date_utils.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_resolver.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/completed_class_record.dart';

class CompletedClassFirestoreService {
  static const String collection = 'smcClasses';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<CompletedClassRecord>> watchCompletedClassesForOrg({
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
      records.sort((a, b) => b.classDate.compareTo(a.classDate));
      return records;
    });
  }

  static List<CompletedClassRecord> filterForFaculty({
    required List<CompletedClassRecord> records,
    required FacultyModel faculty,
    DateTime? referenceDate,
  }) {
    final facultyKeys = FacultyClassResolver.facultyKeysFor(faculty);
    final today = FacultyClassDateUtils.dateOnly(referenceDate ?? DateTime.now());

    return records.where((record) {
      if (!facultyKeys.contains(record.facultyUid.trim())) {
        return false;
      }
      return record.classDate.isBefore(today);
    }).toList();
  }
}
