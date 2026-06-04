import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/screens/auth/landing_page.dart';
import 'package:smartcampus/screens/shared/course_detail_page.dart';
import 'package:smartcampus/screens/shared/person_detail_page.dart';
import 'package:smartcampus/services/course_firestore_service.dart';
import 'package:smartcampus/services/faculty_firestore_service.dart';
import 'package:smartcampus/services/org_role_firestore_service.dart';
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
  final TextEditingController courseSearchController = TextEditingController();

  bool loading = true;
  bool coursesLoaded = false;
  int selectedMenuIndex = 0;
  bool sidebarExpanded = false;
  bool courseDetailMaximized = false;
  double courseListPanelRatio = 0.55;

  FacultyModel? facultyProfile;
  List<CourseModel> allCourses = [];
  CourseModel? selectedCourseDetail;
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

  List<CourseModel> get filteredAssignedCourses {
    final query = courseSearchController.text.trim().toLowerCase();
    final courses = assignedCourses;
    if (query.isEmpty) {
      return courses;
    }
    return courses.where((course) {
      return course.courseCode.toLowerCase().contains(query) ||
          course.courseTitle.toLowerCase().contains(query) ||
          course.semester.toLowerCase().contains(query) ||
          course.batch.toLowerCase().contains(query) ||
          course.courseType.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    refresh();
    courseService.getCourses().listen((courses) {
      if (!mounted) {
        return;
      }
      setState(() {
        allCourses = courses;
        coursesLoaded = true;
        if (selectedCourseDetail != null) {
          final Iterable<CourseModel> match =
              courses.where((c) => c.id == selectedCourseDetail!.id);
          if (match.isNotEmpty) {
            selectedCourseDetail = match.first;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    courseSearchController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      final resolvedFaculty = await facultyService.resolveFacultyForUser(
        orgId: widget.orgId,
        deptId: widget.deptId,
        displayName: widget.displayName,
        uuid: widget.uuid,
        prefetched: widget.faculty,
      );
      final org =
          await roleService.authService.getOrganizationById(widget.orgId);
      String deptName = widget.deptId;
      if (widget.deptId.isNotEmpty) {
        final departments =
            await roleService.loadDepartmentsForOrg(widget.orgId);
        for (final dept in departments) {
          if (dept.deptId.toUpperCase() == widget.deptId.toUpperCase()) {
            deptName = dept.deptName.isNotEmpty ? dept.deptName : widget.deptId;
            break;
          }
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        facultyProfile = resolvedFaculty;
        organizationDisplayName = (org?.orgName ?? '').trim().isEmpty
            ? widget.orgId
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

  void closeCourseDetail() {
    setState(() {
      selectedCourseDetail = null;
      courseDetailMaximized = false;
    });
  }

  void openCourseDetail(CourseModel course) {
    setState(() {
      selectedCourseDetail = course;
      courseDetailMaximized = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String welcomeName =
        facultyProfile?.fullName ?? widget.displayName;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Row(
          children: [
            _buildSidebar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildSelectedView(welcomeName),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedView(String welcomeName) {
    switch (selectedMenuIndex) {
      case 1:
        return _buildMyCoursesView();
      case 2:
        return _buildProfileView();
      default:
        return _buildDashboardView(welcomeName);
    }
  }

  Widget _buildDashboardView(String welcomeName) {
    final courses = assignedCourses;
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
          textToDisplay: 'Faculty Overview',
          textSize: 16,
          textBoldness: 5,
          colorOfText: ColorConst.textPrimary,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Assigned Courses',
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
                title: 'Faculty ID',
                count: facultyProfile?.facultyId ?? '—',
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
                  textToDisplay: 'Recent Assigned Courses',
                  textSize: 16,
                  textBoldness: 5,
                  colorOfText: ColorConst.textPrimary,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: courses.isEmpty
                      ? const Center(
                          child: smcText(
                            textToDisplay:
                                'No courses assigned yet. Check My Courses for updates.',
                            textSize: 14,
                            colorOfText: ColorConst.textSecondary,
                            maxLines: 2,
                          ),
                        )
                      : ListView.separated(
                          itemCount: courses.length.clamp(0, 5),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final course = courses[index];
                            return _buildCourseListTile(course);
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

  Widget _buildMyCoursesView() {
    if (!coursesLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (selectedCourseDetail == null) {
      return _buildCourseListPanel();
    }

    if (courseDetailMaximized) {
      return _buildCourseDetailPanel(maximized: true);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const double dividerWidth = 10;
        const double minListWidth = 360;
        const double minDetailWidth = 320;
        final double availableWidth =
            (constraints.maxWidth - dividerWidth).clamp(0, double.infinity);

        if (availableWidth <= minListWidth + minDetailWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: _buildCourseListPanel()),
              _buildCoursePanelDivider(constraints.maxWidth),
              Expanded(
                flex: 4,
                child: _buildCourseDetailPanel(maximized: false),
              ),
            ],
          );
        }

        final double listWidth = (availableWidth * courseListPanelRatio)
            .clamp(minListWidth, availableWidth - minDetailWidth);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: listWidth, child: _buildCourseListPanel()),
            _buildCoursePanelDivider(constraints.maxWidth),
            Expanded(child: _buildCourseDetailPanel(maximized: false)),
          ],
        );
      },
    );
  }

  Widget _buildCourseListPanel() {
    final courses = filteredAssignedCourses;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: smcText(
                    textToDisplay: 'My Courses',
                    textSize: 16,
                    textBoldness: 5,
                    colorOfText: ColorConst.textPrimary,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: smcText(
                    textToDisplay: '${assignedCourses.length}',
                    textSize: 12,
                    textBoldness: 4,
                    colorOfText: ColorConst.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: courseSearchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search courses...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Color(0xFF8A96B2),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFF),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: ColorConst.primaryBlue),
                ),
              ),
            ),
          ),
          Expanded(
            child: courses.isEmpty
                ? const Center(
                    child: smcText(
                      textToDisplay: 'No assigned courses found.',
                      textSize: 14,
                      colorOfText: ColorConst.textSecondary,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: courses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final course = courses[index];
                      final bool selected =
                          selectedCourseDetail?.id == course.id;
                      return Material(
                        color: selected
                            ? const Color(0xFFEAF0FF)
                            : const Color(0xFFF8FAFF),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => openCourseDetail(course),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                smcText(
                                  textToDisplay: course.courseTitle,
                                  textSize: 14,
                                  textBoldness: 4,
                                  colorOfText: ColorConst.textPrimary,
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 6),
                                smcText(
                                  textToDisplay:
                                      '${course.courseCode} • Sem ${course.semester} • ${course.batch}',
                                  textSize: 12,
                                  colorOfText: ColorConst.textSecondary,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseDetailPanel({required bool maximized}) {
    final faculty = facultyProfile;
    return CourseDetailPage(
      key: ValueKey<String>(selectedCourseDetail!.id),
      course: selectedCourseDetail!,
      assignedFaculty: faculty != null ? [faculty] : const [],
      enrolledStudents: const [],
      embedded: true,
      embeddedMaximized: maximized,
      readOnly: true,
      onClose: closeCourseDetail,
      onMaximize: maximized
          ? null
          : () => setState(() => courseDetailMaximized = true),
      onBackFromMaximized: maximized
          ? () => setState(() => courseDetailMaximized = false)
          : null,
    );
  }

  Widget _buildCoursePanelDivider(double totalWidth) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          setState(() {
            courseListPanelRatio += details.delta.dx / totalWidth;
            courseListPanelRatio = courseListPanelRatio.clamp(0.3, 0.7);
          });
        },
        child: SizedBox(
          width: 10,
          child: Center(
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD8E2F4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileView() {
    final faculty = facultyProfile;
    if (faculty == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const smcText(
              textToDisplay: 'Faculty profile not found.',
              textSize: 16,
              textBoldness: 4,
              colorOfText: ColorConst.textPrimary,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: refresh,
              child: const smcText(
                textToDisplay: 'Retry',
                textSize: 14,
                colorOfText: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

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
    );
  }

  Widget _buildCourseListTile(CourseModel course) {
    return Material(
      color: const Color(0xFFF8FAFF),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            selectedMenuIndex = 1;
            openCourseDetail(course);
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                          '${course.courseCode} • ${course.credits} credits',
                      textSize: 12,
                      colorOfText: ColorConst.textSecondary,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: ColorConst.textSecondary,
              ),
            ],
          ),
        ),
      ),
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
                        textToDisplay: 'Faculty Portal',
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
              onTap: () => setState(() {
                selectedMenuIndex = 0;
                selectedCourseDetail = null;
                courseDetailMaximized = false;
              }),
            ),
            const SizedBox(height: 8),
            _menuTile(
              title: 'My Courses',
              icon: Icons.menu_book_outlined,
              isSelected: selectedMenuIndex == 1,
              onTap: () => setState(() {
                selectedMenuIndex = 1;
              }),
            ),
            const SizedBox(height: 8),
            _menuTile(
              title: 'Profile',
              icon: Icons.person_outline_rounded,
              isSelected: selectedMenuIndex == 2,
              onTap: () => setState(() {
                selectedMenuIndex = 2;
                selectedCourseDetail = null;
                courseDetailMaximized = false;
              }),
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
