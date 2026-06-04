import 'package:flutter/material.dart';
import 'package:smartcampus/data/mock_master_data.dart';
import 'package:smartcampus/screens/auth/register_page.dart';
import 'package:smartcampus/screens/dept_admin/dept_admin_dashboard_page.dart';
import 'package:smartcampus/screens/faculty/faculty_dashboard_page.dart';
import 'package:smartcampus/screens/org_admin/org_admin_dashboard_page.dart';
import 'package:smartcampus/screens/system_admin/system_admin_home_page.dart';
import 'package:smartcampus/services/faculty_firestore_service.dart';
import 'package:smartcampus/services/firebase_auth_service.dart';
import 'package:smartcampus/services/user_master_firestore_service.dart';

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
  final FirebaseAuthService authService = FirebaseAuthService();
  final FacultyFirestoreService facultyService = FacultyFirestoreService();
  final UserMasterFirestoreService userMasterService =
      UserMasterFirestoreService(authService: authService);

  final UserMasterItem? userMaster = await userMasterService.getByUuid(uuid);
  if (userMaster != null) {
    if (userMaster.isPendingApproval) {
      return RegistrationPendingPage(user: userMaster);
    }

    switch (userMaster.normalizedUserRole) {
      case 'SYSTEM_ADMIN':
        return SystemAdminHomePage(
          systemAdminName: userMaster.displayName,
        );
      case 'ORG_ADMIN':
        return OrgAdminDashboardPage(
          orgId: userMaster.orgId,
          adminName: userMaster.displayName,
        );
      case 'DEPT_ADMIN':
        return DeptAdminDashboardPage(
          orgId: userMaster.orgId,
          adminName: userMaster.displayName,
          deptId: userMaster.deptId,
        );
      case 'FACULTY':
        return FacultyDashboardPage(
          orgId: userMaster.orgId,
          deptId: userMaster.deptId,
          displayName: userMaster.displayName,
          uuid: uuid,
        );
      case 'STUDENT':
        if (!userMaster.isApproved) {
          return RegistrationPendingPage(user: userMaster);
        }
        return RegistrationPendingPage(
          user: userMaster.copyWith(
            requestedOrgName: 'Student portal coming soon. Complete your profile after admin approval.',
          ),
        );
      case 'UNCLASSIFIED':
        if (!userMaster.isApproved) {
          return RegistrationPendingPage(user: userMaster);
        }
        return RegistrationPendingPage(
          user: userMaster.copyWith(
            requestedOrgName:
                'Your account is approved. A department admin will classify you as Student or Faculty shortly.',
          ),
        );
    }
  }

  final facultyByMobile = await facultyService.getFacultyByMobile(uuid);
  if (facultyByMobile != null) {
    return FacultyDashboardPage(
      orgId: facultyByMobile.orgId,
      deptId: facultyByMobile.deptId,
      displayName: facultyByMobile.fullName,
      uuid: uuid,
      faculty: facultyByMobile,
    );
  }

  return RegisterPage(uuid: uuid);
}
