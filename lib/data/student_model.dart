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
  final String currentSemester; // e.g. 'III'

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

  // ── Family Details ────────────────────────────────────────────
  final String fatherName;
  final String motherName;
  final String guardianName;

  // ── Org / Dept binding ────────────────────────────────────────
  final String orgId;
  final String deptId;
  final String status;          // 'Active' | 'Inactive'
  final String createdOn;       // ISO-8601 datetime string (stored with time)
  final String proctorId;       // Assigned proctor faculty ID
  /// courseId -> { gradePoints, letterGrade }
  final Map<String, Map<String, String>> enrolledCourseMarks;
  /// semester -> SGPA for that semester (e.g. "I" -> "8.5")
  final Map<String, String> semesterSgpa;
  /// Latest cumulative CGPA across all semesters.
  final String cgpa;

  static const List<String> semesterOptions = ['I', 'II', 'III', 'IV'];

  const StudentModel({
    this.documentId,
    required this.studentId,
    required this.fullName,
    required this.gender,
    required this.dateOfBirth,
    this.photographUrl = '',
    this.batch = '',
    this.currentSemester = '',
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
    this.fatherName = '',
    this.motherName = '',
    this.guardianName = '',
    required this.orgId,
    required this.deptId,
    this.status = 'Active',
    required this.createdOn,
    this.proctorId = '',
    this.enrolledCourseMarks = const {},
    this.semesterSgpa = const {},
    this.cgpa = '',
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
      currentSemester: (data['current_semester'] ?? '').toString().trim(),
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
      fatherName: (data['father_name'] ?? '').toString().trim(),
      motherName: (data['mother_name'] ?? '').toString().trim(),
      guardianName: (data['guardian_name'] ?? '').toString().trim(),
      orgId: OrgField.readOrgId(data),
      deptId: OrgField.readDeptId(data),
      status: (data['status'] ?? 'Active').toString().trim(),
      createdOn: (data['created_on'] ?? data['created_at'] ?? '')
          .toString()
          .trim(),
      proctorId: (data['proctor_id'] ?? '').toString().trim(),
      enrolledCourseMarks: parseEnrolledCourseMarks(
        data['enrolled_course_marks'],
      ),
      semesterSgpa: parseSemesterSgpa(
        data['semester_sgpa'],
        legacySemesterGpa: data['semester_gpa'],
      ),
      cgpa: parseCgpa(
        data['cgpa'],
        legacySemesterGpa: data['semester_gpa'],
      ),
    );
  }

  static Map<String, Map<String, String>> parseEnrolledCourseMarks(
    dynamic value,
  ) {
    if (value is! Map) {
      return const {};
    }

    final Map<String, Map<String, String>> marks = {};
    value.forEach((dynamic courseId, dynamic rawMarks) {
      if (courseId == null || rawMarks is! Map) {
        return;
      }
      marks[courseId.toString()] = {
        'gradePoints': (rawMarks['grade_points'] ?? rawMarks['gradePoints'] ?? '')
            .toString()
            .trim(),
        'letterGrade':
            (rawMarks['letter_grade'] ?? rawMarks['letterGrade'] ?? '')
                .toString()
                .trim(),
      };
    });
    return marks;
  }

  static Map<String, dynamic> writeEnrolledCourseMarks(
    Map<String, Map<String, String>> marks,
  ) {
    final Map<String, dynamic> serialized = {};
    marks.forEach((courseId, values) {
      final String gradePoints = values['gradePoints']?.trim() ?? '';
      final String letterGrade = values['letterGrade']?.trim() ?? '';
      if (gradePoints.isEmpty && letterGrade.isEmpty) {
        return;
      }
      serialized[courseId] = {
        if (gradePoints.isNotEmpty) 'grade_points': gradePoints,
        if (letterGrade.isNotEmpty) 'letter_grade': letterGrade,
      };
    });
    return serialized;
  }

  static Map<String, String> parseSemesterSgpa(
    dynamic value, {
    dynamic legacySemesterGpa,
  }) {
    final Map<String, String> semesterSgpa = {};
    if (value is Map) {
      value.forEach((dynamic semester, dynamic sgpa) {
        if (semester == null) {
          return;
        }
        final String trimmed = sgpa.toString().trim();
        if (trimmed.isNotEmpty) {
          semesterSgpa[semester.toString()] = trimmed;
        }
      });
    }

    if (legacySemesterGpa is Map) {
      legacySemesterGpa.forEach((dynamic semester, dynamic rawGpa) {
        if (semester == null || rawGpa is! Map) {
          return;
        }
        final String key = semester.toString();
        if (semesterSgpa.containsKey(key)) {
          return;
        }
        final String sgpa = (rawGpa['sgpa'] ?? '').toString().trim();
        if (sgpa.isNotEmpty) {
          semesterSgpa[key] = sgpa;
        }
      });
    }

    return semesterSgpa;
  }

  static String parseCgpa(
    dynamic value, {
    dynamic legacySemesterGpa,
  }) {
    final String fromRoot = (value ?? '').toString().trim();
    if (fromRoot.isNotEmpty) {
      return fromRoot;
    }

    if (legacySemesterGpa is! Map) {
      return '';
    }

    for (final String semester in ['IV', 'III', 'II', 'I']) {
      final dynamic rawGpa = legacySemesterGpa[semester];
      if (rawGpa is! Map) {
        continue;
      }
      final String cgpa = (rawGpa['cgpa'] ?? '').toString().trim();
      if (cgpa.isNotEmpty) {
        return cgpa;
      }
    }

    return '';
  }

  static Map<String, dynamic> writeSemesterSgpa(Map<String, String> semesterSgpa) {
    final Map<String, dynamic> serialized = {};
    semesterSgpa.forEach((semester, sgpa) {
      final String trimmed = sgpa.trim();
      if (trimmed.isNotEmpty) {
        serialized[semester] = trimmed;
      }
    });
    return serialized;
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
    String? currentSemester,
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
    String? fatherName,
    String? motherName,
    String? guardianName,
    String? orgId,
    String? deptId,
    String? status,
    String? createdOn,
    String? proctorId,
    Map<String, Map<String, String>>? enrolledCourseMarks,
    Map<String, String>? semesterSgpa,
    String? cgpa,
  }) {
    return StudentModel(
      documentId: documentId ?? this.documentId,
      studentId: studentId ?? this.studentId,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      photographUrl: photographUrl ?? this.photographUrl,
      batch: batch ?? this.batch,
      currentSemester: currentSemester ?? this.currentSemester,
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
      emergencyContactRelation:
          emergencyContactRelation ?? this.emergencyContactRelation,
      emergencyContactMobile:
          emergencyContactMobile ?? this.emergencyContactMobile,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      guardianName: guardianName ?? this.guardianName,
      orgId: orgId ?? this.orgId,
      deptId: deptId ?? this.deptId,
      status: status ?? this.status,
      createdOn: createdOn ?? this.createdOn,
      proctorId: proctorId ?? this.proctorId,
      enrolledCourseMarks: enrolledCourseMarks ?? this.enrolledCourseMarks,
      semesterSgpa: semesterSgpa ?? this.semesterSgpa,
      cgpa: cgpa ?? this.cgpa,
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
      'current_semester': currentSemester,
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
      'father_name': fatherName,
      'mother_name': motherName,
      'guardian_name': guardianName,
      ...OrgField.orgIdWrite(orgId),
      if (OrgField.normalize(deptId).isNotEmpty) OrgField.deptIdKey: OrgField.normalize(deptId),
      'status': status,
      'created_on': createdOn,
      if (proctorId.trim().isNotEmpty) 'proctor_id': proctorId.trim(),
      if (enrolledCourseMarks.isNotEmpty)
        'enrolled_course_marks':
            writeEnrolledCourseMarks(enrolledCourseMarks),
      if (semesterSgpa.isNotEmpty)
        'semester_sgpa': writeSemesterSgpa(semesterSgpa),
      if (cgpa.trim().isNotEmpty) 'cgpa': cgpa.trim(),
    };
  }
}
