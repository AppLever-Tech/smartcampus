import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../models/achievement_model.dart';

class AchievementFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<AchievementModel>> getAchievementsForStudent(String uuid) {
    return _firestore
        .collection('smcAchievements')
        .where('uuid', isEqualTo: uuid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return AchievementModel.fromFirestore(doc.id, doc.data());
      }).toList();
      
      // Sort client-side to avoid "missing index" error in Firestore
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Stream<List<AchievementModel>> getAllAchievements() {
    return _firestore
        .collection('smcAchievements')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return AchievementModel.fromFirestore(doc.id, doc.data());
      }).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Future<void> addAchievement(AchievementModel achievement) async {
    await _firestore.collection('smcAchievements').add(achievement.toMap());
  }

  Future<void> updateAchievement(String id, AchievementModel achievement) async {
    await _firestore.collection('smcAchievements').doc(id).update(achievement.toMap());
  }

  Future<void> deleteAchievement(String id, String? certificateUrl) async {
    await _firestore.collection('smcAchievements').doc(id).delete();
    if (certificateUrl != null && certificateUrl.isNotEmpty) {
      try {
        await _storage.refFromURL(certificateUrl).delete();
      } catch (e) {
        // Log or ignore if file already deleted
      }
    }
  }

  Future<String> uploadCertificate(String uuid, String fileName, Uint8List fileBytes) async {
    final ref = _storage
        .ref()
        .child('student_achievements')
        .child(uuid)
        .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');
    
    final uploadTask = await ref.putData(fileBytes);
    return await uploadTask.ref.getDownloadURL();
  }
}
