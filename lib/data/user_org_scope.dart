import 'package:smartcampus/data/org_field.dart';
import 'package:smartcampus/data/mock_master_data.dart';

/// Tenant scope for a signed-in user — sourced from [smcUserMaster].
class UserOrgScope {
  final String orgId;
  final String deptId;

  const UserOrgScope({
    required this.orgId,
    required this.deptId,
  });

  factory UserOrgScope.fromUser(UserMasterItem user) {
    return UserOrgScope(
      orgId: OrgField.normalize(user.orgId),
      deptId: OrgField.normalize(user.deptId),
    );
  }

  bool get hasOrg => orgId.isNotEmpty;

  bool get hasDept => deptId.isNotEmpty;
}
