import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../models/academic_record_model.dart';

class AcademicFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<AcademicRecordModel>> getAcademicRecordsForPerson(String uuid) {
    return _firestore
        .collection('smcAcademicRecords')
        .where('uuid', isEqualTo: uuid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return AcademicRecordModel.fromFirestore(doc.id, doc.data());
      }).toList();
      
      // Sort client-side by creation date
      list.sort((a, b) => b.createdOn.compareTo(a.createdOn));
      return list;
    });
  }

  Future<void> addAcademicRecord(AcademicRecordModel record) async {
    await _firestore.collection('smcAcademicRecords').add(record.toMap());
  }

  Future<void> updateAcademicRecord(String id, AcademicRecordModel record) async {
    await _firestore.collection('smcAcademicRecords').doc(id).update(record.toMap());
  }

  Future<void> deleteAcademicRecord(String id, String? fileUrl) async {
    await _firestore.collection('smcAcademicRecords').doc(id).delete();
    if (fileUrl != null && fileUrl.isNotEmpty) {
      try {
        await _storage.refFromURL(fileUrl).delete();
      } catch (e) {
        // Log or ignore
      }
    }
  }

  Future<String> uploadAcademicFile(String uuid, String fileName, Uint8List fileBytes) async {
    final ref = _storage
        .ref()
        .child('academic_records')
        .child(uuid)
        .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');
    
    final uploadTask = await ref.putData(fileBytes);
    return await uploadTask.ref.getDownloadURL();
  }
}
