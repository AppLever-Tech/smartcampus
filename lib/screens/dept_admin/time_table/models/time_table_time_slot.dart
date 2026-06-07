class TimeTableTimeSlot {
  final int timeslotOrder;
  final String timeslotName;
  final String timeslotStartTime;
  final String timeslotEndTime;
  final String timeslotUid;

  const TimeTableTimeSlot({
    required this.timeslotOrder,
    required this.timeslotName,
    required this.timeslotStartTime,
    required this.timeslotEndTime,
    required this.timeslotUid,
  });

  factory TimeTableTimeSlot.fromMap(Map<String, dynamic> data) {
    return TimeTableTimeSlot(
      timeslotOrder: (data['timeslot_order'] as num?)?.toInt() ?? 0,
      timeslotName: (data['timeslot_name'] ?? '').toString(),
      timeslotStartTime: (data['timeslot_start_time'] ?? '').toString(),
      timeslotEndTime: (data['timeslot_end_time'] ?? '').toString(),
      timeslotUid: (data['timeslot_uid'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timeslot_order': timeslotOrder,
      'timeslot_name': timeslotName,
      'timeslot_start_time': timeslotStartTime,
      'timeslot_end_time': timeslotEndTime,
      'timeslot_uid': timeslotUid,
    };
  }
}
