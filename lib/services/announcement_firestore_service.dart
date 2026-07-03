import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:smartcampus/data/org_field.dart';
import 'package:smartcampus/models/announcement_model.dart';
import 'dart:io';
import 'dart:typed_data';

class AnnouncementFirestoreService {
  static const String collection = 'smcAnnouncements';
  static const String storagePath = 'announcements';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<AnnouncementModel>> getAnnouncementsForDept({
    required String orgId,
    required String deptId,
  }) {
    return _firestore
        .collection(collection)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => AnnouncementModel.fromFirestore(doc.id, doc.data()))
              .toList();
          list.sort((a, b) => b.publishDate.compareTo(a.publishDate));
          return list;
        });
  }

  Future<AnnouncementModel?> getAnnouncementById(String id) async {
    final doc = await _firestore.collection(collection).doc(id).get();
    if (!doc.exists) return null;
    return AnnouncementModel.fromFirestore(doc.id, doc.data()!);
  }

  Future<String> createAnnouncement(AnnouncementModel announcement) async {
    final docRef = await _firestore.collection(collection).add(announcement.toMap());
    return docRef.id;
  }

  Future<void> updateAnnouncement(AnnouncementModel announcement) async {
    await _firestore
        .collection(collection)
        .doc(announcement.id)
        .update(announcement.toMap());
  }

  Future<void> deleteAnnouncement(String id) async {
    // Delete from storage if there's an attachment
    final doc = await _firestore.collection(collection).doc(id).get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data['attachmentUrl'] != null && data['attachmentUrl'].toString().isNotEmpty) {
        try {
          final ref = _storage.refFromURL(data['attachmentUrl'].toString());
          await ref.delete();
        } catch (e) {
          // Ignore storage errors
        }
      }
    }
    await _firestore.collection(collection).doc(id).delete();
  }

  Future<String> uploadAttachment({
    required String fileName,
    required Uint8List bytes,
    required String orgId,
  }) async {
    final ref = _storage.ref().child('$storagePath/$orgId/${DateTime.now().millisecondsSinceEpoch}_$fileName');
    final uploadTask = ref.putData(bytes);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}
