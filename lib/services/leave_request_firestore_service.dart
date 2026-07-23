import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:smartcampus/models/leave_request_model.dart';
import 'dart:typed_data';

class LeaveRequestFirestoreService {
  static const String collection = 'smcLeaveRequests';
  static const String storagePath = 'leave_requests';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<LeaveRequestModel>> getLeaveRequestsForStudent({
    required String studentId,
  }) {
    return _firestore
        .collection(collection)
        .where('student_id', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => LeaveRequestModel.fromFirestore(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<LeaveRequestModel>> getLeaveRequestsForProctor({
    required String proctorId,
  }) {
    return _firestore
        .collection(collection)
        .where('proctor_id', isEqualTo: proctorId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => LeaveRequestModel.fromFirestore(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<LeaveRequestModel?> getLeaveRequestById(String id) async {
    final doc = await _firestore.collection(collection).doc(id).get();
    if (!doc.exists) return null;
    return LeaveRequestModel.fromFirestore(doc.id, doc.data()!);
  }

  Future<String> createLeaveRequest(LeaveRequestModel request) async {
    final docRef = await _firestore.collection(collection).add(request.toFirestore());
    return docRef.id;
  }

  Future<void> updateLeaveRequest(LeaveRequestModel request) async {
    await _firestore
        .collection(collection)
        .doc(request.id)
        .update(request.toFirestore());
  }

  Future<void> deleteLeaveRequest(String id) async {
    // Delete from storage if there's an attachment
    final doc = await _firestore.collection(collection).doc(id).get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data['attachment_url'] != null && data['attachment_url'].toString().isNotEmpty) {
        try {
          final ref = _storage.refFromURL(data['attachment_url'].toString());
          await ref.delete();
        } catch (e) {
          // Ignore storage errors
        }
      }
    }
    await _firestore.collection(collection).doc(id).delete();
  }

  Future<void> updateLeaveRequestStatus({
    required String id,
    required String status,
  }) async {
    await _firestore.collection(collection).doc(id).update({
      'status': status,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<String> uploadAttachment({
    required String fileName,
    required Uint8List bytes,
    required String studentId,
  }) async {
    final ref = _storage.ref().child('$storagePath/$studentId/${DateTime.now().millisecondsSinceEpoch}_$fileName');
    final uploadTask = ref.putData(bytes);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}
