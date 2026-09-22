class AssignmentModel {
  final String id;
  final String courseId;
  final String facultyId;
  final String orgId;
  final String title;
  final String startDate;
  final String submitDate;
  final String description;
  final String documentUrl;
  final String documentName;

  AssignmentModel({
    required this.id,
    required this.courseId,
    required this.facultyId,
    required this.orgId,
    required this.title,
    required this.startDate,
    required this.submitDate,
    required this.description,
    this.documentUrl = '',
    this.documentName = '',
  });

  factory AssignmentModel.fromMap(Map<String, dynamic> data, String documentId) {
    return AssignmentModel(
      id: documentId,
      courseId: (data['course_id'] ?? '').toString().trim(),
      facultyId: (data['faculty_id'] ?? '').toString().trim(),
      orgId: (data['org_id'] ?? '').toString().trim(),
      title: (data['title'] ?? '').toString().trim(),
      startDate: (data['start_date'] ?? '').toString().trim(),
      submitDate: (data['submit_date'] ?? '').toString().trim(),
      description: (data['description'] ?? '').toString().trim(),
      documentUrl: (data['document_url'] ?? '').toString().trim(),
      documentName: (data['document_name'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'course_id': courseId,
      'faculty_id': facultyId,
      'org_id': orgId,
      'title': title,
      'start_date': startDate,
      'submit_date': submitDate,
      'description': description,
      if (documentUrl.isNotEmpty) 'document_url': documentUrl,
      if (documentName.isNotEmpty) 'document_name': documentName,
    };
  }
}
