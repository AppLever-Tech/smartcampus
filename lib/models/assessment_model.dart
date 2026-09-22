import 'package:smartcampus/data/org_field.dart';

class AssessmentSubmissionModel {
  final String id;
  final String assessmentId;
  final String studentId;
  final String studentName;
  final String submittedAt;
  final String fileUrl;
  final String fileName;
  final String fileType; // 'pdf', 'image', etc.
  final String remarks;

  AssessmentSubmissionModel({
    required this.id,
    required this.assessmentId,
    required this.studentId,
    required this.studentName,
    required this.submittedAt,
    this.fileUrl = '',
    this.fileName = '',
    this.fileType = '',
    this.remarks = '',
  });

  factory AssessmentSubmissionModel.fromMap(Map<String, dynamic> data, String documentId) {
    return AssessmentSubmissionModel(
      id: documentId,
      assessmentId: (data['assessment_id'] ?? '').toString().trim(),
      studentId: (data['student_id'] ?? '').toString().trim(),
      studentName: (data['student_name'] ?? '').toString().trim(),
      submittedAt: (data['submitted_at'] ?? '').toString().trim(),
      fileUrl: (data['file_url'] ?? '').toString().trim(),
      fileName: (data['file_name'] ?? '').toString().trim(),
      fileType: (data['file_type'] ?? '').toString().trim(),
      remarks: (data['remarks'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'assessment_id': assessmentId,
      'student_id': studentId,
      'student_name': studentName,
      'submitted_at': submittedAt,
      if (fileUrl.isNotEmpty) 'file_url': fileUrl,
      if (fileName.isNotEmpty) 'file_name': fileName,
      if (fileType.isNotEmpty) 'file_type': fileType,
      if (remarks.isNotEmpty) 'remarks': remarks,
    };
  }
}

class AssessmentMarkEntry {
  final String studentId;
  final String studentName;
  final double? marksObtained;
  final String? remarks;
  final DateTime? submittedOn;

  AssessmentMarkEntry({
    required this.studentId,
    required this.studentName,
    this.marksObtained,
    this.remarks,
    this.submittedOn,
  });

  factory AssessmentMarkEntry.fromMap(Map<String, dynamic> data) {
    return AssessmentMarkEntry(
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      marksObtained: data['marksObtained']?.toDouble(),
      remarks: data['remarks'],
      submittedOn: data['submittedOn'] != null
          ? DateTime.tryParse(data['submittedOn'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'marksObtained': marksObtained,
      'remarks': remarks,
      'submittedOn': submittedOn?.toIso8601String(),
    };
  }
}

class AssessmentModel {
  final String? id;
  final String orgId;
  final String deptId;
  final String facultyId;
  final String facultyName;
  final String title;
  final String assessmentType;
  final String courseId;
  final String courseName;
  final String section; // For backward compatibility
  final String scheme;
  final String semester;
  final double totalMarks;
  final DateTime dueDate;
  final String? description;
  final List<String> attachmentUrls;
  final List<String> attachmentNames;
  final bool allStudentsInSection;
  final List<String> selectedStudentIds;
  final bool allowLateSubmission;
  final bool showMarksToStudents;
  final List<AssessmentMarkEntry> marksEntries;
  final DateTime createdOn;
  final DateTime updatedOn;

  AssessmentModel({
    this.id,
    required this.orgId,
    required this.deptId,
    required this.facultyId,
    required this.facultyName,
    required this.title,
    required this.assessmentType,
    required this.courseId,
    required this.courseName,
    this.section = '', // Optional for backward compatibility
    required this.scheme,
    required this.semester,
    required this.totalMarks,
    required this.dueDate,
    this.description,
    this.attachmentUrls = const [],
    this.attachmentNames = const [],
    this.allStudentsInSection = true,
    this.selectedStudentIds = const [],
    this.allowLateSubmission = false,
    this.showMarksToStudents = true,
    this.marksEntries = const [],
    required this.createdOn,
    required this.updatedOn,
  });

  static const List<String> assessmentTypes = const [
    'Unit Test',
    'Assignment',
    'Mid Term',
    'Quiz',
    'Lab',
    'Seminar',
    'Project',
    'Other',
  ];

  factory AssessmentModel.fromFirestore(String id, Map<String, dynamic> data) {
    final List<AssessmentMarkEntry> entries = [];
    if (data['marksEntries'] != null && data['marksEntries'] is List) {
      for (final e in data['marksEntries']) {
        if (e is Map<String, dynamic>) {
          entries.add(AssessmentMarkEntry.fromMap(e));
        }
      }
    }
    return AssessmentModel(
      id: id,
      orgId: OrgField.normalize(data['org_id'] ?? data['orgId'] ?? ''),
      deptId: OrgField.normalize(data['dept_id'] ?? data['deptId'] ?? ''),
      facultyId: data['facultyId'] ?? '',
      facultyName: data['facultyName'] ?? '',
      title: data['title'] ?? '',
      assessmentType: data['assessmentType'] ?? '',
      courseId: data['courseId'] ?? '',
      courseName: data['courseName'] ?? '',
      section: data['section'] ?? '', // For backward compatibility
      scheme: data['scheme'] ?? '',
      semester: data['semester'] ?? '',
      totalMarks: (data['totalMarks'] ?? 0).toDouble(),
      dueDate: data['dueDate'] != null
          ? DateTime.tryParse(data['dueDate']) ?? DateTime.now()
          : DateTime.now(),
      description: data['description'],
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
      attachmentNames: List<String>.from(data['attachmentNames'] ?? []),
      allStudentsInSection: data['allStudentsInSection'] ?? true,
      selectedStudentIds: List<String>.from(data['selectedStudentIds'] ?? []),
      allowLateSubmission: data['allowLateSubmission'] ?? false,
      showMarksToStudents: data['showMarksToStudents'] ?? true,
      marksEntries: entries,
      createdOn: data['createdOn'] != null
          ? DateTime.tryParse(data['createdOn']) ?? DateTime.now()
          : DateTime.now(),
      updatedOn: data['updatedOn'] != null
          ? DateTime.tryParse(data['updatedOn']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'org_id': orgId,
      'dept_id': deptId,
      'facultyId': facultyId,
      'facultyName': facultyName,
      'title': title,
      'assessmentType': assessmentType,
      'courseId': courseId,
      'courseName': courseName,
      'section': section, // For backward compatibility
      'scheme': scheme,
      'semester': semester,
      'totalMarks': totalMarks,
      'dueDate': dueDate.toIso8601String(),
      'description': description,
      'attachmentUrls': attachmentUrls,
      'attachmentNames': attachmentNames,
      'allStudentsInSection': allStudentsInSection,
      'selectedStudentIds': selectedStudentIds,
      'allowLateSubmission': allowLateSubmission,
      'showMarksToStudents': showMarksToStudents,
      'marksEntries': marksEntries.map((e) => e.toMap()).toList(),
      'createdOn': createdOn.toIso8601String(),
      'updatedOn': updatedOn.toIso8601String(),
    };
  }

  AssessmentModel copyWith({
    String? id,
    String? orgId,
    String? deptId,
    String? facultyId,
    String? facultyName,
    String? title,
    String? assessmentType,
    String? courseId,
    String? courseName,
    String? section,
    String? scheme,
    String? semester,
    double? totalMarks,
    DateTime? dueDate,
    String? description,
    List<String>? attachmentUrls,
    List<String>? attachmentNames,
    bool? allStudentsInSection,
    List<String>? selectedStudentIds,
    bool? allowLateSubmission,
    bool? showMarksToStudents,
    List<AssessmentMarkEntry>? marksEntries,
    DateTime? createdOn,
    DateTime? updatedOn,
  }) {
    return AssessmentModel(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      deptId: deptId ?? this.deptId,
      facultyId: facultyId ?? this.facultyId,
      facultyName: facultyName ?? this.facultyName,
      title: title ?? this.title,
      assessmentType: assessmentType ?? this.assessmentType,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      section: section ?? this.section,
      scheme: scheme ?? this.scheme,
      semester: semester ?? this.semester,
      totalMarks: totalMarks ?? this.totalMarks,
      dueDate: dueDate ?? this.dueDate,
      description: description ?? this.description,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      attachmentNames: attachmentNames ?? this.attachmentNames,
      allStudentsInSection: allStudentsInSection ?? this.allStudentsInSection,
      selectedStudentIds: selectedStudentIds ?? this.selectedStudentIds,
      allowLateSubmission: allowLateSubmission ?? this.allowLateSubmission,
      showMarksToStudents: showMarksToStudents ?? this.showMarksToStudents,
      marksEntries: marksEntries ?? this.marksEntries,
      createdOn: createdOn ?? this.createdOn,
      updatedOn: updatedOn ?? this.updatedOn,
    );
  }
}
