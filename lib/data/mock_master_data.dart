import 'package:smartcampus/data/org_field.dart';

class OrgUserRoleMappingItem {
  final String uuid;
  final String orgId;
  final String orgUniqueId;
  final String roleId;
  final String name;
  final String status;
  final String deptId;
  final String documentId;

  const OrgUserRoleMappingItem({
    required this.uuid,
    required this.orgId,
    this.orgUniqueId = '',
    required this.roleId,
    required this.name,
    this.status = 'Approved',
    this.deptId = '',
    this.documentId = '',
  });

  bool get isRegisteredPending => isPendingApproval;

  bool get isPendingApproval {
    final normalized = status.toLowerCase().trim();
    return normalized == 'pending approval' ||
        normalized == 'registered' ||
        normalized == 'pending';
  }

  String get normalizedRoleId => roleId.toUpperCase().trim();

  factory OrgUserRoleMappingItem.fromUserMaster(UserMasterItem user) {
    final String role =
        user.userRole.isNotEmpty ? user.userRole : user.roleId;
    return OrgUserRoleMappingItem(
      uuid: user.uuid,
      orgId: user.orgId.isNotEmpty ? user.orgId : user.requestedOrgId,
      roleId: role,
      name: user.displayName,
      status: user.status,
      deptId: user.deptId,
      documentId: user.uuid,
    );
  }

  factory OrgUserRoleMappingItem.fromMap(
    Map<String, dynamic> data, {
    String documentId = '',
  }) {
    return OrgUserRoleMappingItem(
      uuid: (data['uuid'] ?? '').toString().trim(),
      orgId: (data['org_id'] ?? '').toString().trim(),
      orgUniqueId: (data['org_unique_id'] ?? '').toString().trim(),
      roleId: (data['role_id'] ?? '').toString().trim(),
      name: (data['name'] ?? '').toString().trim(),
      status: (data['status'] ?? 'Approved').toString().trim(),
      deptId: (data['dept_id'] ?? '').toString().trim(),
      documentId: documentId,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uuid': uuid,
      'org_id': orgId,
      'org_unique_id': orgUniqueId,
      'role_id': roleId,
      'name': name,
      'status': status,
      'dept_id': deptId,
    };
  }

  OrgUserRoleMappingItem copyWith({
    String? uuid,
    String? orgId,
    String? orgUniqueId,
    String? roleId,
    String? name,
    String? status,
    String? deptId,
    String? documentId,
  }) {
    return OrgUserRoleMappingItem(
      uuid: uuid ?? this.uuid,
      orgId: orgId ?? this.orgId,
      orgUniqueId: orgUniqueId ?? this.orgUniqueId,
      roleId: roleId ?? this.roleId,
      name: name ?? this.name,
      status: status ?? this.status,
      deptId: deptId ?? this.deptId,
      documentId: documentId ?? this.documentId,
    );
  }
}

class UserMasterItem {
  final String uuid;
  final String userName;
  final String userRole;
  final String status;
  final String orgId;
  final String deptId;

  // Legacy / auxiliary fields kept for backward compatibility while reading.
  final String name;
  final String email;
  final String mobile;
  final String photoUrl;
  final String userType;
  final String roleId;
  final String requestedOrgId;
  final String requestedOrgName;
  final String requestedOn;

  const UserMasterItem({
    required this.uuid,
    this.userName = '',
    this.userRole = '',
    required this.status,
    this.orgId = '',
    this.deptId = '',
    this.name = '',
    this.email = '',
    this.mobile = '',
    this.photoUrl = '',
    this.userType = '',
    this.roleId = '',
    this.requestedOrgId = '',
    this.requestedOrgName = '',
    this.requestedOn = '',
  });

  String get displayName =>
      userName.isNotEmpty ? userName : (name.isNotEmpty ? name : 'User');

  String get normalizedUserRole {
    final raw = userRole.isNotEmpty ? userRole : roleId;
    if (raw.isEmpty) {
      return userType.toUpperCase().replaceAll(' ', '_');
    }
    return raw.toUpperCase().trim().replaceAll(' ', '_');
  }

  bool get isUnclassified => normalizedUserRole == 'UNCLASSIFIED';

  bool get isPendingApproval {
    final normalized = status.toLowerCase().trim();
    return normalized == 'pending approval' ||
        normalized == 'registered' ||
        normalized == 'pending';
  }

  bool get isApproved {
    final normalized = status.toLowerCase().trim();
    return normalized == 'approved';
  }

  String get displayStatus {
    if (isApproved) {
      return 'Approved';
    }
    if (isPendingApproval) {
      return 'Pending Approval';
    }
    return status;
  }

  factory UserMasterItem.fromMap(Map<String, dynamic> data) {
    final String resolvedName =
        (data['user_name'] ?? data['name'] ?? '').toString().trim();
    final String resolvedRole = (data['user_role'] ??
            data['role_id'] ??
            data['user_type'] ??
            '')
        .toString()
        .trim();
    return UserMasterItem(
      uuid: (data['uuid'] ?? '').toString().trim(),
      userName: resolvedName,
      userRole: resolvedRole,
      status: (data['status'] ?? 'Pending Approval').toString().trim(),
      orgId: OrgField.readOrgId(data),
      deptId: OrgField.readDeptId(data),
      name: resolvedName,
      email: (data['email'] ?? '').toString().trim(),
      mobile: (data['mobile'] ?? data['phone'] ?? '').toString().trim(),
      photoUrl: (data['photo_url'] ?? data['profile_pic'] ?? '')
          .toString()
          .trim(),
      userType: (data['user_type'] ?? data['designation'] ?? 'User')
          .toString()
          .trim(),
      roleId: resolvedRole,
      requestedOrgId: (data['requested_org_id'] ?? data['org_id'] ?? '')
          .toString()
          .trim(),
      requestedOrgName: (data['requested_org_name'] ?? '').toString().trim(),
      requestedOn: (data['requested_on'] ?? data['created_at'] ?? '')
          .toString()
          .trim(),
    );
  }

  /// Canonical write shape — four primary identity fields plus optional scope.
  Map<String, dynamic> toCoreMap({String? orgId, String? deptId}) {
    return <String, dynamic>{
      'uuid': uuid,
      'user_name': displayName,
      'user_role': userRole.isNotEmpty ? userRole : roleId,
      'status': status,
      ...OrgField.orgIdWrite(orgId ?? this.orgId),
      if (OrgField.normalize(deptId ?? this.deptId).isNotEmpty)
        OrgField.deptIdKey: OrgField.normalize(deptId ?? this.deptId),
    };
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      ...toCoreMap(),
      'name': displayName,
      'email': email,
      'mobile': mobile.isNotEmpty ? mobile : uuid,
      'photo_url': photoUrl,
      'user_type': userType,
      'role_id': userRole.isNotEmpty ? userRole : roleId,
      'requested_org_id': requestedOrgId,
      'requested_org_name': requestedOrgName,
      'requested_on': requestedOn,
    };
  }

  UserMasterItem copyWith({
    String? uuid,
    String? userName,
    String? userRole,
    String? status,
    String? orgId,
    String? deptId,
    String? name,
    String? email,
    String? mobile,
    String? photoUrl,
    String? userType,
    String? roleId,
    String? requestedOrgId,
    String? requestedOrgName,
    String? requestedOn,
  }) {
    return UserMasterItem(
      uuid: uuid ?? this.uuid,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      status: status ?? this.status,
      orgId: orgId ?? this.orgId,
      deptId: deptId ?? this.deptId,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      photoUrl: photoUrl ?? this.photoUrl,
      userType: userType ?? this.userType,
      roleId: roleId ?? this.roleId,
      requestedOrgId: requestedOrgId ?? this.requestedOrgId,
      requestedOrgName: requestedOrgName ?? this.requestedOrgName,
      requestedOn: requestedOn ?? this.requestedOn,
    );
  }
}

class OrganizationItem {
  final String orgId;
  final String orgUniqueId;
  final String orgName;
  final String orgType;
  final String orgAddress;
  final String orgWebsite;
  final String adminUuid;
  final String adminName;
  final String status;

  const OrganizationItem({
    required this.orgId,
    this.orgUniqueId = '',
    required this.orgName,
    required this.orgType,
    required this.orgAddress,
    required this.orgWebsite,
    required this.adminUuid,
    required this.adminName,
    required this.status,
  });

  factory OrganizationItem.fromMap(Map<String, dynamic> data, {String documentId = ''}) {
    return OrganizationItem(
      orgId: (data['org_id'] ?? '').toString().trim(),
      orgUniqueId: (data['org_unique_id'] ?? documentId).toString().trim(),
      orgName: (data['org_name'] ?? '').toString().trim(),
      orgType: (data['org_type'] ?? '').toString().trim(),
      orgAddress: (data['org_address'] ?? '').toString().trim(),
      orgWebsite: (data['org_website'] ?? '').toString().trim(),
      adminUuid: (data['admin_uuid'] ?? '').toString().trim(),
      adminName: (data['admin_name'] ?? '').toString().trim(),
      status: (data['status'] ?? 'Registered').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'org_unique_id': orgUniqueId,
      'org_id': orgId,
      'org_name': orgName,
      'org_type': orgType,
      'org_address': orgAddress,
      'org_website': orgWebsite,
      'admin_uuid': adminUuid,
      'admin_name': adminName,
      'status': status,
    };
  }

  OrganizationItem copyWith({
    String? orgId,
    String? orgUniqueId,
    String? orgName,
    String? orgType,
    String? orgAddress,
    String? orgWebsite,
    String? adminUuid,
    String? adminName,
    String? status,
  }) {
    return OrganizationItem(
      orgId: orgId ?? this.orgId,
      orgUniqueId: orgUniqueId ?? this.orgUniqueId,
      orgName: orgName ?? this.orgName,
      orgType: orgType ?? this.orgType,
      orgAddress: orgAddress ?? this.orgAddress,
      orgWebsite: orgWebsite ?? this.orgWebsite,
      adminUuid: adminUuid ?? this.adminUuid,
      adminName: adminName ?? this.adminName,
      status: status ?? this.status,
    );
  }
}

class DepartmentMasterItem {
  final String orgId;
  final String deptId;
  final String deptUniqueId;          // Firestore document ID
  final String deptAccessCode;        // 4-digit registration code (stored as String)
  final String deptName;
  final String establishedYear;       // e.g. "2005"
  final String deptType;              // "Engineering" / "Management" / "Science"
  final List<String> programsOffered; // ["B.E", "M.Tech", "MCA"]
  final String affiliation;           // University / affiliation name
  final String accreditationStatus;   // "NBA" / "NAAC" / "NBA & NAAC" / "None"
  final String createdBy;

  const DepartmentMasterItem({
    required this.orgId,
    required this.deptId,
    this.deptUniqueId = '',
    this.deptAccessCode = '',
    required this.deptName,
    this.establishedYear = '',
    this.deptType = '',
    this.programsOffered = const [],
    this.affiliation = '',
    this.accreditationStatus = '',
    this.createdBy = '',
  });
  factory DepartmentMasterItem.fromMap(Map<String, dynamic> data, {String documentId = ''}) {
    final rawPrograms = data['programs_offered'];
    List<String> programs = [];
    if (rawPrograms is List) {
      programs = rawPrograms.map((e) => e.toString().trim()).toList();
    } else if (rawPrograms is String && rawPrograms.isNotEmpty) {
      programs = rawPrograms.split(',').map((e) => e.trim()).toList();
    }

    return DepartmentMasterItem(
      orgId: OrgField.readOrgId(data),
      deptId: OrgField.readDeptId(data),
      deptUniqueId: (data['dept_unique_id'] ?? documentId).toString().trim(),
      deptAccessCode: (data['dept_access_code'] ?? '').toString().trim(),
      deptName: (data['dept_name'] ?? data['department_name'] ?? '').toString().trim(),
      establishedYear: (data['established_year'] ?? '').toString().trim(),
      deptType: (data['dept_type'] ?? '').toString().trim(),
      programsOffered: programs,
      affiliation: (data['affiliation'] ?? '').toString().trim(),
      accreditationStatus: (data['accreditation_status'] ?? '').toString().trim(),
      createdBy: (data['created_by'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'org_id': orgId,
      'dept_id': deptId,
      'dept_unique_id': deptUniqueId,
      if (deptAccessCode.isNotEmpty) 'dept_access_code': deptAccessCode,
      'dept_name': deptName,
      'established_year': establishedYear,
      'dept_type': deptType,
      'programs_offered': programsOffered,
      'affiliation': affiliation,
      'accreditation_status': accreditationStatus,
      'created_by': createdBy,
    };
  }
}
