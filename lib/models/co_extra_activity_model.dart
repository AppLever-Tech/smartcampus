import 'package:cloud_firestore/cloud_firestore.dart';

class CoExtraActivityModel {
  final String? id;
  final String uuid;
  final String activityName;
  final String type;
  final String level;
  final String date;
  final String achievement;
  final String certificate;
  final DateTime createdOn;

  CoExtraActivityModel({
    this.id,
    required this.uuid,
    required this.activityName,
    required this.type,
    required this.level,
    required this.date,
    required this.achievement,
    required this.certificate,
    required this.createdOn,
  });

  factory CoExtraActivityModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CoExtraActivityModel(
      id: doc.id,
      uuid: data['uuid'] ?? '',
      activityName: data['activityName'] ?? '',
      type: data['type'] ?? '',
      level: data['level'] ?? '',
      date: data['date'] ?? '',
      achievement: data['achievement'] ?? '',
      certificate: data['certificate'] ?? data['credentials'] ?? '', // Fallback for old data
      createdOn: (data['createdOn'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'activityName': activityName,
      'type': type,
      'level': level,
      'date': date,
      'achievement': achievement,
      'certificate': certificate,
      'createdOn': Timestamp.fromDate(createdOn),
    };
  }
}
