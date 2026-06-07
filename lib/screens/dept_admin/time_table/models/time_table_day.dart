class TimeTableDay {
  final int dayOrder;
  final String dayName;
  final String dayUid;

  const TimeTableDay({
    required this.dayOrder,
    required this.dayName,
    required this.dayUid,
  });

  factory TimeTableDay.fromMap(Map<String, dynamic> data) {
    return TimeTableDay(
      dayOrder: (data['day_order'] as num?)?.toInt() ?? 0,
      dayName: (data['day_name'] ?? '').toString(),
      dayUid: (data['day_uid'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'day_order': dayOrder,
      'day_name': dayName,
      'day_uid': dayUid,
    };
  }
}
