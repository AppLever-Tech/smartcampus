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
  final int lectureHrs;
  final int tutorialHrs;
  final int practicalHrs;
  final int othersHrs;
  final int cieMarks;
  final String seeExamDuration;
  final int seeTheoryMarks;
  final int seeLabMarks;
  final int totalMarks;

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
    this.lectureHrs = 0,
    this.tutorialHrs = 0,
    this.practicalHrs = 0,
    this.othersHrs = 0,
    this.cieMarks = 0,
    this.seeExamDuration = '',
    this.seeTheoryMarks = 0,
    this.seeLabMarks = 0,
    this.totalMarks = 0,
  });

  factory CourseModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final int theory = _parseInt(data['seeTheoryMarks']);
    final int lab = _parseInt(data['seeLabMarks']);
    final int cie = _parseInt(data['cieMarks']);
    final int storedTotal = _parseInt(data['totalMarks']);
    final int seeMarks = _parseInt(data['seeMarks'], fallback: theory > 0 ? theory : lab);

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
      lectureHrs: _parseInt(data['lectureHrs']),
      tutorialHrs: _parseInt(data['tutorialHrs']),
      practicalHrs: _parseInt(data['practicalHrs']),
      othersHrs: _parseInt(data['othersHrs']),
      cieMarks: cie,
      seeExamDuration: data['seeExamDuration']?.toString() ?? '',
      seeTheoryMarks: theory,
      seeLabMarks: lab,
      totalMarks: storedTotal > 0 ? storedTotal : cie + seeMarks,
    );
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? fallback;
  }

  /// SEE marks count as either theory or lab (whichever is entered).
  int get seeMarks => seeTheoryMarks > 0 ? seeTheoryMarks : seeLabMarks;

  Map<String, dynamic> toMap() {
    final int computedSee = seeMarks;
    final int computedTotal = totalMarks > 0 ? totalMarks : cieMarks + computedSee;

    return {
      'batch': batch,
      'semester': semester,
      'courseTitle': courseTitle,
      'faculty': faculty,
      'courseCode': courseCode,
      'credits': credits,
      'courseType': courseType,
      'syllabus': syllabus,
      'lectureHrs': lectureHrs,
      'tutorialHrs': tutorialHrs,
      'practicalHrs': practicalHrs,
      'othersHrs': othersHrs,
      'cieMarks': cieMarks,
      'seeExamDuration': seeExamDuration,
      'seeTheoryMarks': seeTheoryMarks,
      'seeLabMarks': seeLabMarks,
      'seeMarks': computedSee,
      'totalMarks': computedTotal,
    };
  }
}
