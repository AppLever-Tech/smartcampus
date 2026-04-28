import 'package:flutter/material.dart';
import 'package:smartcampus/data/mock_master_data.dart';
import 'package:smartcampus/screens/dept_admin_dashboard_page.dart';
import 'package:smartcampus/screens/org_admin_dashboard_page.dart';
import 'package:smartcampus/screens/profile_pending_approval_page.dart';
import 'package:smartcampus/screens/register_page.dart';
import 'package:smartcampus/screens/system_admin_home_page.dart';
import 'package:smartcampus/services/firebase_auth_service.dart';
import 'package:smartcampus/services/org_role_firestore_service.dart';

class ScreenBrancher extends StatelessWidget {
  final String uuid;

  const ScreenBrancher({super.key, required this.uuid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: resolveHomeWidget(uuid),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data ?? RegisterPage(uuid: uuid);
      },
    );
  }
}

Future<Widget> resolveHomeWidget(String uuid) async {
  final OrgRoleFirestoreService roleService = OrgRoleFirestoreService();
  final FirebaseAuthService authService = FirebaseAuthService();

  final List<OrgUserRoleMappingItem> mappings =
      await roleService.getAllRoleMappingsForUuid(uuid);

  if (mappings.isNotEmpty) {
    final OrgUserRoleMappingItem primary = roleService.pickPrimaryRole(mappings);
    if (primary.isRegisteredPending) {
      final UserMasterItem? user = await authService.getUserByUuid(uuid);
      final String displayName = primary.name.isNotEmpty
          ? primary.name
          : (user?.name ?? 'User');
      return ProfilePendingApprovalPage(
        displayName: displayName,
        user: user,
      );
    }

    switch (primary.normalizedRoleId) {
      case 'SYSTEM_ADMIN':
        return SystemAdminHomePage(
          systemAdminName: primary.name,
        );
      case 'ORG_ADMIN':
        return OrgAdminDashboardPage(
          orgId: primary.orgId,
          adminName: primary.name,
        );
      case 'DEPT_ADMIN':
        return DeptAdminDashboardPage(
          orgId: primary.orgId,
          adminName: primary.name,
        );
      default:
        return RegisterPage(uuid: uuid);
    }
  }

  final UserMasterItem? userMaster = await authService.getUserByUuid(uuid);
  if (userMaster != null &&
      (userMaster.status == 'Registered' ||
          userMaster.status == 'Pending')) {
    return RegistrationPendingPage(user: userMaster);
  }

  return RegisterPage(uuid: uuid);
}
