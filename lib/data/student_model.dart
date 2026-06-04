import 'package:smartcampus/data/org_field.dart';

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
  /// Login id: mobile with country code, no + (e.g. 91XXXXXXXXXX).
  final String uuid;
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
    this.uuid = '',
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

  /// Normalizes a mobile or uuid to country-code digits without '+'.
  static String normalizeUuid(String mobileOrUuid) {
    final raw = mobileOrUuid.trim();
    final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length == 10) {
      return '91$digitsOnly';
    }
    if (digitsOnly.length == 12 && digitsOnly.startsWith('91')) {
      return digitsOnly;
    }
    return digitsOnly;
  }

  String get resolvedUuid {
    if (uuid.trim().isNotEmpty) {
      return normalizeUuid(uuid);
    }
    if (mobile.trim().isNotEmpty) {
      return normalizeUuid(mobile);
    }
    return '';
  }

  static String excelCellValue(dynamic cell) {
    if (cell == null) {
      return '';
    }
    try {
      final dynamic value = (cell as dynamic).value;
      if (value != null) {
        return value.toString().trim();
      }
    } catch (_) {
      // Not an Excel Data cell — fall through to toString().
    }
    return cell.toString().trim();
  }

  /// Builds a student from a spreadsheet row (dept admin import template).
  /// Column 8 is mobile; optional column 15 is explicit login [uuid].
  factory StudentModel.fromExcelRow(
    List<dynamic> row, {
    required String orgId,
    required String deptId,
    String createdOn = '',
  }) {
    String cell(int index) {
      if (index < 0 || index >= row.length) {
        return '';
      }
      return excelCellValue(row[index]);
    }

    final mobile = cell(8);
    final explicitUuid = cell(15);
    final loginUuid = explicitUuid.isNotEmpty
        ? normalizeUuid(explicitUuid)
        : normalizeUuid(mobile);

    return StudentModel(
      studentId: cell(0),
      fullName: cell(1),
      gender: cell(2),
      dateOfBirth: cell(3),
      aadhaarNumber: cell(4),
      category: cell(5),
      nationality: cell(6),
      bloodGroup: cell(7),
      uuid: loginUuid,
      mobile: mobile,
      email: cell(9),
      permanentAddress: cell(10),
      correspondenceAddress: cell(11),
      emergencyContactName: cell(12),
      emergencyContactRelation: cell(13),
      emergencyContactMobile: cell(14),
      orgId: orgId,
      deptId: deptId,
      createdOn: createdOn.isNotEmpty
          ? createdOn
          : DateTime.now().toIso8601String(),
    );
  }

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
      uuid: _readUuidFromMap(data),
      mobile: (data['mobile'] ?? '').toString().trim(),
      email: (data['email'] ?? '').toString().trim(),
      permanentAddress: (data['permanent_address'] ?? '').toString().trim(),
      correspondenceAddress: (data['correspondence_address'] ?? '').toString().trim(),
      emergencyContactName: (data['emergency_contact_name'] ?? '').toString().trim(),
      emergencyContactRelation: (data['emergency_contact_relation'] ?? '').toString().trim(),
      emergencyContactMobile: (data['emergency_contact_mobile'] ?? '').toString().trim(),
      orgId: OrgField.readOrgId(data),
      deptId: OrgField.readDeptId(data),
      status: (data['status'] ?? 'Active').toString().trim(),
      createdOn: (data['created_on'] ?? data['created_at'] ?? '')
          .toString()
          .trim(),
    );
  }

  static String _readUuidFromMap(Map<String, dynamic> data) {
    final stored = (data['uuid'] ?? '').toString().trim();
    if (stored.isNotEmpty) {
      return normalizeUuid(stored);
    }
    final mobile = (data['mobile'] ?? '').toString().trim();
    if (mobile.isNotEmpty) {
      return normalizeUuid(mobile);
    }
    return '';
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
    String? uuid,
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
      uuid: uuid ?? this.uuid,
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
      if (resolvedUuid.isNotEmpty) 'uuid': resolvedUuid,
      'mobile': mobile,
      'email': email,
      'permanent_address': permanentAddress,
      'correspondence_address': correspondenceAddress,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_relation': emergencyContactRelation,
      'emergency_contact_mobile': emergencyContactMobile,
      ...OrgField.orgIdWrite(orgId),
      if (OrgField.normalize(deptId).isNotEmpty) OrgField.deptIdKey: OrgField.normalize(deptId),
      'status': status,
      'created_on': createdOn,
    };
  }
}
