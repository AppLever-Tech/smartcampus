import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection: smcStudentMaster
class StudentModel {
  final String? documentId; // Firestore document ID
  // ── Basic Profile ──────────────────────────────────────────────
  final String studentId;       // Unique USN / Student ID
  final String fullName;
  final String gender;          // 'Male' | 'Female' | 'Other'
  final String dateOfBirth;     // ISO-8601 date string "YYYY-MM-DD"
  final String photographUrl;   // Firestore Storage download URL
  final String batch;           // e.g. '2023-25'

  // ── India-Specific Compliance / Identity ──────────────────────
  final String aadhaarNumber;
  final String category;        // 'Gen' | 'OBC' | 'SC' | 'ST'
  final String nationality;
  final String bloodGroup;

  // ── Contact Details ────────────────────────────────────────────
  final String mobile;
  final String email;

  // ── Address ───────────────────────────────────────────────────
  final String permanentAddress;
  final String correspondenceAddress;

  // ── Emergency Contact ─────────────────────────────────────────
  final String emergencyContactName;
  final String emergencyContactRelation;
  final String emergencyContactMobile;

  // ── Org / Dept binding ────────────────────────────────────────
  final String orgId;
  final String deptId;
  final String status;          // 'Active' | 'Inactive'
  final String createdOn;       // ISO-8601 datetime string (stored with time)

  const StudentModel({
    this.documentId,
    required this.studentId,
    required this.fullName,
    required this.gender,
    required this.dateOfBirth,
    this.photographUrl = '',
    this.batch = '',
    this.aadhaarNumber = '',
    this.category = 'Gen',
    this.nationality = 'Indian',
    this.bloodGroup = '',
    required this.mobile,
    required this.email,
    this.permanentAddress = '',
    this.correspondenceAddress = '',
    this.emergencyContactName = '',
    this.emergencyContactRelation = '',
    this.emergencyContactMobile = '',
    required this.orgId,
    required this.deptId,
    this.status = 'Active',
    required this.createdOn,
  });

  // ── Firestore serialisation ────────────────────────────────────
  factory StudentModel.fromMap(Map<String, dynamic> data, {String? documentId}) {
    return StudentModel(
      documentId: documentId,
      studentId: (data['student_id'] ?? '').toString().trim(),
      fullName: (data['full_name'] ?? '').toString().trim(),
      gender: (data['gender'] ?? '').toString().trim(),
      dateOfBirth: (data['date_of_birth'] ?? '').toString().trim(),
      photographUrl: (data['photograph_url'] ??
              data['photographUrl'] ??
              data['photo_url'] ??
              '')
          .toString()
          .trim(),
      batch: (data['batch'] ?? '').toString().trim(),
      aadhaarNumber: (data['aadhaar_number'] ?? '').toString().trim(),
      category: (data['category'] ?? 'Gen').toString().trim(),
      nationality: (data['nationality'] ?? 'Indian').toString().trim(),
      bloodGroup: (data['blood_group'] ?? '').toString().trim(),
      mobile: (data['mobile'] ?? '').toString().trim(),
      email: (data['email'] ?? '').toString().trim(),
      permanentAddress: (data['permanent_address'] ?? '').toString().trim(),
      correspondenceAddress: (data['correspondence_address'] ?? '').toString().trim(),
      emergencyContactName: (data['emergency_contact_name'] ?? '').toString().trim(),
      emergencyContactRelation: (data['emergency_contact_relation'] ?? '').toString().trim(),
      emergencyContactMobile: (data['emergency_contact_mobile'] ?? '').toString().trim(),
      orgId: (data['org_id'] ?? '').toString().trim(),
      deptId: (data['dept_id'] ?? '').toString().trim(),
      status: (data['status'] ?? 'Active').toString().trim(),
      createdOn: (data['created_on'] ?? data['created_at'] ?? '')
          .toString()
          .trim(),
    );
  }

  StudentModel copyWith({
    String? documentId,
    String? studentId,
    String? fullName,
    String? gender,
    String? dateOfBirth,
    String? photographUrl,
    String? batch,
    String? aadhaarNumber,
    String? category,
    String? nationality,
    String? bloodGroup,
    String? mobile,
    String? email,
    String? permanentAddress,
    String? correspondenceAddress,
    String? emergencyContactName,
    String? emergencyContactRelation,
    String? emergencyContactMobile,
    String? orgId,
    String? deptId,
    String? status,
    String? createdOn,
  }) {
    return StudentModel(
      documentId: documentId ?? this.documentId,
      studentId: studentId ?? this.studentId,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      photographUrl: photographUrl ?? this.photographUrl,
      batch: batch ?? this.batch,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      category: category ?? this.category,
      nationality: nationality ?? this.nationality,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      permanentAddress: permanentAddress ?? this.permanentAddress,
      correspondenceAddress: correspondenceAddress ?? this.correspondenceAddress,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactRelation: emergencyContactRelation ?? this.emergencyContactRelation,
      emergencyContactMobile: emergencyContactMobile ?? this.emergencyContactMobile,
      orgId: orgId ?? this.orgId,
      deptId: deptId ?? this.deptId,
      status: status ?? this.status,
      createdOn: createdOn ?? this.createdOn,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'student_id': studentId,
      'full_name': fullName,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'photograph_url': photographUrl,
      'batch': batch,
      'aadhaar_number': aadhaarNumber,
      'category': category,
      'nationality': nationality,
      'blood_group': bloodGroup,
      'mobile': mobile,
      'email': email,
      'permanent_address': permanentAddress,
      'correspondence_address': correspondenceAddress,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_relation': emergencyContactRelation,
      'emergency_contact_mobile': emergencyContactMobile,
      'org_id': orgId,
      'dept_id': deptId,
      'status': status,
      'created_on': createdOn,
    };
  }
}
