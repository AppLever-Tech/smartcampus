class CourseModel {
  final String id;
  final String batch;
  final String semester;
  final String courseTitle;
  final String faculty;
  final String courseCode;
  final String credits;
  final String courseType;
  final String syllabus;

  CourseModel({
    required this.id,
    required this.batch,
    required this.semester,
    required this.courseTitle,
    required this.faculty,
    required this.courseCode,
    required this.credits,
    required this.courseType,
    required this.syllabus,
  });

  factory CourseModel.fromFirestore(
      String id,
      Map<String, dynamic> data,
      ) {
    return CourseModel(
      id: id,
      batch: data['batch'] ?? '',
      semester: data['semester'] ?? '',
      courseTitle: data['courseTitle'] ?? '',
      faculty: data['faculty'] ?? '',
      courseCode: data['courseCode'] ?? '',
      credits: data['credits'] ?? '',
      courseType: data['courseType'] ?? '',
      syllabus: data['syllabus'] ?? '',
    );
  }


  Map<String, dynamic> toMap() {
    return {
      'batch': batch,
      'semester': semester,
      'courseTitle': courseTitle,
      'faculty': faculty,
      'courseCode': courseCode,
      'credits': credits,
      'courseType': courseType,
      'syllabus': syllabus,
    };
  }
}