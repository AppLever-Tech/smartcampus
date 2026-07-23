import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveRequestModel {
  final String id;
  final String orgId;
  final String deptId;
  final String studentId;
  final String studentName;
  final String proctorId;
  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final String attachmentUrl;
  final String attachmentName;
  final String status; // 'Pending', 'Approved', 'Rejected'
  final DateTime createdAt;
  final DateTime? updatedAt;

  static const List<String> leaveTypes = [
    'Sick Leave',
    'Medical Leave',
    'Personal Leave',
    'Emergency Leave',
    'Others',
  ];

  static const List<String> statuses = [
    'Pending',
    'Approved',
    'Rejected',
  ];

  LeaveRequestModel({
    required this.id,
    required this.orgId,
    required this.deptId,
    required this.studentId,
    required this.studentName,
    required this.proctorId,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    this.attachmentUrl = '',
    this.attachmentName = '',
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory LeaveRequestModel.fromFirestore(String id, Map<String, dynamic> data) {
    return LeaveRequestModel(
      id: id,
      orgId: data['org_id'] ?? '',
      deptId: data['dept_id'] ?? '',
      studentId: data['student_id'] ?? '',
      studentName: data['student_name'] ?? '',
      proctorId: data['proctor_id'] ?? '',
      leaveType: data['leave_type'] ?? 'Sick Leave',
      fromDate: data['from_date'] is Timestamp
          ? (data['from_date'] as Timestamp).toDate()
          : DateTime.tryParse(data['from_date'] ?? '') ?? DateTime.now(),
      toDate: data['to_date'] is Timestamp
          ? (data['to_date'] as Timestamp).toDate()
          : DateTime.tryParse(data['to_date'] ?? '') ?? DateTime.now(),
      reason: data['reason'] ?? '',
      attachmentUrl: data['attachment_url'] ?? '',
      attachmentName: data['attachment_name'] ?? '',
      status: data['status'] ?? 'Pending',
      createdAt: data['created_at'] is Timestamp
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: data['updated_at'] != null
          ? (data['updated_at'] is Timestamp
              ? (data['updated_at'] as Timestamp).toDate()
              : DateTime.tryParse(data['updated_at'] ?? ''))
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'org_id': orgId,
      'dept_id': deptId,
      'student_id': studentId,
      'student_name': studentName,
      'proctor_id': proctorId,
      'leave_type': leaveType,
      'from_date': Timestamp.fromDate(fromDate),
      'to_date': Timestamp.fromDate(toDate),
      'reason': reason,
      'attachment_url': attachmentUrl,
      'attachment_name': attachmentName,
      'status': status,
      'created_at': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updated_at': Timestamp.fromDate(updatedAt!),
    };
  }

  LeaveRequestModel copyWith({
    String? id,
    String? orgId,
    String? deptId,
    String? studentId,
    String? studentName,
    String? proctorId,
    String? leaveType,
    DateTime? fromDate,
    DateTime? toDate,
    String? reason,
    String? attachmentUrl,
    String? attachmentName,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeaveRequestModel(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      deptId: deptId ?? this.deptId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      proctorId: proctorId ?? this.proctorId,
      leaveType: leaveType ?? this.leaveType,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      reason: reason ?? this.reason,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName ?? this.attachmentName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
