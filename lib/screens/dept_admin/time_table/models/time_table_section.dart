class TimeTableSection {
  final String sectionName;
  final String sectionUid;

  const TimeTableSection({
    required this.sectionName,
    required this.sectionUid,
  });

  factory TimeTableSection.fromMap(Map<String, dynamic> data) {
    return TimeTableSection(
      sectionName: (data['section_name'] ?? '').toString(),
      sectionUid: (data['section_uid'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'section_name': sectionName,
      'section_uid': sectionUid,
    };
  }
}
