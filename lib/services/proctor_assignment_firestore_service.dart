import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartcampus/data/org_field.dart';

class ProctorAssignmentFirestoreService {
  static const String collection = 'smcProctorAssignments';

  final FirebaseFirestore _db;

  ProctorAssignmentFirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  static String normalizeOrgId(String orgId) => OrgField.normalize(orgId);

  static String normalizeDeptId(String deptId) => OrgField.normalize(deptId);

  static String normalizeFacultyId(String facultyId) =>
      facultyId.trim().toUpperCase();

  String _documentId({
    required String orgId,
    required String deptId,
    required String facultyId,
  }) {
    final parts = <String>[
      normalizeOrgId(orgId),
      if (normalizeDeptId(deptId).isNotEmpty) normalizeDeptId(deptId),
      normalizeFacultyId(facultyId),
    ];
    return parts.join('__');
  }

  Future<Map<String, List<String>>> listAssignmentsForDept({
    required String orgId,
    required String deptId,
  }) async {
    final orgNorm = normalizeOrgId(orgId);
    final deptNorm = normalizeDeptId(deptId);
    if (orgNorm.isEmpty) {
      return const {};
    }

    Query<Map<String, dynamic>> query = _db
        .collection(collection)
        .where(OrgField.orgIdKey, isEqualTo: orgNorm);
    if (deptNorm.isNotEmpty) {
      query = query.where(OrgField.deptIdKey, isEqualTo: deptNorm);
    }

    final snap = await query.get();
    final assignments = <String, List<String>>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final facultyId = normalizeFacultyId(
        (data['faculty_id'] ?? '').toString(),
      );
      if (facultyId.isEmpty) {
        continue;
      }
      final rawIds = data['student_document_ids'];
      final studentDocumentIds = rawIds is Iterable
          ? rawIds
              .map((id) => id.toString().trim())
              .where((id) => id.isNotEmpty)
              .toList()
          : <String>[];
      assignments[facultyId] = studentDocumentIds;
    }
    return assignments;
  }

  Future<void> saveAssignments({
    required String orgId,
    required String deptId,
    required String facultyId,
    required List<String> studentDocumentIds,
    List<String> studentIds = const [],
  }) async {
    final orgNorm = normalizeOrgId(orgId);
    final deptNorm = normalizeDeptId(deptId);
    final facultyNorm = normalizeFacultyId(facultyId);
    if (orgNorm.isEmpty || facultyNorm.isEmpty) {
      return;
    }

    final normalizedDocumentIds = <String>[];
    for (final id in studentDocumentIds) {
      final trimmed = id.trim();
      if (trimmed.isNotEmpty && !normalizedDocumentIds.contains(trimmed)) {
        normalizedDocumentIds.add(trimmed);
      }
    }

    final normalizedStudentIds = <String>[];
    for (final id in studentIds) {
      final trimmed = id.trim();
      if (trimmed.isNotEmpty && !normalizedStudentIds.contains(trimmed)) {
        normalizedStudentIds.add(trimmed);
      }
    }

    await _db.collection(collection).doc(
      _documentId(orgId: orgNorm, deptId: deptNorm, facultyId: facultyNorm),
    ).set({
      'faculty_id': facultyNorm,
      'student_document_ids': normalizedDocumentIds,
      'student_ids': normalizedStudentIds,
      ...OrgField.orgIdWrite(orgNorm),
      if (deptNorm.isNotEmpty) OrgField.deptIdKey: deptNorm,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String?> findProctorFacultyIdForStudent({
    required String orgId,
    required String deptId,
    required String studentDocumentId,
    required String studentId,
  }) async {
    final orgNorm = normalizeOrgId(orgId);
    final deptNorm = normalizeDeptId(deptId);
    if (orgNorm.isEmpty) {
      return null;
    }

    Query<Map<String, dynamic>> query = _db
        .collection(collection)
        .where(OrgField.orgIdKey, isEqualTo: orgNorm);
    if (deptNorm.isNotEmpty) {
      query = query.where(OrgField.deptIdKey, isEqualTo: deptNorm);
    }

    final snap = await query.get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final List<dynamic> studentDocIds = data['student_document_ids'] ?? [];
      final List<dynamic> stdIds = data['student_ids'] ?? [];
      if (studentDocIds.contains(studentDocumentId) || stdIds.contains(studentId)) {
        return data['faculty_id'] as String?;
      }
    }
    return null;
  }
}
