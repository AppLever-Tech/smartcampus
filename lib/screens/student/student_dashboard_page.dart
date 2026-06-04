import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/org_field.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/data/user_org_scope.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/screens/auth/landing_page.dart';
import 'package:smartcampus/screens/shared/person_detail_page.dart';
import 'package:smartcampus/screens/student/student_profile_not_found_page.dart';
import 'package:smartcampus/services/course_firestore_service.dart';
import 'package:smartcampus/services/org_role_firestore_service.dart';
import 'package:smartcampus/services/student_firestore_service.dart';
import 'package:smartcampus/services/user_master_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';

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

  UserOrgScope? _orgScope;
  StreamSubscription<List<CourseModel>>? _courseSubscription;

  String get scopedOrgId =>
      _orgScope?.orgId ?? OrgField.normalize(widget.orgId);

  bool loading = true;
  bool coursesLoaded = false;
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
        coursesLoaded = true;
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
    await FirebaseAuth.instance.signOut();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LandingPage()),
      (route) => false,
    );
  }

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

    final String welcomeName = studentProfile!.fullName;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Row(
          children: [
            _buildSidebar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildSelectedView(welcomeName),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedView(String welcomeName) {
    if (selectedMenuIndex == 1) {
      return _buildProfileView();
    }
    return _buildDashboardView(welcomeName);
  }

  Widget _buildDashboardView(String welcomeName) {
    final courses = enrolledCourses;
    final totalCredits = courses.fold<int>(
      0,
      (sum, course) => sum + (int.tryParse(course.credits) ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        smcText(
          textToDisplay: 'Welcome, $welcomeName',
          textSize: 20,
          textBoldness: 5,
          colorOfText: ColorConst.textPrimary,
        ),
        const SizedBox(height: 6),
        smcText(
          textToDisplay: organizationDisplayName,
          textSize: 14,
          colorOfText: ColorConst.textSecondary,
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
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Enrolled Courses',
                count: courses.length.toString(),
                icon: Icons.menu_book_rounded,
                color: ColorConst.primaryBlue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'Total Credits',
                count: totalCredits.toString(),
                icon: Icons.star_outline_rounded,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'USN',
                count: studentProfile?.studentId ?? '—',
                icon: Icons.badge_outlined,
                color: Colors.orange,
                compactValue: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3EAF8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const smcText(
                  textToDisplay: 'My Enrolled Courses',
                  textSize: 16,
                  textBoldness: 5,
                  colorOfText: ColorConst.textPrimary,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: !coursesLoaded
                      ? const Center(child: CircularProgressIndicator())
                      : courses.isEmpty
                          ? const Center(
                              child: smcText(
                                textToDisplay:
                                    'No enrolled courses yet. Your department admin will enroll you in courses.',
                                textSize: 14,
                                colorOfText: ColorConst.textSecondary,
                                maxLines: 3,
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.separated(
                              itemCount: courses.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                return _buildCourseListTile(courses[index]);
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseListTile(CourseModel course) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3EAF8)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: ColorConst.primaryBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                smcText(
                  textToDisplay: course.courseTitle,
                  textSize: 14,
                  textBoldness: 4,
                  colorOfText: ColorConst.textPrimary,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                smcText(
                  textToDisplay:
                      '${course.courseCode} • ${course.credits} credits • ${course.semester}',
                  textSize: 12,
                  colorOfText: ColorConst.textSecondary,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
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
                    const Expanded(
                      child: smcText(
                        textToDisplay: 'Student Portal',
                        textSize: 18,
                        textBoldness: 5,
                        colorOfText: ColorConst.textPrimary,
                        maxLines: 1,
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
            else
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Expand menu',
                color: ColorConst.primaryBlue,
                onPressed: () => setState(() => sidebarExpanded = true),
              ),
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
