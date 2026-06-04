/// Firestore field names and helpers for organisation scoping.
class OrgField {
  OrgField._();

  static const String orgIdKey = 'org_id';
  static const String deptIdKey = 'dept_id';

  /// Legacy/wrong casing seen in some documents — read only, never written.
  static const String legacyOrgIdKey = 'Org_id';

  static String normalize(String value) => value.trim();

  static String readOrgId(Map<String, dynamic> data) {
    return normalize(
      (data[orgIdKey] ?? data[legacyOrgIdKey] ?? '').toString(),
    );
  }

  static String readDeptId(Map<String, dynamic> data) {
    return normalize((data[deptIdKey] ?? '').toString());
  }

  static Map<String, dynamic> orgIdWrite(String orgId) {
    final normalized = normalize(orgId);
    if (normalized.isEmpty) {
      return const {};
    }
    return {orgIdKey: normalized};
  }
}
