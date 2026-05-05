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

  bool get isRegisteredPending =>
      status.toLowerCase() == 'registered';

  String get normalizedRoleId => roleId.toUpperCase().trim();

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
  final String name;
  final String email;
  final String mobile;
  final String photoUrl;
  final String userType;
  final String roleId;
  final String orgId;
  final String requestedOrgId;
  final String requestedOrgName;
  final String status;
  final String requestedOn;
  final String deptId;

  const UserMasterItem({
    required this.uuid,
    required this.name,
    required this.email,
    required this.mobile,
    required this.photoUrl,
    required this.userType,
    required this.roleId,
    required this.orgId,
    required this.requestedOrgId,
    required this.requestedOrgName,
    required this.status,
    required this.requestedOn,
    this.deptId = '',
  });

  factory UserMasterItem.fromMap(Map<String, dynamic> data) {
    return UserMasterItem(
      uuid: (data['uuid'] ?? '').toString().trim(),
      name: (data['name'] ?? '').toString().trim(),
      email: (data['email'] ?? '').toString().trim(),
      mobile: (data['mobile'] ?? data['phone'] ?? '').toString().trim(),
      photoUrl: (data['photo_url'] ?? data['profile_pic'] ?? '')
          .toString()
          .trim(),
      userType: (data['user_type'] ?? data['designation'] ?? 'User')
          .toString()
          .trim(),
      roleId: (data['role_id'] ?? '').toString().trim(),
      orgId: (data['org_id'] ?? '').toString().trim(),
      requestedOrgId: (data['requested_org_id'] ?? data['org_id'] ?? '')
          .toString()
          .trim(),
      requestedOrgName: (data['requested_org_name'] ?? '').toString().trim(),
      status: (data['status'] ?? 'Pending').toString().trim(),
      requestedOn: (data['requested_on'] ?? data['created_at'] ?? '')
          .toString()
          .trim(),
      deptId: (data['dept_id'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uuid': uuid,
      'name': name,
      'email': email,
      'mobile': mobile,
      'photo_url': photoUrl,
      'user_type': userType,
      'role_id': roleId,
      'org_id': orgId,
      'requested_org_id': requestedOrgId,
      'requested_org_name': requestedOrgName,
      'status': status,
      'requested_on': requestedOn,
      'dept_id': deptId,
    };
  }


  UserMasterItem copyWith({
    String? uuid,
    String? name,
    String? email,
    String? mobile,
    String? photoUrl,
    String? userType,
    String? roleId,
    String? orgId,
    String? requestedOrgId,
    String? requestedOrgName,
    String? status,
    String? requestedOn,
    String? deptId,
  }) {
    return UserMasterItem(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      photoUrl: photoUrl ?? this.photoUrl,
      userType: userType ?? this.userType,
      roleId: roleId ?? this.roleId,
      orgId: orgId ?? this.orgId,
      requestedOrgId: requestedOrgId ?? this.requestedOrgId,
      requestedOrgName: requestedOrgName ?? this.requestedOrgName,
      status: status ?? this.status,
      requestedOn: requestedOn ?? this.requestedOn,
      deptId: deptId ?? this.deptId,
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
  final String deptName;
  final String establishedYear;       // e.g. "2005"
  final String deptType;              // "Engineering" / "Management" / "Science"
  final List<String> programsOffered; // ["B.E", "M.Tech", "MCA"]
  final String affiliation;           // University / affiliation name
  final String accreditationStatus;   // "NBA" / "NAAC" / "NBA & NAAC" / "None"

  const DepartmentMasterItem({
    required this.orgId,
    required this.deptId,
    this.deptUniqueId = '',
    required this.deptName,
    this.establishedYear = '',
    this.deptType = '',
    this.programsOffered = const [],
    this.affiliation = '',
    this.accreditationStatus = '',
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
      orgId: (data['org_id'] ?? '').toString().trim(),
      deptId: (data['dept_id'] ?? '').toString().trim(),
      deptUniqueId: (data['dept_unique_id'] ?? documentId).toString().trim(),
      deptName: (data['dept_name'] ?? data['department_name'] ?? '').toString().trim(),
      establishedYear: (data['established_year'] ?? '').toString().trim(),
      deptType: (data['dept_type'] ?? '').toString().trim(),
      programsOffered: programs,
      affiliation: (data['affiliation'] ?? '').toString().trim(),
      accreditationStatus: (data['accreditation_status'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'org_id': orgId,
      'dept_id': deptId,
      'dept_unique_id': deptUniqueId,
      'dept_name': deptName,
      'established_year': establishedYear,
      'dept_type': deptType,
      'programs_offered': programsOffered,
      'affiliation': affiliation,
      'accreditation_status': accreditationStatus,
    };
  }
}
