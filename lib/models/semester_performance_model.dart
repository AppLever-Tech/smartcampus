class SemesterPerformanceModel {
  final String? id;
  final String uuid;
  final String semester; // Semester I, II, III, IV
  final double sgpa;
  final double cgpa;
  final int backlogs;
  final String status; // "Clear" or "Active"
  final String remarks;
  final DateTime createdOn;

  SemesterPerformanceModel({
    this.id,
    required this.uuid,
    required this.semester,
    this.sgpa = 0.0,
    this.cgpa = 0.0,
    this.backlogs = 0,
    this.status = 'Clear',
    this.remarks = '',
    required this.createdOn,
  });

  factory SemesterPerformanceModel.fromFirestore(String id, Map<String, dynamic> data) {
    return SemesterPerformanceModel(
      id: id,
      uuid: data['uuid'] ?? '',
      semester: data['semester'] ?? '',
      sgpa: (data['sgpa'] as num?)?.toDouble() ?? 0.0,
      cgpa: (data['cgpa'] as num?)?.toDouble() ?? 0.0,
      backlogs: (data['backlogs'] as num?)?.toInt() ?? 0,
      status: data['status'] ?? 'Clear',
      remarks: data['remarks'] ?? '',
      createdOn: data['createdOn'] != null
          ? DateTime.parse(data['createdOn'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'semester': semester,
      'sgpa': sgpa,
      'cgpa': cgpa,
      'backlogs': backlogs,
      'status': status,
      'remarks': remarks,
      'createdOn': createdOn.toIso8601String(),
    };
  }
}
