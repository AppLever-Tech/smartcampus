import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/semester_performance_model.dart';

class SemesterPerformanceFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<SemesterPerformanceModel>> getSemesterPerformanceForStudent(String uuid) {
    return _firestore
        .collection('smcSemesterPerformance')
        .where('uuid', isEqualTo: uuid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return SemesterPerformanceModel.fromFirestore(doc.id, doc.data());
      }).toList();
      
      list.sort((a, b) => a.semester.compareTo(b.semester));
      return list;
    });
  }

  Future<void> addSemesterPerformance(SemesterPerformanceModel record) async {
    await _firestore.collection('smcSemesterPerformance').add(record.toMap());
  }

  Future<void> updateSemesterPerformance(String id, SemesterPerformanceModel record) async {
    await _firestore.collection('smcSemesterPerformance').doc(id).update(record.toMap());
  }
}
