import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:smartcampus/models/co_extra_activity_model.dart';
import 'dart:typed_data';

class CoExtraActivityFirestoreService {
  final CollectionReference _activitiesCollection = FirebaseFirestore.instance.collection('co_extra_activities');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<CoExtraActivityModel>> getActivitiesForStudent(String uuid) {
    return _activitiesCollection
        .where('uuid', isEqualTo: uuid)
        .snapshots()
        .map((snapshot) {
          final activities = snapshot.docs.map((doc) => CoExtraActivityModel.fromFirestore(doc)).toList();
          // Sort locally to avoid needing a Firestore composite index
          activities.sort((a, b) => b.createdOn.compareTo(a.createdOn));
          return activities;
        });
  }

  Future<void> addActivity(CoExtraActivityModel activity) async {
    await _activitiesCollection.add(activity.toMap());
  }

  Future<void> updateActivity(String id, CoExtraActivityModel activity) async {
    await _activitiesCollection.doc(id).update(activity.toMap());
  }

  Future<void> deleteActivity(String id) async {
    await _activitiesCollection.doc(id).delete();
  }

  Future<String> uploadCertificate(String uuid, String fileName, Uint8List fileBytes) async {
    try {
      final ref = _storage.ref().child('co_extra_activities/$uuid/${DateTime.now().millisecondsSinceEpoch}_$fileName');
      final uploadTask = ref.putData(fileBytes);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload certificate: $e');
    }
  }
}
