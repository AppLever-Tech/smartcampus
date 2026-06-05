import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/widgets/smc_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/services/course_firestore_service.dart';

class PersonDetailPage extends StatefulWidget {
  final dynamic person; // Can be StudentModel or FacultyModel
  final bool isStudent;
  final bool embedded;
  final bool embeddedMaximized;
  final VoidCallback? onClose;
  final VoidCallback? onMaximize;
  final VoidCallback? onBackFromMaximized;
  final VoidCallback? onEditStudent;
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
  Stream<List<CourseModel>>? _enrolledCoursesStream;

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
  }

  @override
  void didUpdateWidget(PersonDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStudent &&
        widget.person is StudentModel &&
        (oldWidget.person is! StudentModel ||
            (oldWidget.person as StudentModel).orgId !=
                (widget.person as StudentModel).orgId)) {
      _bindEnrolledCoursesStream();
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
      return DecoratedBox(
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
        'Courses Enrolled',
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
      case 'Courses Enrolled':
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

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(CourseFirestoreService.collection)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No courses assigned'),
          );
        }

        final assignedCourses = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          return (data['faculty'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase() ==
              faculty.fullName.trim().toLowerCase();
        }).toList();

        if (assignedCourses.isEmpty) {
          return const Center(
            child: Text('No courses assigned'),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: assignedCourses.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(
                    data['courseTitle']?.toString() ?? '',
                  ),
                  subtitle: Text(
                    'Code: ${data['courseCode'] ?? ''}\n'
                    'Semester: ${data['semester'] ?? ''}\n'
                    'Credits: ${data['credits'] ?? ''}',
                  ),
                ),
              );
            }).toList(),
          ),
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
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildDetailsSection(
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
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _buildDetailsSection(
                    title: 'Photograph',
                    icon: Icons.photo_camera_outlined,
                    stretchContent: true,
                    children: [
                      photoUrl.isNotEmpty
                          ? Center(
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: _buildPhotographPreview(
                                  photoUrl,
                                  width: 130,
                                  height: 195,
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size: 40,
                                color: ColorConst.textSecondary,
                              ),
                            ),
                    ],
                  ),
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
    final StudentModel s = widget.person as StudentModel;
    final String photoUrl = _normalizePhotoUrl(s.photographUrl);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildDetailsSection(
                    title: 'Basic Profile Information',
                    icon: Icons.person_outline_rounded,
                    headerTrailing: widget.onEditStudent == null
                        ? null
                        : OutlinedButton.icon(
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
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
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _buildDetailsSection(
                    title: 'Photograph',
                    icon: Icons.photo_camera_outlined,
                    stretchContent: true,
                    children: [
                      photoUrl.isNotEmpty
                          ? Center(
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: _buildPhotographPreview(
                                  photoUrl,
                                  width: 130,
                                  height: 195,
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size: 40,
                                color: ColorConst.textSecondary,
                              ),
                            ),
                    ],
                  ),
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
              child: children.length == 1
                  ? children.first
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
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
    final StudentModel student = widget.person as StudentModel;
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const smcText(
                    textToDisplay: 'Semester',
                    textSize: 13,
                    textBoldness: 4,
                    colorOfText: ColorConst.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
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
                              enrolledCourses: enrolledCourses,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: semesterCourses.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _buildEnrolledCourseTile(semesterCourses[index]);
                      },
                    ),
            ),
          ],
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
    required List<CourseModel> enrolledCourses,
  }) {
    final bool isSelected = _selectedEnrolledSemester == semester;
    final int courseCount = enrolledCourses
        .where((course) => _courseMatchesSemester(course, semester))
        .length;

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
              textToDisplay: semester,
              textSize: 13,
              textBoldness: isSelected ? 4 : 3,
              colorOfText:
                  isSelected ? const Color(0xFF1967D2) : const Color(0xFF6B7280),
            ),
            if (courseCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1967D2)
                      : const Color(0xFFEEF2F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: smcText(
                  textToDisplay: courseCount.toString(),
                  textSize: 11,
                  textBoldness: 4,
                  colorOfText: isSelected
                      ? Colors.white
                      : ColorConst.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEnrolledCourseTile(CourseModel course) {
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
                  textToDisplay: course.courseCode.trim().isEmpty
                      ? '—'
                      : course.courseCode,
                  textSize: 14,
                  textBoldness: 4,
                  colorOfText: ColorConst.textPrimary,
                  maxLines: 1,
                ),
                if (course.courseTitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  smcText(
                    textToDisplay: course.courseTitle,
                    textSize: 13,
                    textBoldness: 3,
                    colorOfText: ColorConst.textPrimary,
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: 4),
                smcText(
                  textToDisplay:
                      '${course.credits} credits • ${course.batch}',
                  textSize: 12,
                  colorOfText: ColorConst.textSecondary,
                  maxLines: 2,
                ),
              ],
            ),
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
