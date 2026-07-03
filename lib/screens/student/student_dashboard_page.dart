import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/org_field.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/data/user_org_scope.dart';
import 'package:smartcampus/models/announcement_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/screens/auth/landing_page.dart';
import 'package:smartcampus/screens/shared/person_detail_page.dart';
import 'package:smartcampus/screens/student/student_class_management/student_classes_page.dart';
import 'package:smartcampus/screens/student/student_courses_page.dart';
import 'package:smartcampus/screens/student/student_course_registration/student_course_registration_page.dart';
import 'package:smartcampus/screens/student/student_dashboard_mobile_layout.dart';
import 'package:smartcampus/screens/student/student_profile_not_found_page.dart';
import 'package:smartcampus/services/announcement_firestore_service.dart';
import 'package:smartcampus/services/course_firestore_service.dart';
import 'package:smartcampus/services/org_role_firestore_service.dart';
import 'package:smartcampus/services/student_firestore_service.dart';
import 'package:smartcampus/services/user_master_firestore_service.dart';
import 'package:smartcampus/widgets/app_info_dialog.dart';
import 'package:smartcampus/widgets/profile_photo_avatar.dart';
import 'package:smartcampus/widgets/smc_text.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentDashboardPage extends StatefulWidget {
  final String orgId;
  final String deptId;
  final String displayName;
  final String uuid;
  final StudentModel? student;

  const StudentDashboardPage({
    super.key,
    required this.orgId,
    this.deptId = '',
    required this.displayName,
    required this.uuid,
    this.student,
  });

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  final OrgRoleFirestoreService roleService = OrgRoleFirestoreService();
  final StudentFirestoreService studentService = StudentFirestoreService();
  final CourseFirestoreService courseService = CourseFirestoreService();
  final UserMasterFirestoreService userMasterService =
      UserMasterFirestoreService();
  final AnnouncementFirestoreService announcementService =
      AnnouncementFirestoreService();

  UserOrgScope? _orgScope;
  StreamSubscription<List<CourseModel>>? _courseSubscription;
  StreamSubscription<List<AnnouncementModel>>? _announcementSubscription;
  List<AnnouncementModel> announcements = [];

  String get scopedOrgId =>
      _orgScope?.orgId ?? OrgField.normalize(widget.orgId);

  bool loading = true;
  int selectedMenuIndex = 0;
  bool sidebarExpanded = false;

  StudentModel? studentProfile;
  List<CourseModel> allCourses = [];
  String organizationDisplayName = '';
  String departmentDisplayName = '';

  List<CourseModel> get enrolledCourses {
    if (studentProfile == null) {
      return const [];
    }
    return CourseFirestoreService.filterCoursesForStudent(
      allCourses,
      studentProfile!,
    );
  }

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
      });
    });
  }

  void _bindAnnouncementListener() {
    _announcementSubscription?.cancel();
    final scope = _orgScope;
    if (scope == null || !scope.hasOrg) {
      return;
    }
    _announcementSubscription = announcementService
        .getAnnouncementsForDept(orgId: scope.orgId, deptId: scope.deptId)
        .listen((announcementList) {
      if (!mounted) {
        return;
      }
      // First filter to org and dept
      final orgDeptFiltered = announcementList.where((a) {
        final matchesOrg = a.orgId == OrgField.normalize(scope.orgId);
        final matchesDept = a.deptId == OrgField.normalize(scope.deptId);
        return matchesOrg && matchesDept;
      }).toList();
      // Filter announcements for student's batch or all students
      final studentBatch = studentProfile?.batch ?? '';
      final filtered = orgDeptFiltered.where((a) {
        if (a.targetSchemes.isEmpty) {
          return true;
        }
        return a.targetSchemes.contains(studentBatch);
      }).toList();
      setState(() {
        announcements = filtered;
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
    _announcementSubscription?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      final scope = await userMasterService.resolveOrgScopeForSignedInUser() ??
          UserOrgScope(
            orgId: OrgField.normalize(widget.orgId),
            deptId: OrgField.normalize(widget.deptId),
          );
      _orgScope = scope;
      _bindScopedCourseListener();

      final resolvedStudent = await studentService.resolveStudentForUser(
        orgId: scope.orgId,
        deptId: scope.deptId,
        displayName: widget.displayName,
        uuid: widget.uuid,
        prefetched: widget.student,
      );
      
      // Bind announcement listener after we have student profile for filtering
      _bindAnnouncementListener();
      final org =
          await roleService.authService.getOrganizationById(scope.orgId);
      String deptName = scope.deptId;
      if (scope.deptId.isNotEmpty) {
        final departments =
            await roleService.loadDepartmentsForOrg(scope.orgId);
        for (final dept in departments) {
          if (dept.deptId.toUpperCase() == scope.deptId) {
            deptName = dept.deptName.isNotEmpty ? dept.deptName : scope.deptId;
            break;
          }
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        studentProfile = resolvedStudent;
        organizationDisplayName = (org?.orgName ?? '').trim().isEmpty
            ? scope.orgId
            : org!.orgName;
        departmentDisplayName = deptName;
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
    if (studentProfile == null) {
      return StudentProfileNotFoundPage(onLogout: onLogout);
    }

    final student = studentProfile!;

    if (_isMobileLayout(context)) {
      return StudentDashboardMobileLayout(
        selectedIndex: selectedMenuIndex,
        onIndexChanged: (index) => setState(() => selectedMenuIndex = index),
        onLogout: onLogout,
        student: student,
        displayName: widget.displayName,
        dashboardContent: _buildDashboardView(),
        profileContent: _buildProfileView(),
        classesContent: _buildClassesView(),
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

  void _showAnnouncementDetails(AnnouncementModel announcement) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: smcText(textToDisplay: announcement.title, textSize: 18, textBoldness: 5),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF4FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: smcText(
                          textToDisplay: announcement.category,
                          textSize: 11,
                          textBoldness: 3,
                          colorOfText: ColorConst.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      smcText(
                        textToDisplay: '${announcement.publishDate.day}/${announcement.publishDate.month}/${announcement.publishDate.year}',
                        textSize: 12,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const smcText(
                    textToDisplay: 'Description',
                    textSize: 12,
                    textBoldness: 4,
                    colorOfText: ColorConst.textSecondary,
                  ),
                  const SizedBox(height: 8),
                  smcText(
                    textToDisplay: announcement.description,
                    textSize: 12,
                  ),
                  if (announcement.attachmentUrl.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final uri = Uri.parse(announcement.attachmentUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.attach_file, color: ColorConst.primaryBlue),
                          const SizedBox(width: 8),
                          smcText(
                            textToDisplay: announcement.attachmentName,
                            textSize: 12,
                            colorOfText: ColorConst.primaryBlue,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const smcText(
                textToDisplay: 'Close',
                textSize: 14,
                textBoldness: 3,
                colorOfText: ColorConst.textSecondary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnnouncementCard(AnnouncementModel announcement) {
    return InkWell(
      onTap: () => _showAnnouncementDetails(announcement),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
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
                Expanded(
                  child: smcText(
                    textToDisplay: announcement.title,
                    textSize: 14,
                    textBoldness: 5,
                    colorOfText: ColorConst.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: smcText(
                    textToDisplay: announcement.category,
                    textSize: 11,
                    textBoldness: 3,
                    colorOfText: ColorConst.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            smcText(
              textToDisplay: announcement.description,
              textSize: 13,
              colorOfText: ColorConst.textSecondary,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            smcText(
              textToDisplay: '${announcement.publishDate.day}/${announcement.publishDate.month}/${announcement.publishDate.year}',
              textSize: 12,
              colorOfText: ColorConst.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const smcText(
          textToDisplay: 'Notifications & Announcements',
          textSize: 16,
          textBoldness: 5,
          colorOfText: ColorConst.textPrimary,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: announcements.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none_outlined, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const smcText(
                        textToDisplay: 'No announcements currently available',
                        textSize: 14,
                        colorOfText: ColorConst.textSecondary,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: announcements.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                  itemBuilder: (ctx, i) => _buildAnnouncementCard(announcements[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildSelectedView() {
    switch (selectedMenuIndex) {
      case 0:
        return _buildDashboardView();

      case 1:
        return _buildProfileView();

      case 2:
        return StudentCoursesPage(
          student: studentProfile!,
          orgId: scopedOrgId,
        );

      case 3:
        return _buildClassesView();

      case 4:
        return const Center(
          child: Text('Assignments'),
        );

      case 5:
        return const Center(
          child: Text('Leave & Requests'),
        );

      case 6:
        return _buildNotificationsView();

      case 7:
        return const Center(
          child: Text('Settings'),
        );

      default:
        return _buildDashboardView();
    }
  }

  Widget _buildClassesView() {
    return StudentClassesPage(
      orgId: scopedOrgId,
      student: studentProfile!,
      enrolledCourses: enrolledCourses,
    );
  }

  Widget _buildDashboardView() {
    final courses = enrolledCourses;
    final totalCredits = courses.fold<int>(
      0,
      (sum, course) => sum + (int.tryParse(course.credits) ?? 0),
    );
    final String cgpaDisplay = () {
      final String cgpa = (studentProfile?.cgpa ?? '').trim();
      return cgpa.isEmpty ? 'NA' : cgpa;
    }();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const smcText(
              textToDisplay: 'USN: ',
              textSize: 14,
              colorOfText: ColorConst.textSecondary,
            ),
            smcText(
              textToDisplay: (studentProfile?.studentId ?? '').trim().isEmpty
                  ? '—'
                  : studentProfile!.studentId,
              textSize: 14,
              textBoldness: 5,
              colorOfText: ColorConst.textPrimary,
            ),
          ],
        ),
        if (departmentDisplayName.isNotEmpty) ...[
          const SizedBox(height: 4),
          smcText(
            textToDisplay: departmentDisplayName,
            textSize: 13,
            colorOfText: ColorConst.textSecondary,
          ),
        ],
        const SizedBox(height: 20),
        const smcText(
          textToDisplay: 'Student Overview',
          textSize: 16,
          textBoldness: 5,
          colorOfText: ColorConst.textPrimary,
        ),
        const SizedBox(height: 16),
        if (_isMobileLayout(context)) ...[
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Enrolled\nCourses',
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
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'My\nCGPA',
                  count: cgpaDisplay,
                  icon: Icons.school_rounded,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'My\nAttendance',
                  count: '40.5 %',
                  icon: Icons.event_available_rounded,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Enrolled\nCourses',
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
                  title: 'My\nCGPA',
                  count: cgpaDisplay,
                  icon: Icons.school_rounded,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'My\nAttendance',
                  count: '40.5 %',
                  icon: Icons.event_available_rounded,
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
        if (announcements.isEmpty)
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
          )
        else
          ...announcements.take(3).map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildAnnouncementCard(a),
          )),
        ],
      );

  }

  Widget _buildProfileView() {
    final student = studentProfile!;

    return PersonDetailPage(
      key: ValueKey<String>(
        student.documentId?.isNotEmpty == true
            ? student.documentId!
            : student.studentId,
      ),
      person: student,
      isStudent: true,
      embedded: true,
      embeddedMaximized: true,
      showLeadingAction: false,
      showEmbeddedHeader: !_isMobileLayout(context),
      allowStudentProfileEdit: true,
      onStudentProfileUpdated: (updated) {
        setState(() => studentProfile = updated);
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
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
                  textSize: 22,
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
    final student = studentProfile;
    final String name = student?.fullName ?? widget.displayName;
    final String initial = name.trim().isEmpty
        ? 'S'
        : name.trim().substring(0, 1).toUpperCase();
    final String photoUrl = normalizeProfilePhotoUrl(
      student?.photographUrl ?? '',
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

          Expanded(
          child: ListView(
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
                                'Welcome, ${(studentProfile?.fullName ?? '').trim().isNotEmpty ? studentProfile!.fullName : widget.displayName}',
                            textSize: 14,
                            textBoldness: 5,
                            colorOfText: ColorConst.textPrimary,
                            maxLines: 1,
                          ),
                          const smcText(
                            textToDisplay: 'Student Portal',
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
                    title: 'Courses',
                    icon: Icons.menu_book_outlined,
                    isSelected: selectedMenuIndex == 2,
                    onTap: () => setState(() => selectedMenuIndex = 2),
                  ),
                  const SizedBox(height: 8),

                  _menuTile(
                    title: 'Classes',
                    icon: Icons.class_outlined,
                    isSelected: selectedMenuIndex == 3,
                    onTap: () => setState(() => selectedMenuIndex = 3),
                  ),
                  const SizedBox(height: 8),

                  _menuTile(
                    title: 'Assignments',
                    icon: Icons.assignment_outlined,
                    isSelected: selectedMenuIndex == 4,
                    onTap: () => setState(() => selectedMenuIndex = 4),
                  ),
                  const SizedBox(height: 8),

                  _menuTile(
                    title: 'Leave & Requests',
                    icon: Icons.event_note_outlined,
                    isSelected: selectedMenuIndex == 5,
                    onTap: () => setState(() => selectedMenuIndex = 5),
                  ),
                  const SizedBox(height: 8),

                  _menuTile(
                    title: 'Notifications',
                    icon: Icons.notifications_none_outlined,
                    isSelected: selectedMenuIndex == 6,
                    onTap: () => setState(() => selectedMenuIndex = 6),
                  ),
                  const SizedBox(height: 8),

                  _menuTile(
                    title: 'Settings',
                    icon: Icons.settings_outlined,
                    isSelected: selectedMenuIndex == 7,
                    onTap: () => setState(() => selectedMenuIndex = 7),
                  ),
          ],
          ),
          ),

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
