import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/data/org_field.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/data/user_org_scope.dart';
import 'package:smartcampus/models/announcement_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/models/leave_request_model.dart';
import 'package:smartcampus/models/meeting_model.dart';
import 'package:smartcampus/screens/auth/landing_page.dart';
import 'package:smartcampus/screens/shared/person_detail_page.dart';
import 'package:smartcampus/screens/student/student_class_management/student_classes_page.dart';
import 'package:smartcampus/screens/student/student_courses_page.dart';
import 'package:smartcampus/screens/student/student_course_registration/student_course_registration_page.dart';
import 'package:smartcampus/screens/student/student_dashboard_mobile_layout.dart';
import 'package:smartcampus/screens/student/student_profile_not_found_page.dart';
import 'package:smartcampus/services/announcement_firestore_service.dart';
import 'package:smartcampus/services/course_firestore_service.dart';
import 'package:smartcampus/services/faculty_firestore_service.dart';
import 'package:smartcampus/services/leave_request_firestore_service.dart';
import 'package:smartcampus/services/meeting_firestore_service.dart';
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
  final FacultyFirestoreService facultyService = FacultyFirestoreService();
  final MeetingFirestoreService meetingService = MeetingFirestoreService();

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
  FacultyModel? proctorProfile;

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

      // Fetch proctor profile if assigned
      if (resolvedStudent?.proctorId != null && resolvedStudent!.proctorId.isNotEmpty) {
        _fetchProctorProfile(resolvedStudent.proctorId, scope.orgId);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => loading = false);
    }
  }

  Future<void> _fetchProctorProfile(String proctorId, String orgId) async {
    try {
      final facultyList = await facultyService.listFacultyForOrg(orgId);
      final proctor = facultyList.firstWhere(
            (f) => f.documentId == proctorId || f.facultyId == proctorId,
        orElse: () => facultyList.firstWhere(
              (f) => f.documentId == proctorId,
          orElse: () => facultyList.first,
        ),
      );
      if (mounted) {
        setState(() => proctorProfile = proctor);
      }
    } catch (_) {
      // Proctor not found or error fetching
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
        myProctorContent: _buildMyProctorView(),
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
        return _buildMyProctorView();

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

  Widget _buildMyProctorView() {
    int selectedFilter = 0; // 0: Meetings, 1: Leave Request

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Blue header with proctor name and ID
            if (proctorProfile != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: ColorConst.primaryBlue,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    _buildProctorAvatar(radius: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          smcText(
                            textToDisplay: proctorProfile!.fullName,
                            textSize: 18,
                            textBoldness: 5,
                            colorOfText: Colors.white,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 4),
                          smcText(
                            textToDisplay: 'Faculty ID: ${proctorProfile!.facultyId}',
                            textSize: 13,
                            colorOfText: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.person_off_outlined, size: 32, color: Colors.grey),
                    SizedBox(width: 16),
                    smcText(
                      textToDisplay: 'No proctor assigned',
                      textSize: 16,
                      colorOfText: ColorConst.textSecondary,
                    ),
                  ],
                ),
              ),

            // Filter Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE3EAF8)),
                ),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildProctorFilterChip(
                    label: 'Meetings',
                    isSelected: selectedFilter == 0,
                    onTap: () => setState(() => selectedFilter = 0),
                  ),
                  _buildProctorFilterChip(
                    label: 'Leave Request',
                    isSelected: selectedFilter == 1,
                    onTap: () => setState(() => selectedFilter = 1),
                  ),
                ],
              ),
            ),

            // Content based on filter
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: _buildProctorFilterContent(selectedFilter),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProctorFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF0FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? ColorConst.primaryBlue : const Color(0xFFE3EAF8),
            width: 1,
          ),
        ),
        child: smcText(
          textToDisplay: label,
          textSize: 13,
          textBoldness: isSelected ? 5 : 4,
          colorOfText: isSelected ? ColorConst.primaryBlue : ColorConst.textSecondary,
        ),
      ),
    );
  }

  Widget _buildProctorAvatar({required double radius}) {
    final String name = proctorProfile?.fullName ?? 'Proctor';
    final String initial = name.trim().isEmpty
        ? 'P'
        : name.trim().substring(0, 1).toUpperCase();
    final String photoUrl = normalizeProfilePhotoUrl(
        proctorProfile?.photographUrl ?? '');

    return ProfilePhotoAvatar(
      photoUrl: photoUrl,
      fallbackInitial: initial,
      radius: radius,
    );
  }

  Widget _buildProctorFilterContent(int filterIndex) {
    switch (filterIndex) {
      case 0:
        return _buildMeetingsView();
      case 1:
        return _buildLeaveRequestView();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMeetingsView() {
    if (studentProfile == null) {
      return const Center(
        child: smcText(
          textToDisplay: 'Student profile not loaded',
          textSize: 14,
          colorOfText: ColorConst.textSecondary,
        ),
      );
    }

    return StreamBuilder<List<MeetingModel>>(
      stream: meetingService.getMeetingsForStudent(studentProfile!.resolvedUuid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final meetings = snapshot.data ?? [];

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3EAF8)),
          ),
          child: meetings.isEmpty
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event,
                  size: 48,
                  color: ColorConst.textSecondary,
                ),
                SizedBox(height: 16),
                smcText(
                  textToDisplay: 'No meetings scheduled yet',
                  textSize: 14,
                  colorOfText: ColorConst.textSecondary,
                ),
              ],
            ),
          )
              : LayoutBuilder(
            builder: (context, constraints) {
              final double tableWidth = constraints.maxWidth;
              return SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: tableWidth),
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowHeight: 50,
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 58,
                      horizontalMargin: 0,
                      columnSpacing: 0,
                      dividerThickness: 1,
                      border: TableBorder.all(
                        color: const Color(0xFFE3EAF8),
                        width: 1,
                      ),
                      headingRowColor: MaterialStateProperty.all(
                        const Color(0xFFF4F7FF),
                      ),
                      columns: const [
                        DataColumn(label: SizedBox(width: 50, child: Center(child: smcText(textToDisplay: 'S.No', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                        DataColumn(label: SizedBox(width: 100, child: Padding(padding: EdgeInsets.only(left: 8), child: Align(alignment: Alignment.centerLeft, child: smcText(textToDisplay: 'Date', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B)))))),
                        DataColumn(label: SizedBox(width: 80, child: Center(child: smcText(textToDisplay: 'Time', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                        DataColumn(label: SizedBox(width: 140, child: Padding(padding: EdgeInsets.only(left: 8), child: Align(alignment: Alignment.centerLeft, child: smcText(textToDisplay: 'Type', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B)))))),
                        DataColumn(label: SizedBox(width: 250, child: Padding(padding: EdgeInsets.only(left: 8), child: Align(alignment: Alignment.centerLeft, child: smcText(textToDisplay: 'Purpose', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B)))))),
                        DataColumn(label: SizedBox(width: 120, child: Center(child: smcText(textToDisplay: 'Status', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                        DataColumn(label: SizedBox(width: 250, child: Padding(padding: EdgeInsets.only(left: 8), child: Align(alignment: Alignment.centerLeft, child: smcText(textToDisplay: 'Meeting Minutes', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B)))))),
                      ],
                      rows: meetings.asMap().entries.map((entry) {
                        final int index = entry.key;
                        final MeetingModel m = entry.value;
                        final int serialNo = index + 1;
                        return DataRow(
                          cells: [
                            DataCell(
                              Center(
                                child: smcText(
                                  textToDisplay: '$serialNo',
                                  textSize: 12,
                                  colorOfText: const Color(0xFF2E3954),
                                ),
                              ),
                            ),
                            DataCell(
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: smcText(
                                    textToDisplay: _formatDisplayDate(m.date),
                                    textSize: 12,
                                    textBoldness: 4,
                                    colorOfText: const Color(0xFF2E3954),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Center(
                                child: smcText(
                                  textToDisplay: m.time,
                                  textSize: 12,
                                  colorOfText: const Color(0xFF2E3954),
                                ),
                              ),
                            ),
                            DataCell(
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: m.type == 'Academic Review' ? const Color(0xFFEFF4FF) : const Color(0xFFF5F3FF),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: smcText(
                                      textToDisplay: m.type,
                                      textSize: 11,
                                      textBoldness: 4,
                                      colorOfText: m.type == 'Academic Review' ? ColorConst.primaryBlue : const Color(0xFF7E22CE),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: smcText(
                                    textToDisplay: m.purpose,
                                    textSize: 12,
                                    colorOfText: const Color(0xFF2E3954),
                                    maxLines: 2,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: m.status == 'Scheduled' ? const Color(0xFFFFF8E1) : const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: smcText(
                                    textToDisplay: m.status,
                                    textSize: 11,
                                    textBoldness: 4,
                                    colorOfText: m.status == 'Scheduled' ? const Color(0xFFF57C00) : const Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: smcText(
                                    textToDisplay: m.minutes,
                                    textSize: 12,
                                    colorOfText: const Color(0xFF2E3954),
                                    maxLines: 3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatDisplayDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final d = DateTime.parse(isoDate);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (e) {
      return isoDate;
    }
  }

  // ─── Leave Request View ───────────────────────────────────────────────────

  final LeaveRequestFirestoreService _leaveService =
  LeaveRequestFirestoreService();

  Widget _buildLeaveRequestView() {
    final String studentId =
        studentProfile?.studentId ?? widget.uuid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Create Leave Request button
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () => _showCreateLeaveRequestDialog(),
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: const Text(
              'Create Leave Request',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorConst.primaryBlue,
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Leave requests table
        Expanded(
          child: StreamBuilder<List<LeaveRequestModel>>(
            stream: _leaveService.getLeaveRequestsForStudent(
                studentId: studentId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final requests = snapshot.data ?? [];
              if (requests.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_note,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const smcText(
                        textToDisplay: 'No leave requests submitted yet',
                        textSize: 14,
                        colorOfText: ColorConst.textSecondary,
                      ),
                    ],
                  ),
                );
              }
              return SingleChildScrollView(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Table(
                    border: TableBorder.all(
                      color: const Color(0xFFE3EAF8),
                      width: 1,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    columnWidths: const {
                      0: FixedColumnWidth(50),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(3),
                      3: FlexColumnWidth(2),
                      4: FlexColumnWidth(2),
                    },
                    children: [
                      // Header row
                      TableRow(
                        decoration: const BoxDecoration(
                          color: Color(0xFFEAF0FF),
                        ),
                        children: [
                          _tableHeader('Sl. No'),
                          _tableHeader('Requested Date'),
                          _tableHeader('Reason'),
                          _tableHeader('Attachment'),
                          _tableHeader('Status'),
                        ],
                      ),
                      // Data rows
                      ...requests.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final req = entry.value;
                        final isEven = idx % 2 == 0;
                        return TableRow(
                          decoration: BoxDecoration(
                            color: isEven
                                ? Colors.white
                                : const Color(0xFFFAFBFF),
                          ),
                          children: [
                            _tableCell(
                              '${idx + 1}',
                              center: true,
                            ),
                            _tableCell(
                              '${req.createdAt.day.toString().padLeft(2, '0')}/${req.createdAt.month.toString().padLeft(2, '0')}/${req.createdAt.year}',
                            ),
                            _tableCell(req.reason, maxLines: 2),
                            // Attachment cell
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: req.attachmentUrl.isNotEmpty
                                  ? InkWell(
                                onTap: () async {
                                  final uri =
                                  Uri.parse(req.attachmentUrl);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri,
                                        mode: LaunchMode
                                            .externalApplication);
                                  }
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.attach_file_rounded,
                                      size: 16,
                                      color: ColorConst.primaryBlue,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: smcText(
                                        textToDisplay: req
                                            .attachmentName
                                            .isNotEmpty
                                            ? req.attachmentName
                                            : 'View',
                                        textSize: 12,
                                        colorOfText:
                                        ColorConst.primaryBlue,
                                        decoration:
                                        TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                                  : const smcText(
                                textToDisplay: '—',
                                textSize: 13,
                                colorOfText: ColorConst.textSecondary,
                              ),
                            ),
                            // Status chip cell
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: _buildLeaveStatusChip(req.status),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: smcText(
        textToDisplay: text,
        textSize: 12,
        textBoldness: 4,
        colorOfText: ColorConst.primaryBlue,
      ),
    );
  }

  Widget _tableCell(String text,
      {bool center = false, int maxLines = 2}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: smcText(
        textToDisplay: text,
        textSize: 13,
        colorOfText: ColorConst.textPrimary,
        textAlign: center ? TextAlign.center : TextAlign.left,
        maxLines: maxLines,
      ),
    );
  }

  Widget _buildLeaveStatusChip(String status) {
    Color bgColor;
    Color textColor;
    IconData icon;
    switch (status) {
      case 'Approved':
        bgColor = const Color(0xFFE6F9F0);
        textColor = const Color(0xFF1B7F4F);
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'Rejected':
        bgColor = const Color(0xFFFFECEA);
        textColor = const Color(0xFFD93025);
        icon = Icons.cancel_outlined;
        break;
      default: // Pending
        bgColor = const Color(0xFFFFF8E1);
        textColor = const Color(0xFFB07B00);
        icon = Icons.hourglass_empty_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateLeaveRequestDialog() async {
    final formKey = GlobalKey<FormState>();
    String selectedLeaveType = LeaveRequestModel.leaveTypes.first;
    DateTime? fromDate;
    DateTime? toDate;
    final reasonController = TextEditingController();
    String? attachmentFileName;
    Uint8List? attachmentBytes;
    bool submitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> pickFromDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: ctx,
                initialDate: fromDate ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 1),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: ColorConst.primaryBlue,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setDialogState(() => fromDate = picked);
              }
            }

            Future<void> pickToDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: ctx,
                initialDate: toDate ?? fromDate ?? now,
                firstDate: fromDate ?? DateTime(now.year - 1),
                lastDate: DateTime(now.year + 1),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: ColorConst.primaryBlue,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setDialogState(() => toDate = picked);
              }
            }

            Future<void> pickAttachment() async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: [
                  'jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'
                ],
                withData: true,
              );
              if (result != null && result.files.isNotEmpty) {
                final file = result.files.first;
                setDialogState(() {
                  attachmentFileName = file.name;
                  attachmentBytes = file.bytes;
                });
              }
            }

            String formatDate(DateTime? d) {
              if (d == null) return 'Select date';
              return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
            }

            Future<void> submitLeaveRequest() async {
              if (!formKey.currentState!.validate()) return;
              if (fromDate == null || toDate == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('Please select From and To dates')),
                );
                return;
              }
              setDialogState(() => submitting = true);
              try {
                String uploadedUrl = '';
                String uploadedName = '';
                if (attachmentBytes != null && attachmentFileName != null) {
                  uploadedUrl = await _leaveService.uploadAttachment(
                    fileName: attachmentFileName!,
                    bytes: attachmentBytes!,
                    studentId:
                    studentProfile?.studentId ?? widget.uuid,
                  );
                  uploadedName = attachmentFileName!;
                }
                final request = LeaveRequestModel(
                  id: '',
                  orgId: scopedOrgId,
                  deptId: _orgScope?.deptId ?? widget.deptId,
                  studentId:
                  studentProfile?.studentId ?? widget.uuid,
                  studentName: studentProfile?.fullName ??
                      widget.displayName,
                  proctorId: studentProfile?.proctorId ?? '',
                  leaveType: selectedLeaveType,
                  fromDate: fromDate!,
                  toDate: toDate!,
                  reason: reasonController.text.trim(),
                  attachmentUrl: uploadedUrl,
                  attachmentName: uploadedName,
                  status: 'Pending',
                  createdAt: DateTime.now(),
                );
                await _leaveService.createLeaveRequest(request);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                          'Leave request submitted successfully'),
                      backgroundColor: const Color(0xFF1B7F4F),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              } catch (e) {
                setDialogState(() => submitting = false);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dialog header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 18),
                        decoration: const BoxDecoration(
                          color: ColorConst.primaryBlue,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event_note_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: smcText(
                                textToDisplay: 'Create Leave Request',
                                textSize: 17,
                                textBoldness: 5,
                                colorOfText: Colors.white,
                              ),
                            ),
                            IconButton(
                              onPressed: submitting
                                  ? null
                                  : () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close,
                                  color: Colors.white70, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      // Scrollable form body
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Leave Type
                              const smcText(
                                textToDisplay: 'Leave Type',
                                textSize: 13,
                                textBoldness: 3,
                                colorOfText: ColorConst.textPrimary,
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: selectedLeaveType,
                                decoration: InputDecoration(
                                  contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFDCE2F4),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFDCE2F4)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: ColorConst.primaryBlue,
                                        width: 1.5),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8F9FF),
                                ),
                                items: LeaveRequestModel.leaveTypes
                                    .map((type) =>
                                    DropdownMenuItem(
                                      value: type,
                                      child: Text(type),
                                    ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() =>
                                    selectedLeaveType = val);
                                  }
                                },
                                validator: (val) => val == null
                                    ? 'Please select leave type'
                                    : null,
                              ),
                              const SizedBox(height: 18),
                              // Date row
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        const smcText(
                                          textToDisplay: 'From Date',
                                          textSize: 13,
                                          textBoldness: 3,
                                          colorOfText:
                                          ColorConst.textPrimary,
                                        ),
                                        const SizedBox(height: 8),
                                        GestureDetector(
                                          onTap: pickFromDate,
                                          child: Container(
                                            padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 13),
                                            decoration: BoxDecoration(
                                              color:
                                              const Color(0xFFF8F9FF),
                                              borderRadius:
                                              BorderRadius.circular(
                                                  10),
                                              border: Border.all(
                                                color: fromDate != null
                                                    ? ColorConst.primaryBlue
                                                    : const Color(
                                                    0xFFDCE2F4),
                                                width: fromDate != null
                                                    ? 1.5
                                                    : 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons
                                                      .calendar_today_outlined,
                                                  size: 16,
                                                  color: fromDate != null
                                                      ? ColorConst.primaryBlue
                                                      : ColorConst
                                                      .textSecondary,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    formatDate(fromDate),
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: fromDate != null
                                                          ? ColorConst
                                                          .textPrimary
                                                          : ColorConst
                                                          .textSecondary,
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
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        const smcText(
                                          textToDisplay: 'To Date',
                                          textSize: 13,
                                          textBoldness: 3,
                                          colorOfText:
                                          ColorConst.textPrimary,
                                        ),
                                        const SizedBox(height: 8),
                                        GestureDetector(
                                          onTap: pickToDate,
                                          child: Container(
                                            padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 13),
                                            decoration: BoxDecoration(
                                              color:
                                              const Color(0xFFF8F9FF),
                                              borderRadius:
                                              BorderRadius.circular(
                                                  10),
                                              border: Border.all(
                                                color: toDate != null
                                                    ? ColorConst.primaryBlue
                                                    : const Color(
                                                    0xFFDCE2F4),
                                                width: toDate != null
                                                    ? 1.5
                                                    : 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons
                                                      .calendar_today_outlined,
                                                  size: 16,
                                                  color: toDate != null
                                                      ? ColorConst.primaryBlue
                                                      : ColorConst
                                                      .textSecondary,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    formatDate(toDate),
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: toDate != null
                                                          ? ColorConst
                                                          .textPrimary
                                                          : ColorConst
                                                          .textSecondary,
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
                                ],
                              ),
                              const SizedBox(height: 18),
                              // Reason
                              const smcText(
                                textToDisplay: 'Reason',
                                textSize: 13,
                                textBoldness: 3,
                                colorOfText: ColorConst.textPrimary,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: reasonController,
                                maxLines: 4,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText:
                                  'Describe the reason for your leave...',
                                  hintStyle: const TextStyle(
                                    fontSize: 13,
                                    color: ColorConst.textSecondary,
                                  ),
                                  contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFDCE2F4)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFDCE2F4)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: ColorConst.primaryBlue,
                                        width: 1.5),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8F9FF),
                                ),
                                validator: (val) =>
                                (val == null || val.trim().isEmpty)
                                    ? 'Please enter a reason'
                                    : null,
                              ),
                              const SizedBox(height: 18),
                              // Attachment
                              const smcText(
                                textToDisplay:
                                'Attachment / Photo (Optional)',
                                textSize: 13,
                                textBoldness: 3,
                                colorOfText: ColorConst.textPrimary,
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: pickAttachment,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F9FF),
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    border: Border.all(
                                      color: attachmentFileName != null
                                          ? ColorConst.primaryBlue
                                          : const Color(0xFFDCE2F4),
                                      width:
                                      attachmentFileName != null ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        attachmentFileName != null
                                            ? Icons.check_circle_outline
                                            : Icons.upload_file_outlined,
                                        size: 20,
                                        color: attachmentFileName != null
                                            ? ColorConst.primaryBlue
                                            : ColorConst.textSecondary,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          attachmentFileName ??
                                              'Click to upload (JPG, PNG, PDF, DOC)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: attachmentFileName !=
                                                null
                                                ? ColorConst.textPrimary
                                                : ColorConst.textSecondary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (attachmentFileName != null)
                                        GestureDetector(
                                          onTap: () => setDialogState(() {
                                            attachmentFileName = null;
                                            attachmentBytes = null;
                                          }),
                                          child: const Icon(
                                            Icons.close,
                                            size: 16,
                                            color: ColorConst.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              // Submit button
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: submitting
                                      ? null
                                      : submitLeaveRequest,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                    ColorConst.primaryBlue,
                                    disabledBackgroundColor:
                                    ColorConst.primaryBlue
                                        .withOpacity(0.6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: submitting
                                      ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                      : const Text(
                                    'Submit',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
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
              ),
            );
          },
        );
      },
    );
    reasonController.dispose();
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

    return SingleChildScrollView(
      child: Column(
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
                    title: 'My Proctor',
                    icon: Icons.supervisor_account_outlined,
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
