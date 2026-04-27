class OrgUserRoleMappingItem {
  final String uuid;
  final String orgId;
  final String roleId;
  final String name;

  const OrgUserRoleMappingItem({
    required this.uuid,
    required this.orgId,
    required this.roleId,
    required this.name,
  });

  factory OrgUserRoleMappingItem.fromMap(Map<String, dynamic> data) {
    return OrgUserRoleMappingItem(
      uuid: (data['uuid'] ?? '').toString().trim(),
      orgId: (data['org_id'] ?? '').toString().trim(),
      roleId: (data['role_id'] ?? '').toString().trim(),
      name: (data['name'] ?? '').toString().trim(),
    );
  }
}

class UserMasterItem {
  final String uuid;
  final String name;
  final String email;
  final String mobile;
  final String userType;
  final String roleId;
  final String orgId;
  final String requestedOrgId;
  final String requestedOrgName;
  final String status;
  final String requestedOn;

  const UserMasterItem({
    required this.uuid,
    required this.name,
    required this.email,
    required this.mobile,
    required this.userType,
    required this.roleId,
    required this.orgId,
    required this.requestedOrgId,
    required this.requestedOrgName,
    required this.status,
    required this.requestedOn,
  });

  factory UserMasterItem.fromMap(Map<String, dynamic> data) {
    return UserMasterItem(
      uuid: (data['uuid'] ?? '').toString().trim(),
      name: (data['name'] ?? '').toString().trim(),
      email: (data['email'] ?? '').toString().trim(),
      mobile: (data['mobile'] ?? data['phone'] ?? '').toString().trim(),
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
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uuid': uuid,
      'name': name,
      'email': email,
      'mobile': mobile,
      'user_type': userType,
      'role_id': roleId,
      'org_id': orgId,
      'requested_org_id': requestedOrgId,
      'requested_org_name': requestedOrgName,
      'status': status,
      'requested_on': requestedOn,
    };
  }

  UserMasterItem copyWith({
    String? uuid,
    String? name,
    String? email,
    String? mobile,
    String? userType,
    String? roleId,
    String? orgId,
    String? requestedOrgId,
    String? requestedOrgName,
    String? status,
    String? requestedOn,
  }) {
    return UserMasterItem(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      userType: userType ?? this.userType,
      roleId: roleId ?? this.roleId,
      orgId: orgId ?? this.orgId,
      requestedOrgId: requestedOrgId ?? this.requestedOrgId,
      requestedOrgName: requestedOrgName ?? this.requestedOrgName,
      status: status ?? this.status,
      requestedOn: requestedOn ?? this.requestedOn,
    );
  }
}

class OrganizationItem {
  final String orgId;
  final String orgCode;
  final String orgName;
  final String orgType;
  final String orgAddress;
  final String orgWebsite;
  final String adminUuid;
  final String adminName;
  final String status;

  const OrganizationItem({
    required this.orgId,
    required this.orgCode,
    required this.orgName,
    required this.orgType,
    required this.orgAddress,
    required this.orgWebsite,
    required this.adminUuid,
    required this.adminName,
    required this.status,
  });

  factory OrganizationItem.fromMap(Map<String, dynamic> data) {
    return OrganizationItem(
      orgId: (data['org_id'] ?? '').toString().trim(),
      orgCode: (data['org_code'] ?? '').toString().trim(),
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
      'org_id': orgId,
      'org_code': orgCode,
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
    String? orgCode,
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
      orgCode: orgCode ?? this.orgCode,
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

class MockMasterData {
  static final List<OrgUserRoleMappingItem> smcOrgUserRoleMapping =
      <OrgUserRoleMappingItem>[
        const OrgUserRoleMappingItem(
          uuid: '911234567890',
          orgId: 'SYSTEM',
          roleId: 'SYSTEM_ADMIN',
          name: 'Super User',
        ),
        const OrgUserRoleMappingItem(
          uuid: '911234567891',
          orgId: 'SJBIT',
          roleId: 'ORG_ADMIN',
          name: 'Siva Rama Krishna',
        ),
      ];

  static final List<UserMasterItem> smcUserMaster = <UserMasterItem>[
    const UserMasterItem(
      uuid: '911234567890',
      name: 'Super User',
      email: 'admin@smartcampus.ai',
      mobile: '+91 12345 67890',
      userType: 'Super Admin',
      roleId: 'SYSTEM_ADMIN',
      orgId: 'SYSTEM',
      requestedOrgId: 'SYSTEM',
      requestedOrgName: 'SmartCampus HQ',
      status: 'Approved',
      requestedOn: '20 May 2025\n09:00 AM',
    ),
    const UserMasterItem(
      uuid: '919876543210',
      name: 'Rohit Kumar',
      email: 'rohit.kumar@example.com',
      mobile: '+91 98765 43210',
      userType: 'Faculty',
      roleId: 'FACULTY',
      orgId: '',
      requestedOrgId: 'SJBIT',
      requestedOrgName: 'SJB Institute of Technology',
      status: 'Pending',
      requestedOn: '20 May 2025\n10:30 AM',
    ),
    const UserMasterItem(
      uuid: '919123456789',
      name: 'Anjali Sharma',
      email: 'anjali.sharma@example.com',
      mobile: '+91 91234 56789',
      userType: 'Student',
      roleId: 'STUDENT',
      orgId: '',
      requestedOrgId: 'SJBIT',
      requestedOrgName: 'SJB Institute of Technology',
      status: 'Pending',
      requestedOn: '20 May 2025\n09:15 AM',
    ),
    const UserMasterItem(
      uuid: '919988776655',
      name: 'Pankaj Mehta',
      email: 'pankaj.mehta@example.com',
      mobile: '+91 99887 76655',
      userType: 'Department Staff',
      roleId: 'STAFF',
      orgId: '',
      requestedOrgId: 'RND001',
      requestedOrgName: 'SmartLabs Research',
      status: 'Pending',
      requestedOn: '19 May 2025\n04:45 PM',
    ),
  ];

  static final List<OrganizationItem> smcOrganisationMaster =
      <OrganizationItem>[
        const OrganizationItem(
          orgId: 'SJBIT',
          orgCode: 'SC100001',
          orgName: 'SJB Institute of Technology',
          orgType: 'College',
          orgAddress: 'Kengeri, Bengaluru',
          orgWebsite: 'https://www.sjbit.edu.in',
          adminUuid: '911234567891',
          adminName: 'Siva Rama Krishna',
          status: 'Registered',
        ),
        const OrganizationItem(
          orgId: 'RND001',
          orgCode: 'SC100002',
          orgName: 'SmartLabs Research',
          orgType: 'Research Institute',
          orgAddress: 'Mysuru, Karnataka',
          orgWebsite: 'https://smartlabs.example.com',
          adminUuid: '911234567999',
          adminName: 'Asha Nair',
          status: 'Registered',
        ),
      ];
}
