import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meeting_model.dart';

class MeetingFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<MeetingModel>> getMeetingsForStudent(String uuid) {
    return _firestore
        .collection('smcMeetings')
        .where('uuid', isEqualTo: uuid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return MeetingModel.fromFirestore(doc.id, doc.data());
      }).toList();
      
      // Sort by date descending
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Stream<List<MeetingModel>> getMeetingsForStudents(List<String> uuids) {
    if (uuids.isEmpty) return Stream.value([]);
    // Using snapshots without where clause to handle >10 uuids limit in whereIn
    // Filter on the client side since smcMeetings is typically small enough.
    return _firestore
        .collection('smcMeetings')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => MeetingModel.fromFirestore(doc.id, doc.data()))
          .where((m) => uuids.contains(m.uuid))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Future<void> addMeeting(MeetingModel meeting) async {
    await _firestore.collection('smcMeetings').add(meeting.toMap());
  }

  Future<void> updateMeeting(String id, MeetingModel meeting) async {
    await _firestore.collection('smcMeetings').doc(id).update(meeting.toMap());
  }

  Future<void> deleteMeeting(String id) async {
    await _firestore.collection('smcMeetings').doc(id).delete();
  }
}
