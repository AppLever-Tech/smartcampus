import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/data/mock_master_data.dart';
import 'package:smartcampus/data/org_field.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/data/user_org_scope.dart';
import 'package:smartcampus/models/assessment_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/screens/auth/landing_page.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_block_record.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_day.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_block_firestore_service.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_settings_firestore_service.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_classes_page.dart';
import 'package:smartcampus/screens/faculty/faculty_dashboard_mobile_layout.dart';
import 'package:smartcampus/screens/faculty/faculty_profile_not_found_page.dart';
import 'package:smartcampus/screens/faculty/faculty_proctoring_page.dart';
import 'package:smartcampus/screens/faculty/faculty_upcoming_classes.dart';
import 'package:smartcampus/screens/shared/person_detail_page.dart';
import 'package:smartcampus/services/assessment_firestore_service.dart';
import 'package:smartcampus/services/course_firestore_service.dart';
import 'package:smartcampus/services/faculty_firestore_service.dart';
import 'package:smartcampus/services/org_role_firestore_service.dart';
import 'package:smartcampus/services/user_master_firestore_service.dart';
import 'package:smartcampus/widgets/app_info_dialog.dart';
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
  final TimeBlockFirestoreService timeBlockService = TimeBlockFirestoreService();
  final TimeTableSettingsFirestoreService timeTableSettingsService =
      TimeTableSettingsFirestoreService();
  final AssessmentFirestoreService assessmentService =
      AssessmentFirestoreService();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  UserOrgScope? _orgScope;
  StreamSubscription<List<CourseModel>>? _courseSubscription;
  StreamSubscription<List<TimeBlockRecord>>? _timeBlockSubscription;
  StreamSubscription<Map<String, dynamic>?>? _timeTableSettingsSubscription;
  StreamSubscription<List<AssessmentModel>>? _assessmentSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _studentSubscription;

  String get scopedOrgId =>
      _orgScope?.orgId ?? OrgField.normalize(widget.orgId);

  String get scopedDeptId =>
      _orgScope?.deptId ?? OrgField.normalize(widget.deptId);

  bool loading = true;
  int selectedMenuIndex = 0;
  int selectedAssessmentSubIndex = 0;
  bool assessmentsExpanded = true;
  bool sidebarExpanded = false;

  FacultyModel? facultyProfile;
  List<CourseModel> allCourses = [];
  List<TimeBlockRecord> allTimeBlocks = [];
  List<TimeTableDay> timetableDays = const [];
  List<DepartmentMasterItem> _departments = const [];
  String departmentDisplayName = '';
  List<AssessmentModel> assessments = [];
  List<Map<String, dynamic>> students = [];

  List<CourseModel> get assignedCourses {
    if (facultyProfile == null) {
      return const [];
    }
    return CourseFirestoreService.filterCoursesForFaculty(
      allCourses,
      facultyProfile!,
    );
  }

  int get upcomingClassesCount {
    final faculty = facultyProfile;
    if (faculty == null) {
      return 0;
    }
    return FacultyUpcomingClasses.countForNextFiveDays(
      timeBlocks: allTimeBlocks,
      assignedCourses: assignedCourses,
      faculty: faculty,
      timetableDays: timetableDays,
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

  void _bindScopedTimeBlockListener() {
    _timeBlockSubscription?.cancel();
    final scope = _orgScope;
    if (scope == null || !scope.hasOrg) {
      return;
    }
    _timeBlockSubscription = timeBlockService
        .watchTimeBlocksForOrg(orgId: scope.orgId)
        .listen((blocks) {
      if (!mounted) {
        return;
      }
      setState(() => allTimeBlocks = blocks);
    });
  }

  void _bindScopedTimeTableSettingsListener() {
    _timeTableSettingsSubscription?.cancel();
    final scope = _orgScope;
    if (scope == null || !scope.hasOrg) {
      return;
    }
    _timeTableSettingsSubscription = timeTableSettingsService
        .watchSettings(orgId: scope.orgId)
        .listen((settings) {
      if (!mounted) {
        return;
      }
      setState(
        () => timetableDays = timeTableSettingsService.parseDays(settings),
      );
    });
  }

  void _bindAssessmentListener() {
    _assessmentSubscription?.cancel();
    final faculty = facultyProfile;
    // Use facultyId if available, otherwise fall back to userId from Firebase Auth
    final facultyId = faculty?.facultyId.isNotEmpty == true 
        ? faculty!.facultyId 
        : FirebaseAuth.instance.currentUser?.uid ?? '';
    
    if (facultyId.isEmpty) {
      return;
    }
    _assessmentSubscription = assessmentService
        .getAssessmentsForFaculty(facultyId: facultyId)
        .listen((list) {
      if (!mounted) return;
      setState(() => assessments = list);
    });
  }

  void _bindStudentsListener() {
    _studentSubscription?.cancel();
    final scope = _orgScope;
    if (scope == null || !scope.hasOrg) return;
    _studentSubscription = firestore
        .collection('smcStudentMaster')
        .where('org_id', isEqualTo: scope.orgId)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList())
        .listen((list) {
      if (!mounted) return;
      setState(() => students = list);
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
    _timeBlockSubscription?.cancel();
    _timeTableSettingsSubscription?.cancel();
    _assessmentSubscription?.cancel();
    _studentSubscription?.cancel();
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

      // Get deptId from the resolved faculty profile!
      final String deptId = resolvedFaculty?.deptId ?? OrgField.normalize(widget.deptId);
      final scope = UserOrgScope(orgId: orgId, deptId: deptId);
      _orgScope = scope;

      facultyProfile = resolvedFaculty;

      _bindScopedCourseListener();
      _bindScopedTimeBlockListener();
      _bindScopedTimeTableSettingsListener();
      _bindAssessmentListener();
      _bindStudentsListener();

      final departments = await roleService.loadDepartmentsForOrg(scope.orgId);
      if (!mounted) {
        return;
      }
      setState(() {
        _departments = departments;
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
        classesContent: _buildClassesView(),
        profileContent: _buildProfileView(),
        proctoringContent: _buildProctoringView(),
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
    switch (selectedMenuIndex) {
      case 1:
        return _buildProfileView();
      case 2:
        return _buildClassesView();
      case 3:
        return _buildProctoringView();
      case 4:
        return _buildAssessmentsView();
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDashboardView(),
          ],
        );
    }
  }

  Widget _buildProctoringView() {
    return FacultyProctoringPage(
      orgId: scopedOrgId,
      deptId: scopedDeptId,
      faculty: facultyProfile!,
    );
  }

  Widget _buildClassesView() {
    return FacultyClassesPage(
      orgId: scopedOrgId,
      faculty: facultyProfile!,
      assignedCourses: assignedCourses,
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: _buildStatCard(
                title: 'Upcoming\nClasses',
                count: upcomingClassesCount.toString(),
                icon: Icons.calendar_today_rounded,
                color: Colors.orange,
              ),
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
                    title: 'Upcoming\nClasses',
                    count: upcomingClassesCount.toString(),
                    icon: Icons.calendar_today_rounded,
                    color: Colors.orange,
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
              color: color.withValues(alpha: 0.12),
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
            const SizedBox(height: 8),
            _menuTile(
              title: 'Classes',
              icon: Icons.class_outlined,
              isSelected: selectedMenuIndex == 2,
              onTap: () => setState(() => selectedMenuIndex = 2),
            ),
            const SizedBox(height: 8),
            _menuTile(
              title: 'Proctoring',
              icon: Icons.supervisor_account_outlined,
              isSelected: selectedMenuIndex == 3,
              onTap: () => setState(() => selectedMenuIndex = 3),
            ),
            const SizedBox(height: 8),
            _menuTile(
              title: 'Assessments',
              icon: Icons.assessment_outlined,
              isSelected: selectedMenuIndex == 4,
              expanded: sidebarExpanded ? assessmentsExpanded : null,
              onTap: () => setState(() {
                selectedMenuIndex = 4;
                if (sidebarExpanded) {
                  assessmentsExpanded = !assessmentsExpanded;
                } else {
                  assessmentsExpanded = true;
                  selectedAssessmentSubIndex = 1; // Default to My Assessments when collapsed
                }
              }),
            ),
            if (sidebarExpanded &&
                selectedMenuIndex == 4 &&
                assessmentsExpanded) ...[
              const SizedBox(height: 4),
              _subMenuItem(
                title: 'Create Assessment',
                isSelected: selectedAssessmentSubIndex == 0,
                onTap: () => setState(() => selectedAssessmentSubIndex = 0),
              ),
              const SizedBox(height: 4),
              _subMenuItem(
                title: 'My Assessments',
                isSelected: selectedAssessmentSubIndex == 1,
                onTap: () => setState(() => selectedAssessmentSubIndex = 1),
              ),
              const SizedBox(height: 4),
              _subMenuItem(
                title: 'Manage Marks',
                isSelected: selectedAssessmentSubIndex == 2,
                onTap: () => setState(() => selectedAssessmentSubIndex = 2),
              ),
              const SizedBox(height: 4),
            ],
            const Spacer(),
            _menuTile(
              title: 'Version',
              icon: Icons.info_outline_rounded,
              isSelected: false,
              onTap: () => AppInfoDialog.show(context),
            ),
            const SizedBox(height: 8),
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
    bool? expanded,
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
                  if (expanded != null)
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_right_rounded,
                      size: 18,
                      color: ColorConst.textSecondary,
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

  Widget _subMenuItem({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final Color textColor =
        isSelected ? ColorConst.primaryBlue : ColorConst.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF0FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: smcText(
          textToDisplay: title,
          textSize: 13,
          textBoldness: isSelected ? 4 : 3,
          colorOfText: textColor,
          maxLines: 1,
        ),
      ),
    );
  }

  Widget _buildAssessmentsView() {
    switch (selectedAssessmentSubIndex) {
      case 1:
        return _buildViewAssessments();
      case 2:
        return _buildManageMarks();
      default:
        return _buildCreateAssessment();
    }
  }

  // ====== ASSESSMENT FORM STATE ======
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _totalMarksCtrl = TextEditingController(text: '100');
  final _descriptionCtrl = TextEditingController();
  String _selectedAssessmentType = '';
  String _selectedScheme = '';
  String _selectedSemester = '';
  String _selectedCourseId = '';
  DateTime? _selectedDueDate;
  bool _allStudentsInSection = true;
  List<String> _selectedStudentIds = [];
  List<String> _attachmentUrls = [];
  List<String> _attachmentNames = [];
  bool _allowLateSubmission = false;
  bool _showMarksToStudents = true;
  String _studentSearchQuery = '';

  void _resetAssessmentForm() {
    _formKey.currentState?.reset();
    _titleCtrl.clear();
    _totalMarksCtrl.text = '100';
    _descriptionCtrl.clear();
    _selectedAssessmentType = '';
    _selectedScheme = '';
    _selectedSemester = '';
    _selectedCourseId = '';
    _selectedDueDate = null;
    _allStudentsInSection = true;
    _selectedStudentIds = [];
    _attachmentUrls = [];
    _attachmentNames = [];
    _allowLateSubmission = false;
    _showMarksToStudents = true;
    _studentSearchQuery = '';
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  String _formatDateFromIso(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return _formatDate(d);
    } catch (_) {
      return iso;
    }
  }

  String _formatSchemeForDisplay(String scheme) {
    if (scheme.isEmpty) return '';
    // Extract just the year for display
    return _extractSchemeYear(scheme);
  }

  List<Map<String, dynamic>> _studentsForSchemeSemesterCourse() {
    // Filter students based on scheme, semester, and course enrollment
    return students.where((s) {
      // Check if student matches the selected scheme and semester
      final studentBatch = (s['batch'] ?? '').toString();
      final studentSemester = (s['current_semester'] ?? s['currentSemester'] ?? '').toString();
      
      // Check if student batch starts with selected scheme year
      // e.g., scheme "2024" should match student batch "2024-2026"
      if (_selectedScheme.isNotEmpty && !studentBatch.startsWith(_selectedScheme)) {
        return false;
      }
      
      if (_selectedSemester.isNotEmpty && studentSemester != _selectedSemester) {
        return false;
      }
      
      // Check if student is enrolled in the selected course (if course is selected)
      if (_selectedCourseId.isNotEmpty) {
        final enrolledCourseMarks = s['enrolled_course_marks'] ?? s['enrolledCourseMarks'];
        if (enrolledCourseMarks == null || enrolledCourseMarks is! Map) {
          return false;
        }
        return enrolledCourseMarks.containsKey(_selectedCourseId);
      }
      
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> _studentsForSection(String section) {
    // Legacy method for backward compatibility with existing assessments
    // Filter students enrolled in the selected course
    if (_selectedCourseId.isEmpty) {
      return students;
    }
    
    return students.where((s) {
      final enrolledCourseMarks = s['enrolled_course_marks'] ?? s['enrolledCourseMarks'];
      if (enrolledCourseMarks == null || enrolledCourseMarks is! Map) {
        return false;
      }
      return enrolledCourseMarks.containsKey(_selectedCourseId);
    }).toList();
  }

  List<Map<String, dynamic>> _getFilteredStudents() {
    var filtered = _studentsForSchemeSemesterCourse();
    
    // Apply search filter if query is not empty
    if (_studentSearchQuery.isNotEmpty) {
      final query = _studentSearchQuery.toLowerCase();
      filtered = filtered.where((s) {
        final name = (s['full_name'] ?? s['fullName'] ?? s['name'] ?? '').toString().toLowerCase();
        final usn = (s['USN'] ?? s['usn'] ?? s['student_id'] ?? s['studentId'] ?? '').toString().toLowerCase();
        return name.contains(query) || usn.contains(query);
      }).toList();
    }
    
    return filtered;
  }

  List<String> _getAvailableSchemes() {
    // Extract unique scheme years from batch data (e.g., "2024-2026" -> "2024")
    final studentBatches = students
        .map((s) => _extractSchemeYear((s['batch'] ?? '').toString()))
        .where((b) => b.isNotEmpty)
        .toSet();
    
    final courseBatches = assignedCourses
        .map((c) => _extractSchemeYear(c.batch))
        .where((b) => b.isNotEmpty)
        .toSet();
    
    final schemes = {...studentBatches, ...courseBatches}.toList();
    schemes.sort();
    return schemes;
  }

  String _extractSchemeYear(String batch) {
    if (batch.isEmpty) return '';
    
    // If batch is already a single year (e.g., "2024"), return it
    if (RegExp(r'^\d{4}$').hasMatch(batch)) {
      return batch;
    }
    
    // If batch is a range (e.g., "2024-2026"), extract the starting year
    if (batch.contains('-')) {
      final parts = batch.split('-');
      if (parts.isNotEmpty && RegExp(r'^\d{4}$').hasMatch(parts[0])) {
        return parts[0];
      }
    }
    
    // Try to extract any 4-digit year from the string
    final yearMatch = RegExp(r'\d{4}').firstMatch(batch);
    if (yearMatch != null) {
      return yearMatch.group(0) ?? '';
    }
    
    return '';
  }

  List<CourseModel> _getFilteredCourses() {
    // Filter courses based on selected scheme and semester
    if (_selectedScheme.isEmpty || _selectedSemester.isEmpty) {
      return []; // Return empty list if scheme/semester not selected
    }
    
    return assignedCourses.where((c) {
      // Check if course batch starts with the selected scheme year
      // e.g., scheme "2024" should match course batch "2024-2026"
      final batchMatch = c.batch.startsWith(_selectedScheme);
      final semesterMatch = c.semester.toLowerCase() == _selectedSemester.toLowerCase();
      return batchMatch && semesterMatch;
    }).toList();
  }

  Future<void> _uploadAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileName = file.name;
        final bytes = file.bytes;
        
        if (bytes != null) {
          setState(() {
            // Show loading state could be added here
          });
          
          final path = 'organizations/$scopedOrgId/assessments/attachments/${DateTime.now().millisecondsSinceEpoch}_$fileName';
          final ref = storage.ref().child(path);
          final uploadTask = ref.putData(Uint8List.fromList(bytes));
          final snapshot = await uploadTask;
          final downloadUrl = await snapshot.ref.getDownloadURL();
          
          setState(() {
            _attachmentUrls.add(downloadUrl);
            _attachmentNames.add(fileName);
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Attachment uploaded successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload attachment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachmentUrls.removeAt(index);
      _attachmentNames.removeAt(index);
    });
  }

  AssessmentModel? _selectedManageMarksAssessment;

  // ====== CREATE ASSESSMENT FORM ======
  Widget _buildCreateAssessment() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            smcText(
              textToDisplay: 'Create Student Assessment',
              textSize: 22,
              textBoldness: 5,
              colorOfText: ColorConst.textPrimary,
            ),
            SizedBox(height: 4),
            smcText(
              textToDisplay:
              'Create and assign an assessment for your students. You can set the type, marks, due date and select the relevant scheme, semester, and course.',
              textSize: 14,
              colorOfText: ColorConst.textSecondary,
            ),
          ],
        ),
        toolbarHeight: 100,
      ),
      body: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Details
                    _buildStepCard(
                      step: 1,
                      title: 'Basic Details',
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _titleCtrl,
                                  label: 'Assessment Title *',
                                  hint: 'e.g. Unit Test 1 / Assignment 1 / Mid Term',
                                  validator: (v) =>
                                      (v ?? '').trim().isEmpty
                                          ? 'Title is required'
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDropdownField<String>(
                                  label: 'Assessment Type *',
                                  hint: 'Select Type',
                                  value: _selectedAssessmentType.isEmpty
                                      ? null
                                      : _selectedAssessmentType,
                                  items: AssessmentModel.assessmentTypes
                                      .map((t) => DropdownMenuItem(
                                            value: t,
                                            child: smcText(
                                              textToDisplay: t,
                                              textSize: 13,
                                              colorOfText:
                                                  ColorConst.textPrimary,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (v) => setState(
                                      () => _selectedAssessmentType = v ?? ''),
                                  validator: (v) =>
                                      (v ?? '').toString().trim().isEmpty
                                          ? 'Type is required'
                                          : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildDropdownField<String>(
                                  label: 'Scheme *',
                                  hint: 'Select Scheme',
                                  value: _selectedScheme.isEmpty
                                      ? null
                                      : _selectedScheme,
                                  items: _getAvailableSchemes()
                                      .map((t) => DropdownMenuItem(
                                            value: t,
                                            child: smcText(
                                              textToDisplay: t,
                                              textSize: 13,
                                              colorOfText:
                                                  ColorConst.textPrimary,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    setState(() {
                                      _selectedScheme = v ?? '';
                                      _selectedCourseId = ''; // Reset course when scheme changes
                                      _selectedStudentIds = []; // Reset student selection
                                    });
                                  },
                                  validator: (v) =>
                                      (v ?? '').toString().trim().isEmpty
                                          ? 'Scheme is required'
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDropdownField<String>(
                                  label: 'Semester *',
                                  hint: 'Select Semester',
                                  value: _selectedSemester.isEmpty
                                      ? null
                                      : _selectedSemester,
                                  items: StudentModel.semesterOptions
                                      .map((t) => DropdownMenuItem(
                                            value: t,
                                            child: smcText(
                                              textToDisplay: t,
                                              textSize: 13,
                                              colorOfText:
                                                  ColorConst.textPrimary,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    setState(() {
                                      _selectedSemester = v ?? '';
                                      _selectedCourseId = ''; // Reset course when semester changes
                                      _selectedStudentIds = []; // Reset student selection
                                    });
                                  },
                                  validator: (v) =>
                                      (v ?? '').toString().trim().isEmpty
                                          ? 'Semester is required'
                                          : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildDropdownField<String>(
                            label: 'Course *',
                            hint: _selectedScheme.isEmpty || _selectedSemester.isEmpty
                                ? 'Select Scheme and Semester first'
                                : (_getFilteredCourses().isEmpty 
                                    ? 'No courses found for this scheme/semester'
                                    : 'Select Course'),
                            value: _selectedCourseId.isEmpty
                                ? null
                                : _selectedCourseId,
                            items: _getFilteredCourses()
                                .map((c) => DropdownMenuItem(
                                      value: c.id,
                                      child: smcText(
                                        textToDisplay:
                                            '${c.courseCode} - ${c.courseTitle}',
                                        textSize: 13,
                                        colorOfText:
                                            ColorConst.textPrimary,
                                        maxLines: 1,
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _selectedCourseId = v ?? '';
                                _selectedStudentIds = []; // Reset student selection when course changes
                              });
                            },
                            validator: (v) =>
                                (v ?? '').toString().trim().isEmpty
                                    ? 'Course is required'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _totalMarksCtrl,
                                  label: 'Total Marks *',
                                  hint: 'e.g. 100',
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if ((v ?? '').trim().isEmpty)
                                      return 'Total marks is required';
                                    final n = double.tryParse(v!);
                                    if (n == null || n <= 0)
                                      return 'Enter a valid number';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDateField(
                                  label: 'Due Date *',
                                  hint: 'dd/mm/yyyy',
                                  date: _selectedDueDate,
                                  onTap: () async {
                                    final now = DateTime.now();
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          _selectedDueDate ?? now,
                                      firstDate: now,
                                      lastDate: DateTime(now.year + 5),
                                      builder: (ctx, child) {
                                        return Theme(
                                          data: Theme.of(ctx).copyWith(
                                            colorScheme:
                                                const ColorScheme.light(
                                              primary: ColorConst.primaryBlue,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (d != null)
                                      setState(() => _selectedDueDate = d);
                                  },
                                  validator: (d) =>
                                      d == null ? 'Due date is required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _descriptionCtrl,
                            label: 'Description (Optional)',
                            hint:
                                'Add instructions or additional details about the assessment...',
                            maxLines: 4,
                            maxLength: 500,
                          ),
                          const SizedBox(height: 16),
                          // Attachments Section
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              smcText(
                                textToDisplay: 'Attachments (Optional)',
                                textSize: 13,
                                textBoldness: 4,
                                colorOfText: ColorConst.textSecondary,
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _uploadAttachment,
                                icon: const Icon(Icons.attach_file, size: 18),
                                label: const Text('Add Attachment'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEAF0FF),
                                  foregroundColor: ColorConst.primaryBlue,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              if (_attachmentNames.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                ...List.generate(_attachmentNames.length, (index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0F4FF),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: ColorConst.primaryBlue.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.description_outlined,
                                              size: 16, color: ColorConst.primaryBlue),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: smcText(
                                              textToDisplay: _attachmentNames[index],
                                              textSize: 12,
                                              colorOfText: ColorConst.textPrimary,
                                              maxLines: 1,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => _removeAttachment(index),
                                            icon: const Icon(Icons.close_rounded,
                                                size: 18, color: ColorConst.textSecondary),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Assign to Students
                    _buildStepCard(
                      step: 2,
                      title: 'Assign to Students',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search students
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Search students by name or USN...',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: ColorConst.textSecondary,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                size: 18,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF9FAFF),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD8E2F4),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD8E2F4),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: ColorConst.primaryBlue,
                                ),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _studentSearchQuery = value.trim();
                              });
                            },
                          ),

                          const SizedBox(height: 12),

                          // Select All Students
                          CheckboxListTile(
                            value: _allStudentsInSection,
                            onChanged: (value) {
                              setState(() {
                                _allStudentsInSection = value ?? false;

                                if (_allStudentsInSection) {
                                  _selectedStudentIds.clear();
                                }
                              });
                            },
                            title: const smcText(
                              textToDisplay: 'Select All Students',
                              textSize: 14,
                              textBoldness: 5,
                              colorOfText: ColorConst.textPrimary,
                            ),
                            subtitle: const smcText(
                              textToDisplay: 'Assign to all students enrolled in the selected course',
                              textSize: 12,
                              colorOfText: ColorConst.textSecondary,
                            ),
                            activeColor: ColorConst.primaryBlue,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          const Divider(height: 1),

                          const SizedBox(height: 8),

                          // Student results
                          // Student results: show only when faculty starts searching
                          if (_studentSearchQuery.trim().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6F7FB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              constraints: const BoxConstraints(maxHeight: 280),
                              child: _getFilteredStudents().isEmpty
                                  ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(30),
                                  child: Text('No students found'),
                                ),
                              )
                                  : ListView.builder(
                                shrinkWrap: true,
                                itemCount: _getFilteredStudents().length,
                                itemBuilder: (ctx, i) {
                                  final s = _getFilteredStudents()[i];

                                  final sid = (s['student_id'] ??
                                      s['student_Id'] ??
                                      s['studentId'] ??
                                      s['documentId'] ??
                                      '')
                                      .toString();

                                  final name = (s['full_name'] ??
                                      s['fullName'] ??
                                      s['name'] ??
                                      'Student')
                                      .toString();

                                  final usn = (s['USN'] ??
                                      s['usn'] ??
                                      s['studentRegNo'] ??
                                      '')
                                      .toString();

                                  return CheckboxListTile(
                                    value: _selectedStudentIds.contains(sid),
                                    onChanged: _allStudentsInSection
                                        ? null
                                        : (value) {
                                      setState(() {
                                        if (value == true) {
                                          if (!_selectedStudentIds.contains(sid)) {
                                            _selectedStudentIds.add(sid);
                                          }
                                        } else {
                                          _selectedStudentIds.remove(sid);
                                        }
                                      });
                                    },
                                    title: Text(
                                      '$name${usn.isNotEmpty ? ' ($usn)' : ''}',
                                    ),
                                    controlAffinity:
                                    ListTileControlAffinity.leading,
                                  );
                                },
                              ),
                            ),

                          const SizedBox(height: 12),

                          // Selection status
                          Align(
                            alignment: Alignment.centerRight,
                            child: smcText(
                              textToDisplay: _allStudentsInSection
                                  ? 'All students will receive this assessment'
                                  : '${_selectedStudentIds.length} student(s) selected',
                              textSize: 12,
                              textBoldness: 4,
                              colorOfText: ColorConst.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Additional Settings
                    _buildStepCard(
                      step: 4,
                      title: 'Additional Settings',
                      child: Column(
                        children: [
                          CheckboxListTile(
                            value: _allowLateSubmission,
                            onChanged: (v) => setState(() =>
                                _allowLateSubmission = v ?? false),
                            title: const smcText(
                              textToDisplay:
                                  'Allow late submission  (with penalty)',
                              textSize: 14,
                              colorOfText: ColorConst.textPrimary,
                            ),
                            activeColor: ColorConst.primaryBlue,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                          ),
                          CheckboxListTile(
                            value: _showMarksToStudents,
                            onChanged: (v) => setState(() =>
                                _showMarksToStudents = v ?? true),
                            title: const smcText(
                              textToDisplay:
                                  'Show marks to students after submission',
                              textSize: 14,
                              colorOfText: ColorConst.textPrimary,
                            ),
                            activeColor: ColorConst.primaryBlue,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dctx) => AlertDialog(
                                title: const smcText(
                                  textToDisplay: 'Discard changes?',
                                  textSize: 18,
                                  textBoldness: 5,
                                  colorOfText: ColorConst.textPrimary,
                                ),
                                content: const smcText(
                                  textToDisplay:
                                      'Are you sure you want to discard this assessment?',
                                  textSize: 14,
                                  colorOfText: ColorConst.textSecondary,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dctx, false),
                                    child: const smcText(
                                      textToDisplay: 'No',
                                      textSize: 14,
                                      textBoldness: 3,
                                      colorOfText: ColorConst.textSecondary,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dctx, true),
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
                            if (confirmed == true) {
                              _resetAssessmentForm();
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(
                                color: Color(0xFFD8E2F4)),
                          ),
                          child: const smcText(
                            textToDisplay: 'Cancel',
                            textSize: 14,
                            textBoldness: 4,
                            colorOfText: ColorConst.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            final form = _formKey.currentState;
                            if (form == null || !form.validate()) return;
                            if (_selectedDueDate == null) return;
                            if (!_allStudentsInSection &&
                                _selectedStudentIds.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Select at least one student, or choose All Students'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            try {
                              final course = assignedCourses
                                  .where((c) => c.id == _selectedCourseId)
                                  .firstOrNull;
                              final now = DateTime.now();
                              // Use facultyId from profile or fall back to Firebase Auth userId
                              final facultyId = facultyProfile?.facultyId.isNotEmpty == true 
                                  ? facultyProfile!.facultyId 
                                  : FirebaseAuth.instance.currentUser?.uid ?? '';
                              
                              final assess = AssessmentModel(
                                orgId: scopedOrgId,
                                deptId: scopedDeptId,
                                facultyId: facultyId,
                                facultyName:
                                    facultyProfile?.fullName ?? widget.displayName,
                                title: _titleCtrl.text.trim(),
                                assessmentType: _selectedAssessmentType,
                                courseId: _selectedCourseId,
                                courseName: course != null
                                    ? '${course.courseCode} - ${course.courseTitle}'
                                    : '',
                                scheme: _selectedScheme, // This is just the year (e.g., "2024")
                                semester: _selectedSemester,
                                totalMarks: double.tryParse(
                                        _totalMarksCtrl.text.trim()) ??
                                    100,
                                dueDate: _selectedDueDate!,
                                description: _descriptionCtrl.text.trim().isEmpty
                                    ? null
                                    : _descriptionCtrl.text.trim(),
                                attachmentUrls: _attachmentUrls,
                                attachmentNames: _attachmentNames,
                                allStudentsInSection: _allStudentsInSection,
                                selectedStudentIds: _selectedStudentIds,
                                allowLateSubmission: _allowLateSubmission,
                                showMarksToStudents: _showMarksToStudents,
                                createdOn: now,
                                updatedOn: now,
                              );
                              await assessmentService.createAssessment(assess);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '✅ Assessment created successfully! Faculty ID: $facultyId'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _resetAssessmentForm();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 14),
                            backgroundColor: ColorConst.primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const smcText(
                            textToDisplay: 'Create Assessment',
                            textSize: 14,
                            textBoldness: 4,
                            colorOfText: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Assessment Summary Sidebar
          // Assessment Summary Sidebar
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE3EAF8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF0FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.assignment_outlined,
                          color: ColorConst.primaryBlue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: smcText(
                          textToDisplay: 'Assessment Summary',
                          textSize: 18,
                          textBoldness: 5,
                          colorOfText: ColorConst.textPrimary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryRow(
                            'Title',
                            _titleCtrl.text.trim().isEmpty
                                ? '—'
                                : _titleCtrl.text.trim(),
                          ),

                          _buildSummaryRow(
                            'Type',
                            _selectedAssessmentType.isEmpty
                                ? '—'
                                : _selectedAssessmentType,
                          ),

                          _buildSummaryRow(
                            'Scheme',
                            _selectedScheme.isEmpty
                                ? '—'
                                : _formatSchemeForDisplay(_selectedScheme),
                          ),

                          _buildSummaryRow(
                            'Semester',
                            _selectedSemester.isEmpty
                                ? '—'
                                : _selectedSemester,
                          ),

                          _buildSummaryRow(
                            'Course',
                            _selectedCourseId.isEmpty
                                ? '—'
                                : assignedCourses
                                .where(
                                  (c) => c.id == _selectedCourseId,
                            )
                                .firstOrNull
                                ?.courseCode ??
                                '—',
                          ),

                          _buildSummaryRow(
                            'Total Marks',
                            _totalMarksCtrl.text.trim().isEmpty
                                ? '—'
                                : _totalMarksCtrl.text.trim(),
                          ),

                          _buildSummaryRow(
                            'Due Date',
                            _selectedDueDate == null
                                ? '—'
                                : _formatDate(_selectedDueDate!),
                          ),

                          _buildSummaryRow(
                            'Attachments',
                            _attachmentNames.isEmpty
                                ? 'None'
                                : '${_attachmentNames.length} file(s)',
                          ),

                          _buildSummaryRow(
                            'Students',
                            _allStudentsInSection
                                ? 'All enrolled in course'
                                : '${_selectedStudentIds.length} selected',
                          ),

                          const SizedBox(height: 20),

                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF4FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD8E2F4),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Icon(
                                  Icons.info_outline,
                                  color: ColorConst.primaryBlue,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: smcText(
                                    textToDisplay:
                                    'Once created, the assessment will be visible to students in the selected scheme, semester, and course.',
                                    textSize: 12,
                                    colorOfText: ColorConst.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
                  ),
              ],
              ),
            ),
         );
  }

  Widget _buildStepCard({
    required int step,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: ColorConst.primaryBlue,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: smcText(
                  textToDisplay: '$step',
                  textSize: 14,
                  textBoldness: 5,
                  colorOfText: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              smcText(
                textToDisplay: title,
                textSize: 18,
                textBoldness: 5,
                colorOfText: ColorConst.textPrimary,
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: smcText(
              textToDisplay: label,
              textSize: 13,
              colorOfText: ColorConst.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: smcText(
                textToDisplay: value,
                textSize: 13,
                textBoldness: 4,
                colorOfText: ColorConst.textPrimary,
                textAlign: TextAlign.right,
                maxLines: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        smcText(
          textToDisplay: label,
          textSize: 13,
          textBoldness: 4,
          colorOfText: ColorConst.textSecondary,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: ColorConst.textSecondary,
              fontSize: 13,
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFF),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD8E2F4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ColorConst.primaryBlue),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red),
            ),
            counterText: maxLength != null ? null : '',
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        smcText(
          textToDisplay: label,
          textSize: 13,
          textBoldness: 4,
          colorOfText: ColorConst.textSecondary,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: ColorConst.textSecondary,
              fontSize: 13,
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFF),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD8E2F4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ColorConst.primaryBlue),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required String hint,
    required DateTime? date,
    required VoidCallback onTap,
    String? Function(DateTime?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        smcText(
          textToDisplay: label,
          textSize: 13,
          textBoldness: 4,
          colorOfText: ColorConst.textSecondary,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: ColorConst.textSecondary,
                fontSize: 13,
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFF),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD8E2F4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: ColorConst.primaryBlue),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.red),
              ),
              suffixIcon: const Icon(
                Icons.calendar_today_outlined,
                color: ColorConst.textSecondary,
                size: 18,
              ),
            ),
            child: smcText(
              textToDisplay: date == null ? '' : _formatDate(date),
              textSize: 13,
              colorOfText: date == null
                  ? ColorConst.textSecondary
                  : ColorConst.textPrimary,
            ),
          ),
        ),
        if (validator != null && validator(date) != null) ...[
          const SizedBox(height: 8),
          smcText(
            textToDisplay: validator(date)!,
            textSize: 12,
            colorOfText: Colors.red,
          ),
        ],
      ],
    );
  }

  Widget _buildViewAssessments() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const smcText(
          textToDisplay: 'My Assessments',
          textSize: 22,
          textBoldness: 5,
          colorOfText: ColorConst.textPrimary,
        ),
      ),
      body: assessments.isEmpty
          ? _buildEmptyState(
              icon: Icons.assessment_outlined,
              title: 'No assessments created yet',
              subtitle:
                  'Click "Create Assessment" to create your first assessment for students.',
              onButtonTap: () =>
                  setState(() => selectedAssessmentSubIndex = 0),
              buttonLabel: 'Create Assessment',
            )
          : ListView.builder(
              itemCount: assessments.length,
              itemBuilder: (ctx, i) {
                final a = assessments[i];
                final now = DateTime.now();
                final isDue = a.dueDate.isBefore(now);
                final submissionsCount =
                    a.marksEntries.where((m) => m.submittedOn != null).length;
                // Handle backward compatibility - use section if scheme/semester are empty
                final useLegacySection = a.scheme.isEmpty && a.semester.isEmpty;
                
                // For scheme matching, check if the stored scheme starts with the year
                // Handle both "2024" and "2024-2026" formats
                int totalStudents = 0;
                if (a.allStudentsInSection) {
                  if (useLegacySection) {
                    totalStudents = _studentsForSection(a.section).length;
                  } else {
                    // Temporarily set filters to match assessment
                    final originalScheme = _selectedScheme;
                    final originalSemester = _selectedSemester;
                    final originalCourseId = _selectedCourseId;
                    
                    _selectedScheme = a.scheme;
                    _selectedSemester = a.semester;
                    _selectedCourseId = a.courseId;
                    
                    totalStudents = _studentsForSchemeSemesterCourse().length;
                    
                    // Restore original values
                    _selectedScheme = originalScheme;
                    _selectedSemester = originalSemester;
                    _selectedCourseId = originalCourseId;
                  }
                } else {
                  totalStudents = a.selectedStudentIds.length;
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE3EAF8)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF0FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.assignment,
                          color: ColorConst.primaryBlue,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            smcText(
                              textToDisplay: a.title,
                              textSize: 16,
                              textBoldness: 5,
                              colorOfText: ColorConst.textPrimary,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                _buildInfoChip(
                                    Icons.category_outlined,
                                    a.assessmentType,
                                    ColorConst.textSecondary),
                                _buildInfoChip(
                                    Icons.class_outlined, a.courseName.isNotEmpty
                                        ? a.courseName
                                        : (useLegacySection ? a.section : '${a.scheme} - ${a.semester}'), 
                                    ColorConst.textSecondary),
                                _buildInfoChip(Icons.calendar_today,
                                    'Due: ${_formatDate(a.dueDate)}',
                                    isDue ? Colors.red : ColorConst.textSecondary),
                                _buildInfoChip(
                                    Icons.people_outline,
                                    '$totalStudents student${totalStudents != 1 ? 's' : ''}',
                                    ColorConst.textSecondary),
                                _buildInfoChip(
                                    Icons.task_alt_outlined,
                                    '$submissionsCount/$totalStudents submitted',
                                    submissionsCount >= totalStudents
                                        ? Colors.green
                                        : ColorConst.textSecondary),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'view') {
                            // Show assessment details dialog
                            await _showAssessmentDetailsDialog(a);
                          } else if (value == 'submissions') {
                            // Show submissions dialog
                            await _showAssessmentSubmissionsDialog(a);
                          } else if (value == 'delete') {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (dctx) => AlertDialog(
                                title: const smcText(
                                  textToDisplay: 'Delete Assessment?',
                                  textSize: 18,
                                  textBoldness: 5,
                                  colorOfText: ColorConst.textPrimary,
                                ),
                                content: smcText(
                                  textToDisplay:
                                      'Are you sure you want to delete "${a.title}"? This action cannot be undone.',
                                  textSize: 14,
                                  colorOfText: ColorConst.textSecondary,
                                  maxLines: 3,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dctx, false),
                                    child: const smcText(
                                      textToDisplay: 'Cancel',
                                      textSize: 14,
                                      textBoldness: 3,
                                      colorOfText: ColorConst.textSecondary,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dctx, true),
                                    child: const smcText(
                                      textToDisplay: 'Delete',
                                      textSize: 14,
                                      textBoldness: 4,
                                      colorOfText: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && a.id != null) {
                              await assessmentService.deleteAssessment(a.id!);
                            }
                          } else if (value == 'edit') {
                            setState(() {
                              // Store the assessment being edited
                              _selectedManageMarksAssessment = a;

                              // Fill existing assessment details
                              _titleCtrl.text = a.title;
                              _totalMarksCtrl.text = a.totalMarks.toString();
                              _descriptionCtrl.text = a.description ?? '';

                              _selectedAssessmentType = a.assessmentType;
                              _selectedScheme = a.scheme;
                              _selectedSemester = a.semester;
                              _selectedCourseId = a.courseId;
                              _selectedDueDate = a.dueDate;

                              _allStudentsInSection = a.allStudentsInSection;
                              _selectedStudentIds = List<String>.from(
                                a.selectedStudentIds,
                              );

                              _allowLateSubmission = a.allowLateSubmission;
                              _showMarksToStudents = a.showMarksToStudents;

                              // Open Create Assessment form
                              selectedAssessmentSubIndex = 0;
                            });
                          } else if (value == 'marks') {
                            setState(() {
                              _selectedManageMarksAssessment = a;
                              selectedAssessmentSubIndex = 2;
                            });
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'view',
                            child: smcText(
                              textToDisplay: '👁️ View',
                              textSize: 14,
                              colorOfText: ColorConst.textPrimary,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'submissions',
                            child: smcText(
                              textToDisplay: '📁 View Submissions',
                              textSize: 14,
                              colorOfText: ColorConst.textPrimary,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'marks',
                            child: smcText(
                              textToDisplay: '📊 Manage Marks',
                              textSize: 14,
                              colorOfText: ColorConst.textPrimary,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: smcText(
                              textToDisplay: '✏️ Edit',
                              textSize: 14,
                              colorOfText: ColorConst.textPrimary,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: smcText(
                              textToDisplay: '🗑️ Delete',
                              textSize: 14,
                              colorOfText: Colors.red,
                            ),
                          ),
                        ],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _showAssessmentDetailsDialog(AssessmentModel assessment) async {
    final useLegacySection = assessment.scheme.isEmpty && assessment.semester.isEmpty;
    
    // Calculate total students
    int totalStudents = 0;
    if (assessment.allStudentsInSection) {
      if (useLegacySection) {
        totalStudents = _studentsForSection(assessment.section).length;
      } else {
        final originalScheme = _selectedScheme;
        final originalSemester = _selectedSemester;
        final originalCourseId = _selectedCourseId;
        
        _selectedScheme = assessment.scheme;
        _selectedSemester = assessment.semester;
        _selectedCourseId = assessment.courseId;
        
        totalStudents = _studentsForSchemeSemesterCourse().length;
        
        _selectedScheme = originalScheme;
        _selectedSemester = originalSemester;
        _selectedCourseId = originalCourseId;
      }
    } else {
      totalStudents = assessment.selectedStudentIds.length;
    }

    await showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const smcText(
          textToDisplay: 'Assessment Details',
          textSize: 18,
          textBoldness: 5,
          colorOfText: ColorConst.textPrimary,
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Title', assessment.title),
              const SizedBox(height: 8),
              _detailRow('Type', assessment.assessmentType),
              const SizedBox(height: 8),
              _detailRow('Course', assessment.courseName.isNotEmpty 
                  ? assessment.courseName 
                  : (useLegacySection ? 'Section ${assessment.section}' : '${assessment.scheme} - ${assessment.semester}')),
              const SizedBox(height: 8),
              _detailRow('Total Marks', assessment.totalMarks.toStringAsFixed(assessment.totalMarks % 1 == 0 ? 0 : 1)),
              const SizedBox(height: 8),
              _detailRow('Due Date', _formatDate(assessment.dueDate)),
              const SizedBox(height: 8),
              _detailRow('Assigned Students', '$totalStudents'),
              const SizedBox(height: 8),
              _detailRow('Late Submission', assessment.allowLateSubmission ? 'Allowed' : 'Not Allowed'),
              const SizedBox(height: 8),
              _detailRow('Show Marks to Students', assessment.showMarksToStudents ? 'Yes' : 'No'),
              if (assessment.description != null && assessment.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                const smcText(
                  textToDisplay: 'Description',
                  textSize: 13,
                  textBoldness: 4,
                  colorOfText: ColorConst.textSecondary,
                ),
                const SizedBox(height: 4),
                smcText(
                  textToDisplay: assessment.description!,
                  textSize: 13,
                  colorOfText: ColorConst.textPrimary,
                ),
              ],
              if (assessment.attachmentUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                const smcText(
                  textToDisplay: 'Attachments',
                  textSize: 13,
                  textBoldness: 4,
                  colorOfText: ColorConst.textSecondary,
                ),
                const SizedBox(height: 8),
                ...List.generate(assessment.attachmentUrls.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file, size: 16, color: ColorConst.primaryBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: smcText(
                            textToDisplay: index < assessment.attachmentNames.length
                                ? assessment.attachmentNames[index]
                                : 'Attachment ${index + 1}',
                            textSize: 12,
                            colorOfText: ColorConst.primaryBlue,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const smcText(
              textToDisplay: 'Close',
              textSize: 14,
              colorOfText: ColorConst.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssessmentSubmissionsDialog(AssessmentModel assessment) async {
    if (assessment.id == null) return;

    await showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.folder_open, color: ColorConst.primaryBlue),
            const SizedBox(width: 8),
            Expanded(
              child: smcText(
                textToDisplay: assessment.title,
                textSize: 18,
                textBoldness: 5,
                colorOfText: ColorConst.textPrimary,
                maxLines: 1,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<AssessmentSubmissionModel>>(
            stream: assessmentService.getAssessmentSubmissionsByAssessment(assessment.id!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return smcText(
                  textToDisplay: 'Error loading submissions',
                  textSize: 14,
                  colorOfText: Colors.red,
                );
              }
              final submissions = snapshot.data ?? [];
              if (submissions.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      smcText(
                        textToDisplay: 'No submissions yet',
                        textSize: 14,
                        colorOfText: ColorConst.textSecondary,
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                itemCount: submissions.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (ctx, index) {
                  final submission = submissions[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEAF0FF),
                      child: Icon(Icons.person, color: ColorConst.primaryBlue, size: 20),
                    ),
                    title: smcText(
                      textToDisplay: submission.studentName,
                      textSize: 14,
                      textBoldness: 4,
                      colorOfText: ColorConst.textPrimary,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        smcText(
                          textToDisplay: 'Submitted: ${_formatSubmissionDate(submission.submittedAt)}',
                          textSize: 12,
                          colorOfText: ColorConst.textSecondary,
                        ),
                        if (submission.fileName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          smcText(
                            textToDisplay: submission.fileName,
                            textSize: 11,
                            colorOfText: ColorConst.textSecondary,
                            maxLines: 1,
                          ),
                        ],
                      ],
                    ),
                    trailing: submission.fileUrl.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.download, color: ColorConst.primaryBlue),
                            onPressed: () async {
                              final uri = Uri.parse(submission.fileUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const smcText(
              textToDisplay: 'Close',
              textSize: 14,
              colorOfText: ColorConst.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: smcText(
            textToDisplay: label,
            textSize: 13,
            textBoldness: 4,
            colorOfText: ColorConst.textSecondary,
          ),
        ),
        Expanded(
          child: smcText(
            textToDisplay: value,
            textSize: 13,
            colorOfText: ColorConst.textPrimary,
          ),
        ),
      ],
    );
  }

  String _formatSubmissionDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      final now = DateTime.now();
      final difference = now.difference(d);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes} min ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return _formatDateFromIso(iso);
      }
    } catch (_) {
      return iso;
    }
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          smcText(
            textToDisplay: label,
            textSize: 12,
            colorOfText: color,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onButtonTap,
    required String buttonLabel,
  }) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 80, color: const Color(0xFFD8E2F4)),
            const SizedBox(height: 20),
            smcText(
              textToDisplay: title,
              textSize: 20,
              textBoldness: 5,
              colorOfText: ColorConst.textPrimary,
            ),
            const SizedBox(height: 12),
            smcText(
              textToDisplay: subtitle,
              textSize: 14,
              colorOfText: ColorConst.textSecondary,
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onButtonTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorConst.primaryBlue,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: smcText(
                textToDisplay: buttonLabel,
                textSize: 14,
                textBoldness: 4,
                colorOfText: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======== MANAGE MARKS ========
  Widget _buildManageMarks() {
    final assessment = _selectedManageMarksAssessment;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: assessment != null
            ? IconButton(
                onPressed: () => setState(() {
                  _selectedManageMarksAssessment = null;
                  selectedAssessmentSubIndex = 1;
                }),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: ColorConst.textPrimary,
                  size: 20,
                ),
              )
            : null,
        title: smcText(
          textToDisplay: assessment != null
              ? 'Manage Marks - ${assessment.title}'
              : 'Manage Marks',
          textSize: 22,
          textBoldness: 5,
          colorOfText: ColorConst.textPrimary,
        ),
      ),
      body: assessment == null
          ? _buildAssessmentSelector()
          : _buildMarksTable(assessment),
    );
  }

  Widget _buildAssessmentSelector() {
    if (assessments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assessment_outlined,
        title: 'No assessments to mark',
        subtitle:
            'Create an assessment first, then come back to enter marks for students.',
        onButtonTap: () => setState(() => selectedAssessmentSubIndex = 0),
        buttonLabel: 'Create Assessment',
      );
    }
    return ListView.builder(
      itemCount: assessments.length,
      itemBuilder: (ctx, i) {
        final a = assessments[i];
        final markedCount =
            a.marksEntries.where((e) => e.marksObtained != null).length;
        // Handle backward compatibility
        final useLegacySection = a.scheme.isEmpty && a.semester.isEmpty;
        final total = a.allStudentsInSection
            ? (useLegacySection 
                ? _studentsForSection(a.section).length 
                : _studentsForSchemeSemesterCourse().length)
            : a.selectedStudentIds.length;
        return InkWell(
          onTap: () =>
              setState(() => _selectedManageMarksAssessment = a),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3EAF8)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF0FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.assignment_turned_in_outlined,
                      color: ColorConst.primaryBlue, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      smcText(
                        textToDisplay: a.title,
                        textSize: 16,
                        textBoldness: 5,
                        colorOfText: ColorConst.textPrimary,
                      ),
                      const SizedBox(height: 6),
                      smcText(
                        textToDisplay:
                            '${a.courseName} • ${useLegacySection ? 'Section ${a.section}' : '${a.scheme} - ${a.semester}'} • ${a.assessmentType}',
                        textSize: 13,
                        colorOfText: ColorConst.textSecondary,
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : markedCount / total,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFEFF4FF),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            markedCount >= total
                                ? Colors.green
                                : ColorConst.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      smcText(
                        textToDisplay:
                            '$markedCount / $total marked${total > 0 ? ' (${((markedCount / total) * 100).toStringAsFixed(0)}%)' : ''}',
                        textSize: 12,
                        colorOfText: ColorConst.textSecondary,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: ColorConst.textSecondary, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMarksTable(AssessmentModel assessment) {
    final studentList = <Map<String, dynamic>>[];
    // Handle backward compatibility
    final useLegacySection = assessment.scheme.isEmpty && assessment.semester.isEmpty;
    
    if (assessment.allStudentsInSection) {
      if (useLegacySection) {
        studentList.addAll(_studentsForSection(assessment.section));
      } else {
        // Temporarily set the filters to match the assessment's scheme/semester/course
        final originalScheme = _selectedScheme;
        final originalSemester = _selectedSemester;
        final originalCourseId = _selectedCourseId;
        
        _selectedScheme = assessment.scheme;
        _selectedSemester = assessment.semester;
        _selectedCourseId = assessment.courseId;
        
        studentList.addAll(_studentsForSchemeSemesterCourse());
        
        // Restore original values
        _selectedScheme = originalScheme;
        _selectedSemester = originalSemester;
        _selectedCourseId = originalCourseId;
      }
    } else {
      for (final sid in assessment.selectedStudentIds) {
        final match = students.firstWhere(
              (s) {
            final sId = s['student_id'] ??
                s['student_Id'] ??
                s['studentId'] ??
                s['Student_ID'] ??
                s['documentId'] ??
                s['USN'] ??
                s['usn'] ??
                '';

            return sId.toString().trim() == sid.toString().trim();
          },
          orElse: () => <String, dynamic>{},
        );

        final studentName = match['full_name'] ??
            match['fullName'] ??
            match['name'] ??
            match['student_name'] ??
            match['studentName'] ??
            'Unknown Student';

        studentList.add({
          ...match,
          'studentId': sid,
          'fullName': studentName,
        });
      }
    }

    final List<TextEditingController> controllers = [];
    final List<AssessmentMarkEntry> localEntries = [];

    for (int i = 0; i < studentList.length; i++) {
      final s = studentList[i];
      final sid = (s['student_Id'] ??
              s['studentId'] ??
              s['documentId'] ??
              s['Student_ID'] ??
              '')
          .toString();
      final name = (s['full_Name'] ??
              s['fullName'] ??
              s['name'] ??
              s['Student_Name'] ??
              'Unknown Student')
          .toString();
      final existing = assessment.marksEntries
          .where((e) => e.studentId.toString() == sid.toString())
          .firstOrNull;
      controllers.add(TextEditingController(
          text: existing?.marksObtained != null
              ? existing!.marksObtained.toString()
              : ''));
      localEntries.add(existing ??
          AssessmentMarkEntry(studentId: sid, studentName: name));
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE3EAF8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildStatMini(
                    'Total Marks', '${assessment.totalMarks}'),
              ),
              Expanded(
                child: _buildStatMini('Students', studentList.length.toString()),
              ),
              Expanded(
                child: _buildStatMini('Marked',
                    localEntries.where((e) => e.marksObtained != null).length.toString()),
              ),
              Expanded(
                child: _buildStatMini(
                  'Avg',
                  _calculateAverage(localEntries, assessment.totalMarks),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  for (int i = 0; i < studentList.length; i++) {
                    final s = studentList[i];
                    final sid = (s['student_Id'] ??
                            s['studentId'] ??
                            s['documentId'] ??
                            '')
                        .toString();
                    final name = (s['full_Name'] ??
                            s['fullName'] ??
                            s['name'] ??
                            'Student')
                        .toString();
                    final rawVal = controllers[i].text.trim();
                    final marks =
                        rawVal.isEmpty ? null : double.tryParse(rawVal);
                    if (marks != null) {
                      if (marks < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Marks cannot be negative for $name'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      if (marks > assessment.totalMarks) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Marks exceed total (${assessment.totalMarks}) for $name'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                    }
                    localEntries[i] = AssessmentMarkEntry(
                      studentId: sid,
                      studentName: name,
                      marksObtained: marks,
                      remarks: localEntries[i].remarks,
                      submittedOn: localEntries[i].submittedOn ??
                          (marks != null ? DateTime.now() : null),
                    );
                  }
                  try {
                    if (assessment.id != null) {
                      await assessmentService.updateMarksEntries(
                        assessmentId: assessment.id!,
                        entries: localEntries,
                      );
                    }
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Marks saved successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorConst.primaryBlue,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.save_outlined,
                    size: 18, color: Colors.white),
                label: const smcText(
                  textToDisplay: 'Save Marks',
                  textSize: 14,
                  textBoldness: 4,
                  colorOfText: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3EAF8)),
            ),
            child: studentList.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: smcText(
                        textToDisplay:
                            'No students found. Select a different section or assign students.',
                        textSize: 14,
                        colorOfText: ColorConst.textSecondary,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(0),
                    child: DataTable(
                      dataRowMinHeight: 56,
                      dataRowMaxHeight: 64,
                      headingRowColor:
                          MaterialStateProperty.resolveWith<Color>(
                        (states) => ColorConst.primaryBlue,
                      ),
                      headingTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      columns: const [
                        DataColumn(label: Text('S.No')),
                        DataColumn(label: Text('Student ID')),
                        DataColumn(label: Text('Student Name')),
                        DataColumn(label: Text('USN')),
                        DataColumn(label: Text('Marks Obtained')),
                        DataColumn(label: Text('Max Marks')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: List.generate(studentList.length, (i) {
                        final s = studentList[i];
                        final sid = (s['student_Id'] ??
                                s['studentId'] ??
                                s['documentId'] ??
                                '')
                            .toString();
                        final usn = (s['USN'] ??
                                s['usn'] ??
                                s['studentRegNo'] ??
                                '')
                            .toString();
                        final name = (s['full_Name'] ??
                                s['fullName'] ??
                                s['name'] ??
                                'Unknown')
                            .toString();
                        final rawVal = controllers[i].text.trim();
                        final marks = rawVal.isEmpty
                            ? null
                            : double.tryParse(rawVal);
                        final bool absent = controllers[i].text.toLowerCase() ==
                            'ab';
                        final bool passed = marks != null &&
                            marks >= (assessment.totalMarks * 0.4);
                        return DataRow(
                          color: MaterialStateProperty.resolveWith<Color>(
                            (states) => i % 2 == 0
                                ? const Color(0xFFF9FAFF)
                                : Colors.white,
                          ),
                          cells: [
                            DataCell(Text('${i + 1}')),
                            DataCell(Text(sid.isEmpty ? '—' : sid)),
                            DataCell(Text(name)),
                            DataCell(Text(usn.isEmpty ? '—' : usn)),
                            DataCell(
                              SizedBox(
                                width: 120,
                                child: TextField(
                                  controller: controllers[i],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Marks / AB',
                                    hintStyle: TextStyle(
                                        fontSize: 12,
                                        color: ColorConst.textSecondary),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFD8E2F4)),
                                    ),
                                    isDense: true,
                                  ),
                                  style:
                                      const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            DataCell(
                                Text('${assessment.totalMarks}')),
                            DataCell(
                              absent
                                  ? Container(
                                      padding: const EdgeInsets
                                          .symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.grey
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(
                                                999),
                                      ),
                                      child: const smcText(
                                        textToDisplay: 'Absent',
                                        textSize: 11,
                                        textBoldness: 4,
                                        colorOfText: Colors.grey,
                                      ),
                                    )
                                  : marks == null
                                      ? Container(
                                          padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 10,
                                                  vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.orange
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius
                                                    .circular(999),
                                          ),
                                          child: const smcText(
                                            textToDisplay:
                                                'Awaiting',
                                            textSize: 11,
                                            textBoldness: 4,
                                            colorOfText: Colors.orange,
                                          ),
                                        )
                                      : passed
                                          ? Container(
                                              padding:
                                                  const EdgeInsets
                                                          .symmetric(
                                                      horizontal: 10,
                                                      vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.green
                                                    .withValues(
                                                        alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(999),
                                              ),
                                              child: smcText(
                                                textToDisplay:
                                                    'Passed',
                                                textSize: 11,
                                                textBoldness: 4,
                                                colorOfText:
                                                    Color(0xFF2E7D32),
                                              ),
                                            )
                                          : Container(
                                              padding:
                                                  const EdgeInsets
                                                          .symmetric(
                                                      horizontal: 10,
                                                      vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.red
                                                    .withValues(
                                                        alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(999),
                                              ),
                                              child: const smcText(
                                                textToDisplay:
                                                    'Failed',
                                                textSize: 11,
                                                textBoldness: 4,
                                                colorOfText: Colors.red,
                                              ),
                                            ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  String _calculateAverage(List<AssessmentMarkEntry> entries, double total) {
    final marked = entries.where((e) => e.marksObtained != null).toList();
    if (marked.isEmpty) return '—';
    final sum = marked.fold<double>(
        0, (sum, e) => sum + (e.marksObtained ?? 0));
    return '${(sum / marked.length).toStringAsFixed(1)}/${total}';
  }

  Widget _buildStatMini(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        smcText(
          textToDisplay: label,
          textSize: 12,
          colorOfText: ColorConst.textSecondary,
        ),
        const SizedBox(height: 6),
        smcText(
          textToDisplay: value,
          textSize: 20,
          textBoldness: 5,
          colorOfText: ColorConst.textPrimary,
        ),
      ],
    );
  }
}
