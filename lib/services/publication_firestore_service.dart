import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../models/publication_model.dart';

class PublicationFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<PublicationModel>> getPublicationsForStudent(String uuid) {
    return _firestore
        .collection('smcPublications')
        .where('uuid', isEqualTo: uuid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return PublicationModel.fromFirestore(doc.id, doc.data());
      }).toList();
      
      // Sort client-side to avoid index requirements
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Stream<List<PublicationModel>> getAllPublications() {
    return _firestore
        .collection('smcPublications')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return PublicationModel.fromFirestore(doc.id, doc.data());
      }).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Future<void> addPublication(PublicationModel publication) async {
    await _firestore.collection('smcPublications').add(publication.toMap());
  }

  Future<void> updatePublication(String id, PublicationModel publication) async {
    await _firestore.collection('smcPublications').doc(id).update(publication.toMap());
  }

  Future<void> deletePublication(String id, String? pdfUrl) async {
    await _firestore.collection('smcPublications').doc(id).delete();
    if (pdfUrl != null && pdfUrl.isNotEmpty) {
      try {
        await _storage.refFromURL(pdfUrl).delete();
      } catch (e) {
        // Log or ignore
      }
    }
  }

  Future<String> uploadPublicationPdf(String uuid, String fileName, Uint8List fileBytes) async {
    final ref = _storage
        .ref()
        .child('student_publications')
        .child(uuid)
        .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');
    
    final uploadTask = await ref.putData(fileBytes, SettableMetadata(contentType: 'application/pdf'));
    return await uploadTask.ref.getDownloadURL();
  }
}
