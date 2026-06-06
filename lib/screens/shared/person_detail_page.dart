import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/widgets/smc_text.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/services/course_firestore_service.dart';
import 'package:smartcampus/services/student_firestore_service.dart';
import 'package:smartcampus/widgets/course_list_table.dart';

class PersonDetailPage extends StatefulWidget {
  final dynamic person; // Can be StudentModel or FacultyModel
  final bool isStudent;
  final bool embedded;
  final bool embeddedMaximized;
  final VoidCallback? onClose;
  final VoidCallback? onMaximize;
  final VoidCallback? onBackFromMaximized;
  final VoidCallback? onEditStudent;
  /// When true, student can edit their own profile (except Student ID).
  final bool allowStudentProfileEdit;
  final ValueChanged<StudentModel>? onStudentProfileUpdated;
  /// When false, hides back/close in the embedded header (e.g. student own profile).
  final bool showLeadingAction;
  /// When false, hides the blue embedded header (e.g. student mobile profile tab).
  final bool showEmbeddedHeader;

  const PersonDetailPage({
    super.key,
    required this.person,
    required this.isStudent,
    this.embedded = false,
    this.embeddedMaximized = false,
    this.onClose,
    this.onMaximize,
    this.onBackFromMaximized,
    this.onEditStudent,
    this.allowStudentProfileEdit = false,
    this.onStudentProfileUpdated,
    this.showLeadingAction = true,
    this.showEmbeddedHeader = true,
  });

  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends State<PersonDetailPage> {
  int _selectedIndex = 0;
  String _selectedEnrolledSemester = 'I';
  final CourseFirestoreService _courseService = CourseFirestoreService();
  final StudentFirestoreService _studentService = StudentFirestoreService();
  Stream<List<CourseModel>>? _enrolledCoursesStream;
  final Map<String, Map<String, String>> _enrolledCourseMarks = {};
  final Map<String, String> _semesterSgpaBySemester = {};
  String _cgpa = '';
  bool _loadingEnrolledCourseMarks = false;
  bool _savingEnrolledCourseMarks = false;
  StudentModel? _studentProfileOverride;

  StudentModel get _studentModel => _studentProfileOverride ??
      widget.person as StudentModel;

  static const List<String> _enrolledSemesterOptions = [
    'I',
    'II',
    'III',
    'IV',
  ];

  String get _name => widget.isStudent
      ? (widget.person as StudentModel).fullName
      : (widget.person as FacultyModel).fullName;

  String get _id => widget.isStudent
      ? (widget.person as StudentModel).studentId
      : (widget.person as FacultyModel).facultyId;

  String get _idLabel => widget.isStudent ? 'USN' : 'Faculty ID';

  @override
  void initState() {
    super.initState();
    _bindEnrolledCoursesStream();
    _loadEnrolledCourseMarks();
  }

  @override
  void didUpdateWidget(PersonDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStudent &&
        widget.person is StudentModel &&
        (oldWidget.person is! StudentModel ||
            (oldWidget.person as StudentModel).orgId !=
                (widget.person as StudentModel).orgId ||
            (oldWidget.person as StudentModel).documentId !=
                (widget.person as StudentModel).documentId)) {
      _bindEnrolledCoursesStream();
      _loadEnrolledCourseMarks();
      _studentProfileOverride = null;
    }
  }

  void _seedEnrolledCourseMarksFromStudent(StudentModel student) {
    _enrolledCourseMarks
      ..clear()
      ..addAll(
        student.enrolledCourseMarks.map(
          (courseId, marks) => MapEntry(
            courseId,
            Map<String, String>.from(marks),
          ),
        ),
      );
    _semesterSgpaBySemester
      ..clear()
      ..addAll(student.semesterSgpa);
    _cgpa = student.cgpa.trim();
  }

  String _sgpaDisplayForSemester(String semester) {
    final String value = _semesterSgpaBySemester[semester]?.trim() ?? '';
    return value.isEmpty ? 'NA' : value;
  }

  String _cgpaDisplay() {
    return _cgpa.trim().isEmpty ? 'NA' : _cgpa.trim();
  }

  Future<void> _loadEnrolledCourseMarks() async {
    if (!widget.isStudent || widget.person is! StudentModel) {
      return;
    }

    final StudentModel student = widget.person as StudentModel;
    _seedEnrolledCourseMarksFromStudent(student);

    final String? documentId = student.documentId?.trim();
    if (documentId == null || documentId.isEmpty) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    setState(() => _loadingEnrolledCourseMarks = true);
    try {
      final StudentModel? fresh =
          await _studentService.getStudentByDocumentId(documentId);
      if (fresh != null && mounted) {
        _seedEnrolledCourseMarksFromStudent(fresh);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingEnrolledCourseMarks = false);
      }
    }
  }

  void _bindEnrolledCoursesStream() {
    if (!widget.isStudent || widget.person is! StudentModel) {
      _enrolledCoursesStream = null;
      return;
    }
    final StudentModel student = widget.person as StudentModel;
    _enrolledCoursesStream =
        _courseService.getCoursesForOrg(orgId: student.orgId);
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTabBar(),
        Expanded(child: _buildSelectedView()),
      ],
    );

    if (widget.embedded) {
      return SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7FB),
            borderRadius: widget.embeddedMaximized
                ? BorderRadius.zero
                : BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3EAF8)),
          ),
          child: ClipRRect(
            borderRadius: widget.embeddedMaximized
                ? BorderRadius.zero
                : BorderRadius.circular(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.showEmbeddedHeader) _buildEmbeddedHeader(),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: ColorConst.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            smcText(
              textToDisplay: _name,
              textSize: 16,
              textBoldness: 5,
              colorOfText: Colors.white,
            ),
            smcText(
              textToDisplay: '$_idLabel: $_id',
              textSize: 12,
              colorOfText: Colors.white.withOpacity(0.8),
            ),
          ],
        ),
      ),
      body: body,
    );
  }

  Widget _buildEmbeddedHeader() {
    final bool isMaximized = widget.embeddedMaximized;

    return Container(
      color: ColorConst.primaryBlue,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          if (widget.showLeadingAction)
            IconButton(
              icon: Icon(
                isMaximized ? Icons.arrow_back_rounded : Icons.close_rounded,
                color: Colors.white,
              ),
              tooltip: isMaximized ? 'Back' : 'Close',
              onPressed: isMaximized
                  ? widget.onBackFromMaximized
                  : widget.onClose,
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                smcText(
                  textToDisplay: _name,
                  textSize: 15,
                  textBoldness: 5,
                  colorOfText: Colors.white,
                  maxLines: 1,
                ),
                smcText(
                  textToDisplay: '$_idLabel: $_id',
                  textSize: 11,
                  colorOfText: Colors.white.withOpacity(0.85),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          if (!isMaximized && widget.onMaximize != null)
            IconButton(
              icon: const Icon(Icons.open_in_new, color: Colors.white),
              tooltip: 'Maximize',
              onPressed: widget.onMaximize,
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final List<String> tabs = _tabLabels;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < tabs.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              _buildFilterChip(tabs[i], i),
            ],
          ],
        ),
      ),
    );
  }

  List<String> get _tabLabels {
    if (widget.isStudent) {
      return const [
        'Basic Details',
        'Enrolled Courses',
        'Achievements',
        'Publications',
      ];
    }
    return const [
      'Basic Details',
      'Assigned Courses',
      'Achievements',
      'Publications',
    ];
  }

  Widget _buildFilterChip(String label, int index) {
    final bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F0FE) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF1967D2) : const Color(0xFFD1D5DB),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 14, color: Color(0xFF1967D2)),
              const SizedBox(width: 6),
            ],
            smcText(
              textToDisplay: label,
              textSize: 13,
              textBoldness: isSelected ? 4 : 3,
              colorOfText: isSelected ? const Color(0xFF1967D2) : const Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedView() {
    final String tab = _tabLabels[_selectedIndex.clamp(0, _tabLabels.length - 1)];

    switch (tab) {
      case 'Basic Details':
        return _buildBasicDetails();
      case 'Enrolled Courses':
        return _buildCoursesOpted();
      case 'Assigned Courses':
        return _buildAssignedCourses();
      case 'Achievements':
        return _buildAchievements();
      case 'Publications':
        return _buildPublications();
      default:
        return _buildBasicDetails();
    }
  }

  Widget _buildBasicDetails() {
    if (widget.isStudent) {
      return _buildStudentBasicDetails();
    }
    return _buildFacultyBasicDetails();
  }

  Widget _buildAssignedCourses() {
    final FacultyModel faculty = widget.person as FacultyModel;

    return StreamBuilder<List<CourseModel>>(
      stream: _courseService.getCoursesForOrg(orgId: faculty.orgId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<CourseModel> assignedCourses =
            CourseFirestoreService.filterCoursesForFaculty(
          snapshot.data ?? const <CourseModel>[],
          faculty,
        )..sort(
            (a, b) => a.courseTitle
                .toLowerCase()
                .compareTo(b.courseTitle.toLowerCase()),
          );

        if (assignedCourses.isEmpty) {
          return const Center(
            child: smcText(
              textToDisplay: 'No courses assigned yet.',
              textSize: 14,
              colorOfText: ColorConst.textSecondary,
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool useTable = constraints.maxWidth >= 600;

            if (useTable) {
              return Padding(
                padding: const EdgeInsets.all(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE3EAF8)),
                  ),
                  child: CourseListTable(
                    courses: assignedCourses,
                    totalsCourses: assignedCourses,
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: assignedCourses.map((course) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: smcText(
                        textToDisplay: course.courseTitle,
                        textSize: 14,
                        textBoldness: 4,
                        colorOfText: ColorConst.textPrimary,
                        maxLines: 2,
                      ),
                      subtitle: smcText(
                        textToDisplay:
                            'Code: ${course.courseCode} • Sem ${course.semester} • ${course.credits} credits',
                        textSize: 12,
                        colorOfText: ColorConst.textSecondary,
                        maxLines: 2,
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }
  Widget _buildFacultyBasicDetails() {
    final FacultyModel f = widget.person as FacultyModel;
    final String photoUrl = _normalizePhotoUrl(f.photographUrl);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfilePhotographLayout(
            photoUrl: photoUrl,
            profileSection: _buildDetailsSection(
              title: 'Basic Profile Information',
              icon: Icons.person_outline_rounded,
              children: [
                _buildDetailRow('Faculty ID', f.facultyId),
                _buildDetailRow('Full Name', f.fullName),
                _buildDetailRow('Gender', f.gender),
                _buildDetailRow(
                  'Date of Birth',
                  _formatDisplayDate(f.dateOfBirth),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailsSection(
            title: 'Identity & Compliance',
            icon: Icons.verified_user_outlined,
            children: [
              _buildDetailRow('Aadhaar / Govt ID', f.aadhaarNumber),
              _buildDetailRow('PAN', f.panNumber),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailsSection(
            title: 'Contact Details',
            icon: Icons.contact_phone_outlined,
            children: [
              _buildDetailRow('Mobile Number', f.mobile),
              _buildDetailRow('Email Address', f.email),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailsSection(
            title: 'Address',
            icon: Icons.home_outlined,
            children: [
              _buildDetailRow('Permanent Address', f.permanentAddress),
              _buildDetailRow('Current Address', f.currentAddress),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailsSection(
            title: 'Emergency Contact',
            icon: Icons.emergency_outlined,
            children: [
              _buildDetailRow('Contact Person Name', f.emergencyContactName),
              _buildDetailRow('Relation', f.emergencyContactRelation),
              _buildDetailRow('Emergency Mobile', f.emergencyContactMobile),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentBasicDetails() {
    final StudentModel s = _studentModel;
    final String photoUrl = _normalizePhotoUrl(s.photographUrl);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfilePhotographLayout(
            photoUrl: photoUrl,
            profileSection: _buildDetailsSection(
              title: 'Basic Profile Information',
              icon: Icons.person_outline_rounded,
              headerTrailing: _buildStudentProfileHeaderActions(),
              children: [
                _buildDetailRow('Student ID (USN)', s.studentId),
                _buildDetailRow('Full Name', s.fullName),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildDetailField('Gender', s.gender),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildDetailField('Batch', s.batch),
                      ),
                    ],
                  ),
                ),
                _buildDetailRow(
                  'Date of Birth',
                  _formatDisplayDate(s.dateOfBirth),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailsSection(
            title: 'Identity & Category',
            icon: Icons.verified_user_outlined,
            children: [
              _buildDetailRow('Aadhaar / Govt ID', s.aadhaarNumber),
              _buildDetailRow('Category', s.category),
              _buildDetailRow('Nationality', s.nationality),
              _buildDetailRow('Blood Group', s.bloodGroup),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailsSection(
            title: 'Contact Details',
            icon: Icons.contact_phone_outlined,
            children: [
              _buildDetailRow('Mobile Number', s.mobile),
              _buildDetailRow('Email Address', s.email),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailsSection(
            title: 'Family Details',
            icon: Icons.family_restroom_outlined,
            children: [
              _buildDetailRow('Father Name', s.fatherName),
              _buildDetailRow('Mother Name', s.motherName),
              _buildDetailRow('Guardian Name', s.guardianName),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailsSection(
            title: 'Address',
            icon: Icons.home_outlined,
            children: [
              _buildDetailRow('Permanent Address', s.permanentAddress),
              _buildDetailRow('Correspondence Address', s.correspondenceAddress),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailsSection(
            title: 'Emergency Contact (Parent/Guardian)',
            icon: Icons.emergency_outlined,
            children: [
              _buildDetailRow('Contact Person Name', s.emergencyContactName),
              _buildDetailRow('Relation', s.emergencyContactRelation),
              _buildDetailRow('Emergency Mobile', s.emergencyContactMobile),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool stretchContent = false,
    Widget? headerTrailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: stretchContent ? MainAxisSize.max : MainAxisSize.min,
        children: [
          _sectionHeader(title, icon, trailing: headerTrailing),
          if (stretchContent)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return ClipRect(
                    child: Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight,
                          maxWidth: constraints.maxWidth,
                        ),
                        child: children.length == 1
                            ? children.first
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: children,
                              ),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 14, color: ColorConst.primaryBlue),
          const SizedBox(width: 6),
          Expanded(
            child: smcText(
              textToDisplay: title,
              textSize: 12,
              textBoldness: 4,
              colorOfText: ColorConst.primaryBlue,
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildProfilePhotographLayout({
    required Widget profileSection,
    required String photoUrl,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool stackVertically = constraints.maxWidth < 640;
        final bool boundedHeight = constraints.hasBoundedHeight;
        final bool useStretchPhotograph = boundedHeight && !stackVertically;
        final Widget photographSection = _buildPhotographDetailsSection(
          photoUrl,
          stretch: useStretchPhotograph,
        );

        if (stackVertically) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              profileSection,
              const SizedBox(height: 16),
              photographSection,
            ],
          );
        }

        if (!boundedHeight) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: profileSection),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: photographSection),
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: profileSection),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: photographSection),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotographDetailsSection(
    String photoUrl, {
    bool stretch = true,
  }) {
    return _buildDetailsSection(
      title: 'Photograph',
      icon: Icons.photo_camera_outlined,
      stretchContent: stretch,
      children: [
        _buildPhotographSectionContent(photoUrl),
      ],
    );
  }

  Widget _buildPhotographSectionContent(String photoUrl) {
    if (photoUrl.isEmpty) {
      return const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 40,
          color: ColorConst.textSecondary,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const double maxPhotoWidth = 130;
        const double maxPhotoHeight = 195;
        const double aspectRatio = maxPhotoWidth / maxPhotoHeight;

        final double maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : maxPhotoWidth;
        final double maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : maxPhotoHeight;

        double height = maxPhotoHeight;
        if (height > maxH) {
          height = maxH;
        }
        double width = height * aspectRatio;
        if (width > maxW) {
          width = maxW;
          height = width / aspectRatio;
        }

        if (width <= 0 || height <= 0) {
          return const SizedBox.shrink();
        }

        return Center(
          child: _buildPhotographPreview(
            photoUrl,
            width: width,
            height: height,
          ),
        );
      },
    );
  }

  Widget _buildPhotographPreview(
    String photoUrl, {
    double width = 280,
    double height = 420,
  }) {
    return Container(
      key: ValueKey<String>(photoUrl),
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorConst.borderSoft),
        color: const Color(0xFFF7F9FF),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        photoUrl,
        key: ValueKey<String>('img-$photoUrl'),
        fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        gaplessPlayback: false,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: ColorConst.textSecondary,
          ),
        ),
      ),
    );
  }

  String _normalizePhotoUrl(String rawUrl) {
    final value = rawUrl.trim();
    if (value.isEmpty) {
      return '';
    }
    if (value.startsWith('gs://')) {
      return value;
    }
    if (value.startsWith('//')) {
      return 'https:$value';
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '';
  }

  String _formatDisplayDate(String rawDate) {
    if (rawDate.trim().isEmpty) {
      return '';
    }
    final parts = rawDate.split('-');
    if (parts.length == 3) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return rawDate;
  }

  Widget? _buildStudentProfileHeaderActions() {
    if (widget.onEditStudent != null) {
      return OutlinedButton.icon(
        onPressed: widget.onEditStudent,
        icon: const Icon(
          Icons.edit_outlined,
          size: 14,
          color: ColorConst.primaryBlue,
        ),
        label: const smcText(
          textToDisplay: 'Edit',
          textSize: 11,
          textBoldness: 4,
          colorOfText: ColorConst.primaryBlue,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: ColorConst.primaryBlue,
          side: const BorderSide(color: ColorConst.primaryBlue),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    if (!widget.allowStudentProfileEdit) {
      return null;
    }
    return OutlinedButton.icon(
      onPressed: _showStudentProfileEditDialog,
      icon: const Icon(
        Icons.edit_outlined,
        size: 14,
        color: ColorConst.primaryBlue,
      ),
      label: const smcText(
        textToDisplay: 'Edit',
        textSize: 11,
        textBoldness: 4,
        colorOfText: ColorConst.primaryBlue,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: ColorConst.primaryBlue,
        side: const BorderSide(color: ColorConst.primaryBlue),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _showStudentProfileEditDialog() async {
    final StudentModel? updated = await showDialog<StudentModel>(
      context: context,
      builder: (ctx) => _StudentProfileEditDialog(student: _studentModel),
    );
    if (updated == null || !mounted) {
      return;
    }

    final String? documentId = updated.documentId?.trim();
    if (documentId == null || documentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save profile: student record not found.'),
        ),
      );
      return;
    }

    try {
      await _studentService.updateStudent(
        documentId: documentId,
        updated: updated,
      );
      if (!mounted) {
        return;
      }
      setState(() => _studentProfileOverride = updated);
      _seedEnrolledCourseMarksFromStudent(updated);
      widget.onStudentProfileUpdated?.call(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save profile: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildDetailField(label, value),
    );
  }

  Widget _buildDetailField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        smcText(
          textToDisplay: label,
          textSize: 12,
          textBoldness: 4,
          colorOfText: ColorConst.textSecondary,
        ),
        const SizedBox(height: 4),
        smcText(
          textToDisplay: value.isEmpty ? '—' : value,
          textSize: 13,
          textBoldness: 3,
          colorOfText: ColorConst.textPrimary,
          maxLines: 5,
        ),
      ],
    );
  }

  Widget _buildCoursesOpted() {
    final StudentModel student = _studentModel;
    final Stream<List<CourseModel>> coursesStream =
        _enrolledCoursesStream ??
            _courseService.getCoursesForOrg(orgId: student.orgId);

    return StreamBuilder<List<CourseModel>>(
      stream: coursesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<CourseModel> enrolledCourses =
            CourseFirestoreService.filterCoursesForStudent(
          snapshot.data ?? const <CourseModel>[],
          student,
        );

        if (enrolledCourses.isEmpty) {
          return const Center(
            child: smcText(
              textToDisplay: 'No courses enrolled yet.',
              textSize: 14,
              colorOfText: ColorConst.textSecondary,
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
          );
        }

        final List<CourseModel> semesterCourses = enrolledCourses
            .where(
              (course) => _courseMatchesSemester(
                course,
                _selectedEnrolledSemester,
              ),
            )
            .toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool useTable = constraints.maxWidth >= 600;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (int i = 0;
                            i < _enrolledSemesterOptions.length;
                            i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          _buildSemesterFilterChip(
                            semester: _enrolledSemesterOptions[i],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  child: _buildEnrolledSemesterSummaryRow(semesterCourses),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: semesterCourses.isEmpty
                      ? Center(
                          child: smcText(
                            textToDisplay:
                                'No courses enrolled in Semester $_selectedEnrolledSemester.',
                            textSize: 14,
                            colorOfText: ColorConst.textSecondary,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                          ),
                        )
                      : useTable
                          ? _buildEnrolledCoursesTable(
                              semesterCourses,
                              constraints.maxWidth,
                            )
                          : _buildEnrolledCoursesList(semesterCourses),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _courseMatchesSemester(CourseModel course, String semester) {
    return course.semester.trim().toUpperCase() ==
        semester.trim().toUpperCase();
  }

  Widget _buildSemesterFilterChip({
    required String semester,
  }) {
    final bool isSelected = _selectedEnrolledSemester == semester;

    return InkWell(
      onTap: () => setState(() => _selectedEnrolledSemester = semester),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F0FE) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1967D2)
                : const Color(0xFFD1D5DB),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 14, color: Color(0xFF1967D2)),
              const SizedBox(width: 6),
            ],
            smcText(
              textToDisplay: 'Sem: $semester',
              textSize: 13,
              textBoldness: isSelected ? 4 : 3,
              colorOfText:
                  isSelected ? const Color(0xFF1967D2) : const Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnrolledSummaryDivider() {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFFD1D5DB),
    );
  }

  Widget _buildEnrolledSemesterSummaryRow(List<CourseModel> semesterCourses) {
    final Widget editMarksButton = OutlinedButton.icon(
      onPressed: semesterCourses.isEmpty ||
              _savingEnrolledCourseMarks ||
              _loadingEnrolledCourseMarks
          ? null
          : () => _showEditMarksDialog(semesterCourses),
      icon: const Icon(
        Icons.edit_outlined,
        size: 16,
        color: ColorConst.primaryBlue,
      ),
      label: const smcText(
        textToDisplay: 'Edit',
        textSize: 12,
        textBoldness: 4,
        colorOfText: ColorConst.primaryBlue,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: ColorConst.primaryBlue,
        side: const BorderSide(color: ColorConst.primaryBlue),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        minimumSize: const Size(0, 42),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );

    return Wrap(
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        smcText(
          textToDisplay:
              'SGPA: ${_sgpaDisplayForSemester(_selectedEnrolledSemester)}',
          textSize: 13,
          textBoldness: 4,
          colorOfText: ColorConst.textPrimary,
        ),
        _buildEnrolledSummaryDivider(),
        smcText(
          textToDisplay: 'CGPA: ${_cgpaDisplay()}',
          textSize: 13,
          textBoldness: 4,
          colorOfText: ColorConst.textPrimary,
        ),
        _buildEnrolledSummaryDivider(),
        editMarksButton,
      ],
    );
  }

  String _enrolledCourseCellText(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? '—' : trimmed;
  }

  String _gradePointsForCourse(CourseModel course) {
    return _enrolledCourseCellText(
      _enrolledCourseMarks[course.id]?['gradePoints'] ?? '',
    );
  }

  String _letterGradeForCourse(CourseModel course) {
    return _enrolledCourseCellText(
      _enrolledCourseMarks[course.id]?['letterGrade'] ?? '',
    );
  }

  Future<void> _showEditMarksDialog(List<CourseModel> courses) async {
    final _EditMarksDialogResult? result =
        await showDialog<_EditMarksDialogResult>(
      context: context,
      builder: (ctx) => _EditMarksDialog(
        courses: courses,
        semester: _selectedEnrolledSemester,
        initialMarks: _enrolledCourseMarks,
        initialSgpa: _semesterSgpaBySemester[_selectedEnrolledSemester] ?? '',
        initialCgpa: _cgpa,
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    final Map<String, Map<String, String>> updatedMarks =
        Map<String, Map<String, String>>.from(
      _enrolledCourseMarks.map(
        (courseId, marks) => MapEntry(
          courseId,
          Map<String, String>.from(marks),
        ),
      ),
    );

    for (final CourseModel course in courses) {
      final Map<String, String>? marks = result.courseMarks[course.id];
      if (marks == null) {
        updatedMarks.remove(course.id);
        continue;
      }

      final String gradePoints = marks['gradePoints']?.trim() ?? '';
      final String letterGrade = marks['letterGrade']?.trim() ?? '';
      if (gradePoints.isEmpty && letterGrade.isEmpty) {
        updatedMarks.remove(course.id);
      } else {
        updatedMarks[course.id] = {
          'gradePoints': gradePoints,
          'letterGrade': letterGrade,
        };
      }
    }

    final Map<String, String> updatedSemesterSgpa =
        Map<String, String>.from(_semesterSgpaBySemester);
    final String sgpa = result.sgpa.trim();
    if (sgpa.isEmpty) {
      updatedSemesterSgpa.remove(_selectedEnrolledSemester);
    } else {
      updatedSemesterSgpa[_selectedEnrolledSemester] = sgpa;
    }
    final String updatedCgpa = result.cgpa.trim();

    if (!widget.isStudent || widget.person is! StudentModel) {
      setState(() {
        _enrolledCourseMarks
          ..clear()
          ..addAll(updatedMarks);
        _semesterSgpaBySemester
          ..clear()
          ..addAll(updatedSemesterSgpa);
        _cgpa = updatedCgpa;
      });
      return;
    }

    final StudentModel student = widget.person as StudentModel;
    final String? documentId = student.documentId?.trim();
    if (documentId == null || documentId.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save marks: student record not found.'),
        ),
      );
      return;
    }

    setState(() => _savingEnrolledCourseMarks = true);
    try {
      await _studentService.saveEnrolledCourseMarks(
        documentId: documentId,
        marksByCourseId: updatedMarks,
        semesterSgpaBySemester: updatedSemesterSgpa,
        cgpa: updatedCgpa,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _enrolledCourseMarks
          ..clear()
          ..addAll(updatedMarks);
        _semesterSgpaBySemester
          ..clear()
          ..addAll(updatedSemesterSgpa);
        _cgpa = updatedCgpa;
        _savingEnrolledCourseMarks = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marks saved successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _savingEnrolledCourseMarks = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save marks: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Widget _buildEnrolledCoursesList(List<CourseModel> courses) {
    return ListView.builder(
      key: ValueKey<String>(
        'enrolled-courses-$_selectedEnrolledSemester-${courses.length}',
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index < courses.length - 1 ? 10 : 0),
          child: _buildEnrolledCourseTile(
            courses[index],
            serialNo: index + 1,
          ),
        );
      },
    );
  }

  Widget _buildEnrolledCoursesTable(
    List<CourseModel> courses,
    double tableWidth,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3EAF8)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: tableWidth - 40),
                child: DataTable(
                  showCheckboxColumn: false,
                  headingRowHeight: 50,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 58,
                  horizontalMargin: 0,
                  columnSpacing: 0,
                  dividerThickness: 1,
                  border: const TableBorder(
                    horizontalInside: BorderSide(color: Color(0xFFE3EAF8)),
                    verticalInside: BorderSide(color: Color(0xFFE3EAF8)),
                    top: BorderSide(color: Color(0xFFE3EAF8)),
                    bottom: BorderSide(color: Color(0xFFE3EAF8)),
                    left: BorderSide(color: Color(0xFFE3EAF8)),
                    right: BorderSide(color: Color(0xFFE3EAF8)),
                  ),
                  headingRowColor: MaterialStateProperty.all(
                    const Color(0xFFF4F7FF),
                  ),
                  columns: const [
                    DataColumn(
                      label: SizedBox(
                        width: 50,
                        child: Center(
                          child: smcText(
                            textToDisplay: 'S.No',
                            textSize: 12,
                            textBoldness: 4,
                            colorOfText: Color(0xFF5C6B8B),
                          ),
                        ),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: 120,
                        child: Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: smcText(
                              textToDisplay: 'Course Code',
                              textSize: 12,
                              textBoldness: 4,
                              colorOfText: Color(0xFF5C6B8B),
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: 260,
                        child: Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: smcText(
                              textToDisplay: 'Course Title',
                              textSize: 12,
                              textBoldness: 4,
                              colorOfText: Color(0xFF5C6B8B),
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: 80,
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Credits',
                            textSize: 12,
                            textBoldness: 4,
                            colorOfText: Color(0xFF5C6B8B),
                          ),
                        ),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: 100,
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Grade Points',
                            textSize: 12,
                            textBoldness: 4,
                            colorOfText: Color(0xFF5C6B8B),
                          ),
                        ),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: 100,
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Letter Grade',
                            textSize: 12,
                            textBoldness: 4,
                            colorOfText: Color(0xFF5C6B8B),
                          ),
                        ),
                      ),
                    ),
                  ],
                  rows: courses.asMap().entries.map((entry) {
                    final int index = entry.key;
                    final CourseModel course = entry.value;
                    return DataRow(
                      cells: [
                        DataCell(
                          Center(
                            child: smcText(
                              textToDisplay: '${index + 1}',
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
                                textToDisplay:
                                    _enrolledCourseCellText(course.courseCode),
                                textSize: 12,
                                textBoldness: 4,
                                colorOfText: const Color(0xFF2E3954),
                                maxLines: 1,
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
                                textToDisplay:
                                    _enrolledCourseCellText(course.courseTitle),
                                textSize: 12,
                                colorOfText: const Color(0xFF2E3954),
                                maxLines: 2,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: smcText(
                              textToDisplay:
                                  _enrolledCourseCellText(course.credits),
                              textSize: 12,
                              colorOfText: const Color(0xFF2E3954),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: smcText(
                              textToDisplay: _gradePointsForCourse(course),
                              textSize: 12,
                              colorOfText: const Color(0xFF2E3954),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: smcText(
                              textToDisplay: _letterGradeForCourse(course),
                              textSize: 12,
                              colorOfText: const Color(0xFF2E3954),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnrolledCourseCardField(
    String label,
    String value, {
    bool withBottomPadding = true,
    bool expandValue = true,
  }) {
    final Widget valueWidget = smcText(
      textToDisplay: value.trim().isEmpty ? '—' : value.trim(),
      textSize: 13,
      textBoldness: 3,
      colorOfText: ColorConst.textPrimary,
      maxLines: 3,
    );

    final Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        smcText(
          textToDisplay: label,
          textSize: 12,
          textBoldness: 4,
          colorOfText: ColorConst.textSecondary,
          maxLines: 1,
        ),
        const SizedBox(width: 8),
        if (expandValue) Expanded(child: valueWidget) else valueWidget,
      ],
    );

    if (!withBottomPadding) {
      return content;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: content,
    );
  }

  Widget _buildEnrolledCourseCardCompactField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        smcText(
          textToDisplay: label,
          textSize: 11,
          textBoldness: 4,
          colorOfText: ColorConst.textSecondary,
          maxLines: 2,
        ),
        const SizedBox(height: 4),
        smcText(
          textToDisplay: value.trim().isEmpty ? '—' : value.trim(),
          textSize: 13,
          textBoldness: 3,
          colorOfText: ColorConst.textPrimary,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildEnrolledCourseSerialBadge(int serialNo) {
    return Container(
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1967D2)),
      ),
      child: smcText(
        textToDisplay: serialNo.toString(),
        textSize: 13,
        textBoldness: 4,
        colorOfText: ColorConst.primaryBlue,
        maxLines: 1,
      ),
    );
  }

  Widget _buildEnrolledCourseTile(
    CourseModel course, {
    required int serialNo,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3EAF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildEnrolledCourseSerialBadge(serialNo),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildEnrolledCourseCardField(
                    'Course Code',
                    _enrolledCourseCellText(course.courseCode),
                    withBottomPadding: false,
                  ),
                ),
              ],
            ),
          ),
          _buildEnrolledCourseCardField(
            'Course Title',
            _enrolledCourseCellText(course.courseTitle),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildEnrolledCourseCardCompactField(
                  'Credits',
                  _enrolledCourseCellText(course.credits),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEnrolledCourseCardCompactField(
                  'Grade Points',
                  _gradePointsForCourse(course),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEnrolledCourseCardCompactField(
                  'Letter Grade',
                  _letterGradeForCourse(course),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAchievements() {
    return const Center(
      child: smcText(
        textToDisplay: 'No achievements recorded yet.',
        textSize: 14,
        colorOfText: ColorConst.textSecondary,
      ),
    );
  }

  Widget _buildPublications() {
    return const Center(
      child: smcText(
        textToDisplay: 'No publications recorded yet.',
        textSize: 14,
        colorOfText: ColorConst.textSecondary,
      ),
    );
  }
}

class _EditMarksDialogResult {
  final Map<String, Map<String, String>> courseMarks;
  final String sgpa;
  final String cgpa;

  const _EditMarksDialogResult({
    required this.courseMarks,
    required this.sgpa,
    required this.cgpa,
  });
}

class _EditMarksDialog extends StatefulWidget {
  final List<CourseModel> courses;
  final String semester;
  final Map<String, Map<String, String>> initialMarks;
  final String initialSgpa;
  final String initialCgpa;

  const _EditMarksDialog({
    required this.courses,
    required this.semester,
    required this.initialMarks,
    required this.initialSgpa,
    required this.initialCgpa,
  });

  @override
  State<_EditMarksDialog> createState() => _EditMarksDialogState();
}

class _EditMarksDialogState extends State<_EditMarksDialog> {
  late final List<TextEditingController> _gradePointsControllers;
  late final List<TextEditingController> _letterGradeControllers;
  late final TextEditingController _sgpaController;
  late final TextEditingController _cgpaController;

  @override
  void initState() {
    super.initState();
    _sgpaController = TextEditingController(text: widget.initialSgpa.trim());
    _cgpaController = TextEditingController(text: widget.initialCgpa.trim());
    _gradePointsControllers = widget.courses.map((course) {
      final String stored =
          widget.initialMarks[course.id]?['gradePoints']?.trim() ?? '';
      return TextEditingController(text: stored);
    }).toList();
    _letterGradeControllers = widget.courses.map((course) {
      final String stored =
          widget.initialMarks[course.id]?['letterGrade']?.trim() ?? '';
      return TextEditingController(text: stored);
    }).toList();
  }

  @override
  void dispose() {
    _sgpaController.dispose();
    _cgpaController.dispose();
    for (final TextEditingController controller in _gradePointsControllers) {
      controller.dispose();
    }
    for (final TextEditingController controller in _letterGradeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  InputDecoration _marksFieldDecoration() {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ColorConst.primaryBlue),
      ),
    );
  }

  InputDecoration _gradePointsFieldDecoration() {
    return _marksFieldDecoration().copyWith(
      hintText: '1-10',
      hintStyle: const TextStyle(
        fontSize: 11,
        color: Color(0xFF8A96B2),
      ),
    );
  }

  InputDecoration _gpaFieldDecoration() {
    return _marksFieldDecoration().copyWith(
      hintText: '0-10',
      hintStyle: const TextStyle(
        fontSize: 11,
        color: Color(0xFF8A96B2),
      ),
    );
  }

  String? _validateGpa(String label, String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final num? parsed = num.tryParse(trimmed);
    if (parsed == null || parsed < 0 || parsed > 10) {
      return '$label must be between 0 and 10.';
    }
    return null;
  }

  String? _validateGradePoints(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final num? parsed = num.tryParse(trimmed);
    if (parsed == null || parsed < 1 || parsed > 10) {
      return 'Grade Points must be between 1 and 10.';
    }
    return null;
  }

  String? _validateMarksBeforeSave() {
    final String? sgpaError = _validateGpa('SGPA', _sgpaController.text);
    if (sgpaError != null) {
      return sgpaError;
    }

    final String? cgpaError = _validateGpa('CGPA', _cgpaController.text);
    if (cgpaError != null) {
      return cgpaError;
    }

    for (int i = 0; i < widget.courses.length; i++) {
      final String? error =
          _validateGradePoints(_gradePointsControllers[i].text);
      if (error != null) {
        final CourseModel course = widget.courses[i];
        final String courseCode = course.courseCode.trim();
        final String label =
            courseCode.isEmpty ? 'Row ${i + 1}' : courseCode;
        return '$label: $error';
      }
    }
    return null;
  }

  void _handleSave() {
    final String? error = _validateMarksBeforeSave();
    if (error != null) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const smcText(
            textToDisplay: 'Validation Error',
            textSize: 18,
            textBoldness: 4,
            colorOfText: ColorConst.textPrimary,
          ),
          content: smcText(
            textToDisplay: error,
            textSize: 14,
            colorOfText: ColorConst.textSecondary,
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const smcText(
                textToDisplay: 'OK',
                textSize: 14,
                textBoldness: 4,
                colorOfText: ColorConst.primaryBlue,
              ),
            ),
          ],
        ),
      );
      return;
    }

    _confirmSave();
  }

  Future<void> _confirmSave() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const smcText(
          textToDisplay: 'Save Marks',
          textSize: 18,
          textBoldness: 4,
          colorOfText: ColorConst.textPrimary,
        ),
        content: const smcText(
          textToDisplay: 'Are you sure you want to save these marks?',
          textSize: 14,
          colorOfText: ColorConst.textSecondary,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const smcText(
              textToDisplay: 'Cancel',
              textSize: 14,
              textBoldness: 3,
              colorOfText: ColorConst.textSecondary,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const smcText(
              textToDisplay: 'Save',
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

    Navigator.pop(
      context,
      _EditMarksDialogResult(
        courseMarks: _collectMarks(),
        sgpa: _sgpaController.text.trim(),
        cgpa: _cgpaController.text.trim(),
      ),
    );
  }

  Future<void> _handleCancel() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const smcText(
          textToDisplay: 'Discard Changes?',
          textSize: 18,
          textBoldness: 4,
          colorOfText: ColorConst.textPrimary,
        ),
        content: const smcText(
          textToDisplay:
              'Are you sure you want to cancel? Unsaved changes will be lost.',
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
              textToDisplay: 'Yes, Cancel',
              textSize: 14,
              textBoldness: 4,
              colorOfText: ColorConst.primaryBlue,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.pop(context);
    }
  }

  Map<String, Map<String, String>> _collectMarks() {
    final Map<String, Map<String, String>> marks = {};
    for (int i = 0; i < widget.courses.length; i++) {
      final CourseModel course = widget.courses[i];
      marks[course.id] = {
        'gradePoints': _gradePointsControllers[i].text.trim(),
        'letterGrade': _letterGradeControllers[i].text.trim(),
      };
    }
    return marks;
  }

  Widget _buildGpaFieldsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const smcText(
                textToDisplay: 'SGPA',
                textSize: 12,
                textBoldness: 4,
                colorOfText: Color(0xFF5C6B8B),
              ),
              const SizedBox(height: 2),
              const smcText(
                textToDisplay: 'For this semester',
                textSize: 10,
                colorOfText: Color(0xFF8A96B2),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _sgpaController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _gpaFieldDecoration(),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const smcText(
                textToDisplay: 'CGPA',
                textSize: 12,
                textBoldness: 4,
                colorOfText: Color(0xFF5C6B8B),
              ),
              const SizedBox(height: 2),
              const smcText(
                textToDisplay: 'Cumulative GPA',
                textSize: 10,
                colorOfText: Color(0xFF8A96B2),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _cgpaController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _gpaFieldDecoration(),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double dialogWidth = screenWidth > 860 ? 820 : screenWidth - 24;
    final double tableHeight = (48.0 + widget.courses.length * 54.0)
        .clamp(102.0, screenHeight * 0.55)
        .toDouble();
    final bool showCreditsColumn = kIsWeb;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              smcText(
                textToDisplay: 'Edit Marks — Semester ${widget.semester}',
                textSize: 16,
                textBoldness: 5,
                colorOfText: ColorConst.textPrimary,
                maxLines: 1,
              ),
              const SizedBox(height: 10),
              _buildGpaFieldsRow(),
              const SizedBox(height: 10),
              if (!kIsWeb) ...[
                const smcText(
                  textToDisplay: '(Scroll right to enter the values)',
                  textSize: 11,
                  colorOfText: Color(0xFF8A96B2),
                  maxLines: 1,
                ),
                const SizedBox(height: 6),
              ],
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE3EAF8)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: tableHeight,
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          showCheckboxColumn: false,
                          headingRowHeight: 44,
                          dataRowMinHeight: 50,
                          dataRowMaxHeight: 54,
                          horizontalMargin: 10,
                          columnSpacing: 12,
                          dividerThickness: 1,
                          border: const TableBorder(
                            horizontalInside:
                                BorderSide(color: Color(0xFFE3EAF8)),
                            verticalInside:
                                BorderSide(color: Color(0xFFE3EAF8)),
                            top: BorderSide(color: Color(0xFFE3EAF8)),
                            bottom: BorderSide(color: Color(0xFFE3EAF8)),
                            left: BorderSide(color: Color(0xFFE3EAF8)),
                            right: BorderSide(color: Color(0xFFE3EAF8)),
                          ),
                          headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF4F7FF),
                          ),
                          columns: [
                            const DataColumn(
                              label: smcText(
                                textToDisplay: 'Course Code',
                                textSize: 12,
                                textBoldness: 4,
                                colorOfText: Color(0xFF5C6B8B),
                              ),
                            ),
                            const DataColumn(
                              label: smcText(
                                textToDisplay: 'Course Title',
                                textSize: 12,
                                textBoldness: 4,
                                colorOfText: Color(0xFF5C6B8B),
                              ),
                            ),
                            if (showCreditsColumn)
                              const DataColumn(
                                label: smcText(
                                  textToDisplay: 'Credits',
                                  textSize: 12,
                                  textBoldness: 4,
                                  colorOfText: Color(0xFF5C6B8B),
                                ),
                              ),
                            const DataColumn(
                              label: smcText(
                                textToDisplay: 'Grade Points',
                                textSize: 12,
                                textBoldness: 4,
                                colorOfText: Color(0xFF5C6B8B),
                              ),
                            ),
                            const DataColumn(
                              label: smcText(
                                textToDisplay: 'Letter Grade',
                                textSize: 12,
                                textBoldness: 4,
                                colorOfText: Color(0xFF5C6B8B),
                              ),
                            ),
                          ],
                          rows: List<DataRow>.generate(widget.courses.length,
                              (index) {
                            final CourseModel course = widget.courses[index];
                            return DataRow(
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 110,
                                    child: smcText(
                                      textToDisplay: course.courseCode
                                              .trim()
                                              .isEmpty
                                          ? '—'
                                          : course.courseCode.trim(),
                                      textSize: 12,
                                      textBoldness: 4,
                                      colorOfText: const Color(0xFF2E3954),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 220,
                                    child: smcText(
                                      textToDisplay: course.courseTitle
                                              .trim()
                                              .isEmpty
                                          ? '—'
                                          : course.courseTitle.trim(),
                                      textSize: 12,
                                      colorOfText: const Color(0xFF2E3954),
                                      maxLines: 2,
                                    ),
                                  ),
                                ),
                                if (showCreditsColumn)
                                  DataCell(
                                    Center(
                                      child: smcText(
                                        textToDisplay: course.credits
                                                .trim()
                                                .isEmpty
                                            ? '—'
                                            : course.credits.trim(),
                                        textSize: 12,
                                        colorOfText: const Color(0xFF2E3954),
                                      ),
                                    ),
                                  ),
                                DataCell(
                                  SizedBox(
                                    width: 96,
                                    child: TextField(
                                      controller:
                                          _gradePointsControllers[index],
                                      decoration: _gradePointsFieldDecoration(),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9.]'),
                                        ),
                                      ],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF2E3954),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 96,
                                    child: TextField(
                                      controller:
                                          _letterGradeControllers[index],
                                      decoration: _marksFieldDecoration(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF2E3954),
                                      ),
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
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _handleCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColorConst.textSecondary,
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const smcText(
                      textToDisplay: 'Cancel',
                      textSize: 13,
                      textBoldness: 4,
                      colorOfText: ColorConst.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorConst.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const smcText(
                      textToDisplay: 'Save',
                      textSize: 13,
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
    );
  }
}

class _StudentProfileEditDialog extends StatefulWidget {
  final StudentModel student;

  const _StudentProfileEditDialog({required this.student});

  @override
  State<_StudentProfileEditDialog> createState() =>
      _StudentProfileEditDialogState();
}

class _StudentProfileEditDialogState extends State<_StudentProfileEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _batchController;
  late final TextEditingController _dobController;
  late final TextEditingController _aadhaarController;
  late final TextEditingController _mobileController;
  late final TextEditingController _emailController;
  late final TextEditingController _permanentAddressController;
  late final TextEditingController _correspondenceAddressController;
  late final TextEditingController _fatherNameController;
  late final TextEditingController _motherNameController;
  late final TextEditingController _guardianNameController;
  late final TextEditingController _emergencyNameController;
  late final TextEditingController _emergencyRelationController;
  late final TextEditingController _emergencyMobileController;

  String? _gender;
  String? _category;
  String? _nationality;
  String? _bloodGroup;
  DateTime? _dateOfBirth;

  static const List<String> _genderOptions = ['Male', 'Female', 'Other'];
  static const List<String> _categoryOptions = ['Gen', 'OBC', 'SC', 'ST'];
  static const List<String> _nationalityOptions = [
    'Indian',
    'NRI',
    'Foreigner',
  ];
  static const List<String> _bloodGroupOptions = [
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
  ];

  @override
  void initState() {
    super.initState();
    final StudentModel student = widget.student;
    _fullNameController = TextEditingController(text: student.fullName);
    _batchController = TextEditingController(text: student.batch);
    _aadhaarController = TextEditingController(text: student.aadhaarNumber);
    _mobileController = TextEditingController(text: student.mobile);
    _emailController = TextEditingController(text: student.email);
    _permanentAddressController =
        TextEditingController(text: student.permanentAddress);
    _correspondenceAddressController =
        TextEditingController(text: student.correspondenceAddress);
    _fatherNameController = TextEditingController(text: student.fatherName);
    _motherNameController = TextEditingController(text: student.motherName);
    _guardianNameController = TextEditingController(text: student.guardianName);
    _emergencyNameController =
        TextEditingController(text: student.emergencyContactName);
    _emergencyRelationController =
        TextEditingController(text: student.emergencyContactRelation);
    _emergencyMobileController =
        TextEditingController(text: student.emergencyContactMobile);
    _gender = student.gender.isEmpty ? null : student.gender;
    _category = student.category.isEmpty ? null : student.category;
    _nationality = student.nationality.isEmpty ? null : student.nationality;
    _bloodGroup = student.bloodGroup.isEmpty ? null : student.bloodGroup;
    if (student.dateOfBirth.isNotEmpty) {
      try {
        _dateOfBirth = DateTime.parse(student.dateOfBirth);
      } catch (_) {}
    }
    _dobController = TextEditingController(text: _formatDob(_dateOfBirth));
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _batchController.dispose();
    _dobController.dispose();
    _aadhaarController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _permanentAddressController.dispose();
    _correspondenceAddressController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _guardianNameController.dispose();
    _emergencyNameController.dispose();
    _emergencyRelationController.dispose();
    _emergencyMobileController.dispose();
    super.dispose();
  }

  String _formatDob(DateTime? date) {
    if (date == null) {
      return '';
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 12,
        color: ColorConst.textSecondary,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ColorConst.primaryBlue),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: ColorConst.primaryBlue),
          const SizedBox(width: 6),
          smcText(
            textToDisplay: title,
            textSize: 12,
            textBoldness: 4,
            colorOfText: ColorConst.primaryBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: options.contains(value) ? value : null,
        decoration: _fieldDecoration(label),
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option,
                child: Text(option, style: const TextStyle(fontSize: 13)),
              ),
            )
            .toList(),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  Future<void> _pickDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2005),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _dateOfBirth = picked;
      _dobController.text = _formatDob(picked);
    });
  }

  StudentModel _buildUpdatedStudent() {
    return widget.student.copyWith(
      fullName: _fullNameController.text.trim(),
      gender: _gender ?? '',
      batch: _batchController.text.trim(),
      dateOfBirth: _dateOfBirth?.toIso8601String().split('T').first ?? '',
      aadhaarNumber: _aadhaarController.text.trim(),
      category: _category ?? '',
      nationality: _nationality ?? '',
      bloodGroup: _bloodGroup ?? '',
      mobile: _mobileController.text.trim(),
      email: _emailController.text.trim().toLowerCase(),
      permanentAddress: _permanentAddressController.text.trim(),
      correspondenceAddress: _correspondenceAddressController.text.trim(),
      fatherName: _fatherNameController.text.trim(),
      motherName: _motherNameController.text.trim(),
      guardianName: _guardianNameController.text.trim(),
      emergencyContactName: _emergencyNameController.text.trim(),
      emergencyContactRelation: _emergencyRelationController.text.trim(),
      emergencyContactMobile: _emergencyMobileController.text.trim(),
    );
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.pop(context, _buildUpdatedStudent());
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double dialogHeight = (screenHeight * 0.88).clamp(420.0, 760.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SizedBox(
          height: dialogHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const smcText(
                  textToDisplay: 'Edit Profile',
                  textSize: 16,
                  textBoldness: 5,
                  colorOfText: ColorConst.textPrimary,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionTitle(
                            'Basic Profile Information',
                            Icons.person_outline_rounded,
                          ),
                          TextFormField(
                            initialValue: widget.student.studentId,
                            readOnly: true,
                            decoration: _fieldDecoration('Student ID (USN)'),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _fullNameController,
                            decoration: _fieldDecoration('Full Name *'),
                            textCapitalization: TextCapitalization.words,
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Full name is required'
                                    : null,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdown(
                            label: 'Gender *',
                            value: _gender,
                            options: _genderOptions,
                            onChanged: (value) =>
                                setState(() => _gender = value),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Please select gender'
                                    : null,
                          ),
                          TextFormField(
                            controller: _batchController,
                            decoration: _fieldDecoration('Batch'),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _dobController,
                            readOnly: true,
                            decoration: _fieldDecoration('Date of Birth').copyWith(
                              suffixIcon: const Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                              ),
                            ),
                            onTap: _pickDateOfBirth,
                          ),
                          _buildSectionTitle(
                            'Identity & Category',
                            Icons.verified_user_outlined,
                          ),
                          TextFormField(
                            controller: _aadhaarController,
                            decoration: _fieldDecoration('Aadhaar / Govt ID'),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdown(
                            label: 'Category *',
                            value: _category,
                            options: _categoryOptions,
                            onChanged: (value) =>
                                setState(() => _category = value),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Please select category'
                                    : null,
                          ),
                          _buildDropdown(
                            label: 'Nationality *',
                            value: _nationality,
                            options: _nationalityOptions,
                            onChanged: (value) =>
                                setState(() => _nationality = value),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Please select nationality'
                                    : null,
                          ),
                          _buildDropdown(
                            label: 'Blood Group *',
                            value: _bloodGroup,
                            options: _bloodGroupOptions,
                            onChanged: (value) =>
                                setState(() => _bloodGroup = value),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Please select blood group'
                                    : null,
                          ),
                          _buildSectionTitle(
                            'Contact Details',
                            Icons.contact_phone_outlined,
                          ),
                          TextFormField(
                            controller: _mobileController,
                            decoration: _fieldDecoration('Mobile Number *'),
                            keyboardType: TextInputType.phone,
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Mobile number is required'
                                    : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _emailController,
                            decoration: _fieldDecoration('Email Address *'),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required';
                              }
                              final emailRegex = RegExp(
                                r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$',
                              );
                              if (!emailRegex.hasMatch(value.trim())) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          _buildSectionTitle(
                            'Family Details',
                            Icons.family_restroom_outlined,
                          ),
                          TextFormField(
                            controller: _fatherNameController,
                            decoration: _fieldDecoration('Father Name'),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _motherNameController,
                            decoration: _fieldDecoration('Mother Name'),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _guardianNameController,
                            decoration: _fieldDecoration('Guardian Name'),
                            textCapitalization: TextCapitalization.words,
                          ),
                          _buildSectionTitle('Address', Icons.home_outlined),
                          TextFormField(
                            controller: _permanentAddressController,
                            decoration: _fieldDecoration('Permanent Address'),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _correspondenceAddressController,
                            decoration:
                                _fieldDecoration('Correspondence Address'),
                            maxLines: 2,
                          ),
                          _buildSectionTitle(
                            'Emergency Contact (Parent/Guardian)',
                            Icons.emergency_outlined,
                          ),
                          TextFormField(
                            controller: _emergencyNameController,
                            decoration: _fieldDecoration('Contact Person Name'),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _emergencyRelationController,
                            decoration: _fieldDecoration('Relation'),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _emergencyMobileController,
                            decoration: _fieldDecoration('Emergency Mobile'),
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ColorConst.textSecondary,
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const smcText(
                        textToDisplay: 'Cancel',
                        textSize: 13,
                        textBoldness: 4,
                        colorOfText: ColorConst.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorConst.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const smcText(
                        textToDisplay: 'Save',
                        textSize: 13,
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
      ),
    );
  }
}
