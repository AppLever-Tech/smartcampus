class AchievementModel {
  final String? id;
  final String uuid; // USN or Document ID from smcUserMaster
  final String title;
  final String category; // Academic, Technical, Sports, Cultural, Certification, Other
  final String level; // College, State, National, International
  final String organization;
  final String date; // ISO format or YYYY-MM-DD
  final String description;
  final String? certificateUrl;
  final String? certificateFileName;
  final DateTime createdOn;

  AchievementModel({
    this.id,
    required this.uuid,
    required this.title,
    required this.category,
    required this.level,
    required this.organization,
    required this.date,
    required this.description,
    this.certificateUrl,
    this.certificateFileName,
    required this.createdOn,
  });

  factory AchievementModel.fromFirestore(String id, Map<String, dynamic> data) {
    return AchievementModel(
      id: id,
      uuid: data['uuid'] ?? '',
      title: data['title'] ?? '',
      category: data['category'] ?? '',
      level: data['level'] ?? '',
      organization: data['organization'] ?? '',
      date: data['date'] ?? '',
      description: data['description'] ?? '',
      certificateUrl: data['certificateUrl'],
      certificateFileName: data['certificateFileName'],
      createdOn: data['createdOn'] != null 
          ? DateTime.parse(data['createdOn']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'title': title,
      'category': category,
      'level': level,
      'organization': organization,
      'date': date,
      'description': description,
      'certificateUrl': certificateUrl,
      'certificateFileName': certificateFileName,
      'createdOn': createdOn.toIso8601String(),
    };
  }
}
