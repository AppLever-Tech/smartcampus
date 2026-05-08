import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection: smcFacultyMaster
class FacultyModel {
  final String? documentId; // Firestore document ID
  // ── Basic Profile ──────────────────────────────────────────────
  final String facultyId;       // Unique employee / faculty ID
  final String fullName;
  final String gender;          // 'Male' | 'Female' | 'Other' | 'Prefer not to say'
  final String dateOfBirth;     // ISO-8601 date string  "YYYY-MM-DD"
  final String photographUrl;   // Firestore Storage download URL (empty until uploaded)

  // ── India-Specific Compliance ──────────────────────────────────
  final String aadhaarNumber;   // masked / encrypted in production
  final String panNumber;

  // ── Contact Details ────────────────────────────────────────────
  final String mobile;
  final String email;

  // ── Address ───────────────────────────────────────────────────
  final String permanentAddress;
  final String currentAddress;

  // ── Emergency Contact ─────────────────────────────────────────
  final String emergencyContactName;
  final String emergencyContactRelation;
  final String emergencyContactMobile;

  // ── Org / Dept binding ────────────────────────────────────────
  final String orgId;
  final String deptId;
  final String status;          // 'Active' | 'Inactive'
  final String createdAt;       // ISO-8601 timestamp

  const FacultyModel({
    this.documentId,
    required this.facultyId,
    required this.fullName,
    required this.gender,
    required this.dateOfBirth,
    this.photographUrl = '',
    this.aadhaarNumber = '',
    this.panNumber = '',
    required this.mobile,
    required this.email,
    this.permanentAddress = '',
    this.currentAddress = '',
    this.emergencyContactName = '',
    this.emergencyContactRelation = '',
    this.emergencyContactMobile = '',
    required this.orgId,
    required this.deptId,
    this.status = 'Active',
    required this.createdAt,
  });

  // ── Firestore serialisation ────────────────────────────────────
  factory FacultyModel.fromMap(Map<String, dynamic> data, {String? documentId}) {
    return FacultyModel(
      documentId: documentId,
      facultyId: (data['faculty_id'] ?? '').toString().trim(),
      fullName: (data['full_name'] ?? '').toString().trim(),
      gender: (data['gender'] ?? '').toString().trim(),
      dateOfBirth: (data['date_of_birth'] ?? '').toString().trim(),
      photographUrl: (data['photograph_url'] ?? '').toString().trim(),
      aadhaarNumber: (data['aadhaar_number'] ?? '').toString().trim(),
      panNumber: (data['pan_number'] ?? '').toString().trim(),
      mobile: (data['mobile'] ?? '').toString().trim(),
      email: (data['email'] ?? '').toString().trim(),
      permanentAddress: (data['permanent_address'] ?? '').toString().trim(),
      currentAddress: (data['current_address'] ?? '').toString().trim(),
      emergencyContactName:
      (data['emergency_contact_name'] ?? '').toString().trim(),
      emergencyContactRelation:
      (data['emergency_contact_relation'] ?? '').toString().trim(),
      emergencyContactMobile:
      (data['emergency_contact_mobile'] ?? '').toString().trim(),
      orgId: (data['org_id'] ?? '').toString().trim(),
      deptId: (data['dept_id'] ?? '').toString().trim(),
      status: (data['status'] ?? 'Active').toString().trim(),
      createdAt: (data['created_at'] ?? '').toString().trim(),
    );
  }

  FacultyModel copyWith({
    String? documentId,
    String? facultyId,
    String? fullName,
    String? gender,
    String? dateOfBirth,
    String? photographUrl,
    String? aadhaarNumber,
    String? panNumber,
    String? mobile,
    String? email,
    String? permanentAddress,
    String? currentAddress,
    String? emergencyContactName,
    String? emergencyContactRelation,
    String? emergencyContactMobile,
    String? orgId,
    String? deptId,
    String? status,
    String? createdAt,
  }) {
    return FacultyModel(
      documentId: documentId ?? this.documentId,
      facultyId: facultyId ?? this.facultyId,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      photographUrl: photographUrl ?? this.photographUrl,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      panNumber: panNumber ?? this.panNumber,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      permanentAddress: permanentAddress ?? this.permanentAddress,
      currentAddress: currentAddress ?? this.currentAddress,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactRelation:
      emergencyContactRelation ?? this.emergencyContactRelation,
      emergencyContactMobile:
      emergencyContactMobile ?? this.emergencyContactMobile,
      orgId: orgId ?? this.orgId,
      deptId: deptId ?? this.deptId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'faculty_id': facultyId,
      'full_name': fullName,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'photograph_url': photographUrl,
      'aadhaar_number': aadhaarNumber,
      'pan_number': panNumber,
      'mobile': mobile,
      'email': email,
      'permanent_address': permanentAddress,
      'current_address': currentAddress,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_relation': emergencyContactRelation,
      'emergency_contact_mobile': emergencyContactMobile,
      'org_id': orgId,
      'dept_id': deptId,
      'status': status,
      'created_at': createdAt,
    };
  }
}
