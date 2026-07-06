class MeetingModel {
  final String? id;
  final String uuid; // USN or Document ID from smcUserMaster (student's uuid)
  final String date; // ISO format YYYY-MM-DD
  final String time; // Time of meeting (e.g., 10:30 AM)
  final String purpose;
  final String minutes; // Meeting minutes (points discussed)
  final String type; // e.g., 'Academic Review', 'Parent Meeting'
  final String status; // e.g., 'Scheduled', 'Completed'
  final DateTime createdOn;

  MeetingModel({
    this.id,
    required this.uuid,
    required this.date,
    required this.time,
    required this.purpose,
    this.minutes = '',
    this.type = 'Academic Review',
    this.status = 'Scheduled',
    required this.createdOn,
  });

  factory MeetingModel.fromFirestore(String id, Map<String, dynamic> data) {
    return MeetingModel(
      id: id,
      uuid: data['uuid'] ?? '',
      date: data['date'] ?? '',
      time: data['time'] ?? '',
      purpose: data['purpose'] ?? '',
      minutes: data['minutes'] ?? '',
      type: data['type'] ?? 'Academic Review',
      status: data['status'] ?? 'Scheduled',
      createdOn: data['createdOn'] != null 
          ? DateTime.parse(data['createdOn']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'date': date,
      'time': time,
      'purpose': purpose,
      'minutes': minutes,
      'type': type,
      'status': status,
      'createdOn': createdOn.toIso8601String(),
    };
  }
}
