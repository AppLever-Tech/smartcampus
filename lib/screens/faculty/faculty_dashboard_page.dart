import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/data/mock_master_data.dart';
import 'package:smartcampus/data/org_field.dart';
import 'package:smartcampus/data/user_org_scope.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/screens/auth/landing_page.dart';
import 'package:smartcampus/screens/faculty/faculty_dashboard_mobile_layout.dart';
import 'package:smartcampus/screens/faculty/faculty_profile_not_found_page.dart';
import 'package:smartcampus/screens/shared/person_detail_page.dart';
import 'package:smartcampus/services/course_firestore_service.dart';
import 'package:smartcampus/services/faculty_firestore_service.dart';
import 'package:smartcampus/services/org_role_firestore_service.dart';
import 'package:smartcampus/services/user_master_firestore_service.dart';
import 'package:smartcampus/widgets/profile_photo_avatar.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class FacultyDashboardPage extends StatefulWidget {
  final String orgId;
  final String deptId;
  final String displayName;
  final String uuid;
  final FacultyModel? faculty;

  const FacultyDashboardPage({
    super.key,
    required this.orgId,
    this.deptId = '',
    required this.displayName,
    required this.uuid,
    this.faculty,
  });

  @override
  State<FacultyDashboardPage> createState() => _FacultyDashboardPageState();
}

class _FacultyDashboardPageState extends State<FacultyDashboardPage> {
  final OrgRoleFirestoreService roleService = OrgRoleFirestoreService();
  final FacultyFirestoreService facultyService = FacultyFirestoreService();
  final CourseFirestoreService courseService = CourseFirestoreService();
  final UserMasterFirestoreService userMasterService =
      UserMasterFirestoreService();

  UserOrgScope? _orgScope;
  StreamSubscription<List<CourseModel>>? _courseSubscription;

  String get scopedOrgId =>
      _orgScope?.orgId ?? OrgField.normalize(widget.orgId);

  String get scopedDeptId =>
      _orgScope?.deptId ?? OrgField.normalize(widget.deptId);

  bool loading = true;
  int selectedMenuIndex = 0;
  bool sidebarExpanded = false;

  FacultyModel? facultyProfile;
  List<CourseModel> allCourses = [];
  List<DepartmentMasterItem> _departments = const [];
  String organizationDisplayName = '';
  String departmentDisplayName = '';

  List<CourseModel> get assignedCourses {
    if (facultyProfile == null) {
      return const [];
    }
    return CourseFirestoreService.filterCoursesForFaculty(
      allCourses,
      facultyProfile!,
    );
  }

  String _resolveOrgId({
    UserOrgScope? scope,
    FacultyModel? faculty,
  }) {
    return _firstNonEmpty([
      scope?.orgId ?? _orgScope?.orgId ?? '',
      faculty?.orgId ?? facultyProfile?.orgId ?? '',
      widget.faculty?.orgId ?? '',
      widget.orgId,
    ]);
  }

  String _firstNonEmpty(Iterable<String> values) {
    for (final value in values) {
      final normalized = OrgField.normalize(value);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  String _departmentLabelFromOrgDepartments() {
    if (_departments.isEmpty) {
      return '';
    }
    if (_departments.length == 1) {
      final dept = _departments.first;
      return dept.deptName.isNotEmpty ? dept.deptName : dept.deptId;
    }

    final names = _departments
        .map((dept) => dept.deptName.isNotEmpty ? dept.deptName : dept.deptId)
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return names.join(', ');
  }

  String _resolveDepartmentLabel() {
    if (departmentDisplayName.trim().isNotEmpty) {
      return departmentDisplayName.trim();
    }
    return _departmentLabelFromOrgDepartments();
  }

  void _syncDepartmentDisplayName() {
    if (departmentDisplayName.trim().isNotEmpty) {
      return;
    }
    final label = _resolveDepartmentLabel();
    if (label.isNotEmpty) {
      departmentDisplayName = label;
    }
  }

  String get _dashboardDepartmentLabel => _resolveDepartmentLabel();

  void _bindScopedCourseListener() {
    _courseSubscription?.cancel();
    final scope = _orgScope;
    if (scope == null || !scope.hasOrg) {
      return;
    }
    _courseSubscription = courseService
        .getCoursesForOrg(orgId: scope.orgId)
        .listen((courses) {
      if (!mounted) {
        return;
      }
      setState(() {
        allCourses = courses;
        _syncDepartmentDisplayName();
      });
    });
  }

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    _courseSubscription?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      final rawScope = await userMasterService.resolveOrgScopeForSignedInUser() ??
          UserOrgScope(
            orgId: OrgField.normalize(widget.orgId),
            deptId: OrgField.normalize(widget.deptId),
          );

      final resolvedFaculty = await facultyService.resolveFacultyForUser(
        orgId: _resolveOrgId(scope: rawScope, faculty: widget.faculty),
        deptId: '',
        displayName: widget.displayName,
        uuid: widget.uuid,
        prefetched: widget.faculty,
      );

      final String orgId = _resolveOrgId(
        scope: rawScope,
        faculty: resolvedFaculty,
      );
      final scope = UserOrgScope(orgId: orgId, deptId: '');
      _orgScope = scope;
      _bindScopedCourseListener();

      final org =
          await roleService.authService.getOrganizationById(scope.orgId);
      final departments = await roleService.loadDepartmentsForOrg(scope.orgId);
      if (!mounted) {
        return;
      }
      setState(() {
        facultyProfile = resolvedFaculty;
        _departments = departments;
        organizationDisplayName = (org?.orgName ?? '').trim().isEmpty
            ? scope.orgId
            : org!.orgName;
        departmentDisplayName = '';
        _syncDepartmentDisplayName();
        loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => loading = false);
    }
  }

  Future<void> onLogout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const smcText(
          textToDisplay: 'Logout',
          textSize: 18,
          textBoldness: 4,
          colorOfText: ColorConst.textPrimary,
        ),
        content: const smcText(
          textToDisplay: 'Are you sure you want to logout?',
          textSize: 14,
          colorOfText: ColorConst.textSecondary,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const smcText(
              textToDisplay: 'No',
              textSize: 14,
              textBoldness: 3,
              colorOfText: ColorConst.textSecondary,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const smcText(
              textToDisplay: 'Yes',
              textSize: 14,
              textBoldness: 4,
              colorOfText: ColorConst.primaryBlue,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await FirebaseAuth.instance.signOut();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LandingPage()),
      (route) => false,
    );
  }

  static const double _mobileLayoutBreakpoint = 768;

  bool _isMobileLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width < _mobileLayoutBreakpoint;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF6F7FB),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (facultyProfile == null) {
      return FacultyProfileNotFoundPage(onLogout: onLogout);
    }

    final faculty = facultyProfile!;

    if (_isMobileLayout(context)) {
      return FacultyDashboardMobileLayout(
        selectedIndex: selectedMenuIndex,
        onIndexChanged: (index) => setState(() => selectedMenuIndex = index),
        onLogout: onLogout,
        faculty: faculty,
        displayName: widget.displayName,
        dashboardContent: _buildDashboardView(),
        profileContent: _buildProfileView(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Row(
          children: [
            _buildSidebar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildSelectedView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedView() {
    if (selectedMenuIndex == 1) {
      return _buildProfileView();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDashboardView(),
      ],
    );
  }

  Widget _buildDashboardView() {
    final courses = assignedCourses;
    final totalCredits = courses.fold<int>(
      0,
      (sum, course) => sum + (int.tryParse(course.credits) ?? 0),
    );
    final String welcomeName =
        (facultyProfile?.fullName ?? '').trim().isNotEmpty
            ? facultyProfile!.fullName
            : widget.displayName;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isMobileLayout(context)) ...[
            smcText(
              textToDisplay: 'Welcome, $welcomeName',
              textSize: 20,
              textBoldness: 5,
              colorOfText: ColorConst.textPrimary,
            ),
            if (_dashboardDepartmentLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              smcText(
                textToDisplay: _dashboardDepartmentLabel,
                textSize: 13,
                colorOfText: ColorConst.textSecondary,
              ),
            ],
          ] else if (_dashboardDepartmentLabel.isNotEmpty)
            smcText(
              textToDisplay: _dashboardDepartmentLabel,
              textSize: 13,
              colorOfText: ColorConst.textSecondary,
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              const smcText(
                textToDisplay: 'Faculty Overview',
                textSize: 16,
                textBoldness: 5,
                colorOfText: ColorConst.textPrimary,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  width: 1,
                  height: 18,
                  color: const Color(0xFFD8E2F4),
                ),
              ),
              const smcText(
                textToDisplay: 'ID: ',
                textSize: 14,
                colorOfText: ColorConst.textSecondary,
              ),
              Flexible(
                child: smcText(
                  textToDisplay:
                      (facultyProfile?.facultyId ?? '').trim().isEmpty
                          ? '—'
                          : facultyProfile!.facultyId,
                  textSize: 14,
                  textBoldness: 5,
                  colorOfText: ColorConst.textPrimary,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isMobileLayout(context)) ...[
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Assigned\nCourses',
                    count: courses.length.toString(),
                    icon: Icons.menu_book_rounded,
                    color: ColorConst.primaryBlue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: 'Total\nCredits',
                    count: totalCredits.toString(),
                    icon: Icons.star_outline_rounded,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Assigned\nCourses',
                    count: courses.length.toString(),
                    icon: Icons.menu_book_rounded,
                    color: ColorConst.primaryBlue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: 'Total\nCredits',
                    count: totalCredits.toString(),
                    icon: Icons.star_outline_rounded,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: 'Organization',
                    count: organizationDisplayName,
                    icon: Icons.apartment_rounded,
                    color: Colors.orange,
                    compactValue: true,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          const smcText(
            textToDisplay: 'Events & Announcements',
            textSize: 16,
            textBoldness: 5,
            colorOfText: ColorConst.textPrimary,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3EAF8)),
            ),
            child: const smcText(
              textToDisplay:
                  'No events & announcements currently available',
              textSize: 14,
              colorOfText: ColorConst.textSecondary,
              maxLines: 3,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileView() {
    final faculty = facultyProfile!;

    return PersonDetailPage(
      key: ValueKey<String>(
        faculty.documentId?.isNotEmpty == true
            ? faculty.documentId!
            : faculty.facultyId,
      ),
      person: faculty,
      isStudent: false,
      embedded: true,
      embeddedMaximized: true,
      showLeadingAction: false,
      showEmbeddedHeader: !_isMobileLayout(context),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    bool compactValue = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF8)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                smcText(
                  textToDisplay: title,
                  textSize: 13,
                  colorOfText: ColorConst.textSecondary,
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                smcText(
                  textToDisplay: count,
                  textSize: compactValue ? 14 : 22,
                  textBoldness: 5,
                  colorOfText: ColorConst.textPrimary,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarProfileAvatar({required double radius}) {
    final faculty = facultyProfile;
    final String name = faculty?.fullName ?? widget.displayName;
    final String initial = name.trim().isEmpty
        ? 'F'
        : name.trim().substring(0, 1).toUpperCase();
    final String photoUrl = normalizeProfilePhotoUrl(
      faculty?.photographUrl ?? '',
    );

    return ProfilePhotoAvatar(
      photoUrl: photoUrl,
      fallbackInitial: initial,
      radius: radius,
    );
  }

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: sidebarExpanded ? 240 : 84,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE3EAF8))),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: sidebarExpanded
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (sidebarExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Row(
                  children: [
                    _buildSidebarProfileAvatar(radius: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          smcText(
                            textToDisplay:
                                'Welcome, ${(facultyProfile?.fullName ?? '').trim().isNotEmpty ? facultyProfile!.fullName : widget.displayName}',
                            textSize: 14,
                            textBoldness: 5,
                            colorOfText: ColorConst.textPrimary,
                            maxLines: 1,
                          ),
                          const smcText(
                            textToDisplay: 'Faculty Portal',
                            textSize: 12,
                            colorOfText: ColorConst.textSecondary,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      tooltip: 'Collapse menu',
                      color: ColorConst.textSecondary,
                      onPressed: () => setState(() => sidebarExpanded = false),
                    ),
                  ],
                ),
              )
            else ...[
              _buildSidebarProfileAvatar(radius: 24),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Expand menu',
                color: ColorConst.primaryBlue,
                onPressed: () => setState(() => sidebarExpanded = true),
              ),
            ],
            const SizedBox(height: 8),
            _menuTile(
              title: 'Dashboard',
              icon: Icons.dashboard_outlined,
              isSelected: selectedMenuIndex == 0,
              onTap: () => setState(() => selectedMenuIndex = 0),
            ),
            const SizedBox(height: 8),
            _menuTile(
              title: 'Profile',
              icon: Icons.person_outline_rounded,
              isSelected: selectedMenuIndex == 1,
              onTap: () => setState(() => selectedMenuIndex = 1),
            ),
            const Spacer(),
            _menuTile(
              title: 'Logout',
              icon: Icons.logout_rounded,
              isSelected: false,
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final Color iconColor =
        isSelected ? ColorConst.primaryBlue : ColorConst.textSecondary;
    final Color textColor =
        isSelected ? ColorConst.primaryBlue : ColorConst.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: sidebarExpanded ? 42 : 58,
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: sidebarExpanded ? 12 : 4,
          vertical: sidebarExpanded ? 0 : 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF0FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: sidebarExpanded
            ? Row(
                children: [
                  Icon(icon, size: 18, color: iconColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: smcText(
                      textToDisplay: title,
                      textSize: 14,
                      textBoldness: isSelected ? 4 : 3,
                      colorOfText: textColor,
                      maxLines: 1,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: iconColor),
                  const SizedBox(height: 4),
                  smcText(
                    textToDisplay: title.split(' ').first,
                    textSize: 10,
                    textBoldness: isSelected ? 4 : 3,
                    colorOfText: textColor,
                    maxLines: 1,
                  ),
                ],
              ),
      ),
    );
  }
}
