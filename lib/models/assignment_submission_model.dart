class AssignmentSubmissionModel {
  final String id;
  final String assignmentId;
  final String studentId;
  final String studentName;
  final String submittedAt;
  final String fileUrl;
  final String fileName;
  final String fileType; // 'pdf', 'image', etc.
  final String remarks;

  AssignmentSubmissionModel({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.studentName,
    required this.submittedAt,
    this.fileUrl = '',
    this.fileName = '',
    this.fileType = '',
    this.remarks = '',
  });

  factory AssignmentSubmissionModel.fromMap(Map<String, dynamic> data, String documentId) {
    return AssignmentSubmissionModel(
      id: documentId,
      assignmentId: (data['assignment_id'] ?? '').toString().trim(),
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
      'assignment_id': assignmentId,
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
