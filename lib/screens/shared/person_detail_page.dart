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
import 'package:smartcampus/models/achievement_model.dart';
import 'package:smartcampus/services/achievement_firestore_service.dart';
import 'package:smartcampus/models/publication_model.dart';
import 'package:smartcampus/services/publication_firestore_service.dart';
import 'package:smartcampus/models/academic_record_model.dart';
import 'package:smartcampus/services/academic_firestore_service.dart';
import 'package:smartcampus/models/meeting_model.dart';
import 'package:smartcampus/services/meeting_firestore_service.dart';
import 'package:smartcampus/models/co_extra_activity_model.dart';
import 'package:smartcampus/services/co_extra_activity_firestore_service.dart';
import 'package:smartcampus/models/semester_performance_model.dart';
import 'package:smartcampus/services/semester_performance_firestore_service.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/class_attendance_firestore_service.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/completed_class_record.dart';
import 'package:smartcampus/screens/student/student_class_management/student_class_firestore_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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
  /// Custom list of tab labels for the page
  final List<String>? customTabLabels;

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
    this.customTabLabels,
  });

  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends State<PersonDetailPage> {
  int _selectedIndex = 0;
  String _selectedEnrolledSemester = 'I';
  final CourseFirestoreService _courseService = CourseFirestoreService();
  final StudentFirestoreService _studentService = StudentFirestoreService();
  final AchievementFirestoreService _achievementService = AchievementFirestoreService();
  final PublicationFirestoreService _publicationService = PublicationFirestoreService();
  final AcademicFirestoreService _academicService = AcademicFirestoreService();
  final MeetingFirestoreService _meetingService = MeetingFirestoreService();
  final CoExtraActivityFirestoreService _coExtraActivityService = CoExtraActivityFirestoreService();
  final SemesterPerformanceFirestoreService _semesterPerformanceService = SemesterPerformanceFirestoreService();
  final ClassAttendanceFirestoreService _classAttendanceService = ClassAttendanceFirestoreService();
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

  String get _uuid => widget.isStudent
      ? (widget.person as StudentModel).uuid
      : (widget.person is FacultyModel ? (widget.person as FacultyModel).mobile : ''); // Use mobile for faculty as uuid if not present

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
        setState(() {
          _studentProfileOverride = fresh;
          _seedEnrolledCourseMarksFromStudent(fresh);
        });
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
              textToDisplay: '$_idLabel: ${widget.isStudent ? (widget.person as StudentModel).studentId : (widget.person as FacultyModel).facultyId}',
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
                  textToDisplay: '$_idLabel: ${widget.isStudent ? (widget.person as StudentModel).studentId : (widget.person as FacultyModel).facultyId}',
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
    if (widget.customTabLabels != null) {
      return widget.customTabLabels!;
    }
    if (widget.isStudent) {
      return const [
        'Basic Details',
        'Enrolled Courses',
        'Academics',
        'Achievements',
        'Publications',
      ];
    }
    return const [
      'Basic Details',
      'Assigned Courses',
      'Academics',
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

  Widget _buildOriginalAcademics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const smcText(
                textToDisplay: 'Academic Records',
                textSize: 16,
                textBoldness: 5,
                colorOfText: ColorConst.textPrimary,
              ),
              ElevatedButton.icon(
                onPressed: () => _openAcademicDialog(),
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                label: const smcText(
                  textToDisplay: 'Add Academic Record',
                  textSize: 13,
                  textBoldness: 4,
                  colorOfText: Colors.white,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorConst.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AcademicRecordModel>>(
            stream: _academicService.getAcademicRecordsForPerson(_uuid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final records = snapshot.data ?? [];

              return LayoutBuilder(
                builder: (context, constraints) {
                  return _buildAcademicTable(records, constraints.maxWidth);
                },
              );
            },
          ),
        ),
      ],
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
      case 'Academics':
        return _buildOriginalAcademics();
      case 'Academic Performance':
        return _buildAcademics();
      case 'Achievements':
        return _buildAchievements();
      case 'Publications':
        return _buildPublications();
      case 'Meetings':
        return _buildMeetings();
      case 'Attendance':
        return _buildAttendance();
      case 'Co & Extra Activities':
        return _buildCoExtraActivities();
      case 'Academic Activities':
        return _buildPlaceholder('Academic Activities');
      default:
        return _buildBasicDetails();
    }
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            smcText(
              textToDisplay: '$title module is under construction.',
              textSize: 14,
              colorOfText: ColorConst.textSecondary,
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetings() {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const smcText(
                  textToDisplay: 'Meetings',
                  textSize: 16,
                  textBoldness: 5,
                  colorOfText: ColorConst.textPrimary,
                ),
                ElevatedButton.icon(
                  onPressed: () => _openMeetingDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  label: const smcText(
                    textToDisplay: 'Schedule Meeting',
                    textSize: 13,
                    textBoldness: 4,
                    colorOfText: Colors.white,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorConst.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                labelColor: ColorConst.primaryBlue,
                unselectedLabelColor: ColorConst.textSecondary,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: 'Minutes of Meeting'),
                  Tab(text: 'Parent Interaction'),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildMinutesOfMeetingTab(),
                _buildPlaceholder('Parent Interaction'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinutesOfMeetingTab() {
    return StreamBuilder<List<MeetingModel>>(
      stream: _meetingService.getMeetingsForStudent(_uuid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final meetings = snapshot.data ?? [];

        if (meetings.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const smcText(
                    textToDisplay: "No meetings scheduled yet. Click Schedule Meeting to add one.",
                    textSize: 14,
                    colorOfText: ColorConst.textSecondary,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return _buildMeetingTable(meetings, constraints.maxWidth);
          },
        );
      },
    );
  }

  Widget _buildMeetingTable(List<MeetingModel> meetings, double tableWidth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFF4F7FF)),
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
                              textToDisplay: 'Date',
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
                        width: 100,
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Time',
                            textSize: 12,
                            textBoldness: 4,
                            colorOfText: Color(0xFF5C6B8B),
                          ),
                        ),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: 200,
                        child: Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: smcText(
                              textToDisplay: 'Purpose',
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
                        width: 250,
                        child: Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: smcText(
                              textToDisplay: 'Meeting Minutes',
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
                        width: 120,
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Actions',
                            textSize: 12,
                            textBoldness: 4,
                            colorOfText: Color(0xFF5C6B8B),
                          ),
                        ),
                      ),
                    ),
                  ],
                  rows: meetings.asMap().entries.map((entry) {
                    final int index = entry.key;
                    final m = entry.value;
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: TextFormField(
                              initialValue: m.minutes,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Type points discussed...',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 4),
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2E3954),
                              ),
                              maxLines: 3,
                              minLines: 1,
                              onChanged: (value) async {
                                final updatedMeeting = MeetingModel(
                                  id: m.id,
                                  uuid: m.uuid,
                                  date: m.date,
                                  time: m.time,
                                  purpose: m.purpose,
                                  minutes: value,
                                  createdOn: m.createdOn,
                                );
                                await _meetingService.updateMeeting(m.id!, updatedMeeting);
                              },
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined, size: 18, color: ColorConst.primaryBlue),
                                  onPressed: () => _viewMeeting(m),
                                  tooltip: 'View',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.green),
                                  onPressed: () => _openMeetingDialog(meeting: m),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                  onPressed: () => _deleteMeeting(m),
                                  tooltip: 'Delete',
                                ),
                              ],
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

  void _openMeetingDialog({MeetingModel? meeting}) async {
    final bool isEdit = meeting != null;
    final formKey = GlobalKey<FormState>();
    final dateCtrl = TextEditingController(text: meeting?.date ?? '');
    final timeCtrl = TextEditingController(text: meeting?.time ?? '');
    final purposeCtrl = TextEditingController(text: meeting?.purpose ?? '');
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          smcText(
                            textToDisplay: '${isEdit ? 'Edit' : 'Schedule'} Meeting',
                            textSize: 18,
                            textBoldness: 5,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: dateCtrl,
                        readOnly: true,
                        decoration: _dialogFieldDecor('Date *').copyWith(
                          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setModalState(() => dateCtrl.text = picked.toIso8601String().split('T')[0]);
                          }
                        },
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: timeCtrl,
                        decoration: _dialogFieldDecor('Time *', hint: 'e.g., 10:30 AM'),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: purposeCtrl,
                        maxLines: 3,
                        decoration: _dialogFieldDecor('Purpose *'),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: saving ? null : () async {
                            if (!formKey.currentState!.validate()) return;
                            setModalState(() => saving = true);
                            try {
                              final m = MeetingModel(
                                id: meeting?.id,
                                uuid: _uuid,
                                date: dateCtrl.text,
                                time: timeCtrl.text,
                                purpose: purposeCtrl.text,
                                minutes: meeting?.minutes ?? '',
                                createdOn: meeting?.createdOn ?? DateTime.now(),
                              );

                              if (isEdit) {
                                await _meetingService.updateMeeting(meeting.id!, m);
                              } else {
                                await _meetingService.addMeeting(m);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              setModalState(() => saving = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorConst.primaryBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: saving
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : smcText(textToDisplay: isEdit ? 'Save Changes' : 'Schedule', textSize: 14, colorOfText: Colors.white, textBoldness: 5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _viewMeeting(MeetingModel meeting) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: smcText(textToDisplay: 'Meeting Details', textSize: 18, textBoldness: 5),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Date', _formatDisplayDate(meeting.date)),
              _buildDetailRow('Time', meeting.time),
              _buildDetailRow('Purpose', meeting.purpose),
              if (meeting.minutes.isNotEmpty)
                  _buildDetailRow('Meeting Minutes', meeting.minutes),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _deleteMeeting(MeetingModel meeting) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Meeting'),
        content: const Text('Are you sure you want to delete this meeting?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _meetingService.deleteMeeting(meeting.id!);
    }
  }

  Widget _buildAttendance() {
    if (!widget.isStudent) {
      return const Center(
        child: smcText(
          textToDisplay: 'Attendance is only available for students!',
          textSize: 14,
          colorOfText: ColorConst.textSecondary,
          textAlign: TextAlign.center,
        ),
      );
    }

    final student = _studentModel;
    final orgId = student.orgId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: const smcText(
            textToDisplay: 'Attendance',
            textSize: 16,
            textBoldness: 5,
            colorOfText: ColorConst.textPrimary,
          ),
        ),
        Expanded(
          child: StreamBuilder<List<CourseModel>>(
            stream: _courseService.getCoursesForOrg(orgId: orgId),
            builder: (context, coursesSnapshot) {
              if (coursesSnapshot.connectionState == ConnectionState.waiting && !coursesSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final enrolledCourses = coursesSnapshot.data ?? [];

              return StreamBuilder<List<CompletedClassRecord>>(
                stream: _classAttendanceService.watchClassesForOrg(orgId: orgId),
                builder: (context, classesSnapshot) {
                  if (classesSnapshot.connectionState == ConnectionState.waiting && !classesSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final classes = classesSnapshot.data ?? [];
                  final studentClasses = StudentClassFirestoreService.filterCompletedForStudent(
                    records: classes,
                    student: student,
                    enrolledCourses: enrolledCourses,
                  );

                  int totalClasses = 0;
                  int presentClasses = 0;

                  for (final cls in studentClasses) {
                    final status = StudentClassFirestoreService.attendanceStatusForStudent(
                      record: cls,
                      student: student,
                    );
                    if (status != null) {
                      totalClasses++;
                      if (status == 'Present') {
                        presentClasses++;
                      }
                    }
                  }

                  final double percentage = totalClasses == 0 ? 0.0 : (presentClasses / totalClasses) * 100;
                  final String attendanceText = totalClasses == 0 ? 'No classes conducted yet' : '${percentage.toStringAsFixed(1)}%';

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return Padding(
                        padding: const EdgeInsets.all(14),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE3EAF8)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
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
                              headingRowColor: MaterialStateProperty.all(const Color(0xFFF4F7FF)),
                              columns: const [
                                DataColumn(
                                  label: SizedBox(
                                    width: 200,
                                    child: Center(
                                      child: smcText(
                                        textToDisplay: 'Overall Attendance',
                                        textSize: 12,
                                        textBoldness: 4,
                                        colorOfText: Color(0xFF5C6B8B),
                                      ),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 12),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: smcText(
                                          textToDisplay: 'Remark',
                                          textSize: 12,
                                          textBoldness: 4,
                                          colorOfText: Color(0xFF5C6B8B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              rows: [
                                DataRow(
                                  cells: [
                                    DataCell(
                                      Center(
                                        child: smcText(
                                          textToDisplay: attendanceText,
                                          textSize: 14,
                                          textBoldness: 5,
                                          colorOfText: percentage >= 75
                                              ? Colors.green
                                              : percentage >= 60
                                                  ? Colors.orange
                                                  : Colors.red,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.only(left: 12),
                                        child: smcText(
                                          textToDisplay: totalClasses == 0
                                              ? 'Attendance will be calculated once classes are conducted'
                                              : percentage >= 75
                                                  ? 'Attendance is good!'
                                                  : percentage >= 60
                                                      ? 'Need to improve attendance'
                                                      : 'Attendance is low; please attend more classes',
                                          textSize: 12,
                                          colorOfText: const Color(0xFF2E3954),
                                        ),
                                      ),
                                    ),
                                  ],
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
            },
          ),
        ),
      ],
    );
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildDetailField(
                          'Current Semester',
                          s.currentSemester,
                        ),
                      ),
                      const Spacer(flex: 1),
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

  Future<void> _initializeSemesters(List<SemesterPerformanceModel> existing) async {
    final semesters = ['Semester I', 'Semester II', 'Semester III', 'Semester IV'];
    for (final semester in semesters) {
      final hasSemester = existing.any((e) => e.semester == semester);
      if (!hasSemester) {
        final newRecord = SemesterPerformanceModel(
          uuid: _uuid,
          semester: semester,
          createdOn: DateTime.now(),
        );
        await _semesterPerformanceService.addSemesterPerformance(newRecord);
      }
    }
  }

  Widget _buildAcademics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const smcText(
                textToDisplay: 'Academic Performance',
                textSize: 16,
                textBoldness: 5,
                colorOfText: ColorConst.textPrimary,
              ),
              ElevatedButton.icon(
                onPressed: () => _openAcademicDialog(),
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                label: const smcText(
                  textToDisplay: 'Add Academic Record',
                  textSize: 13,
                  textBoldness: 4,
                  colorOfText: Colors.white,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorConst.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<SemesterPerformanceModel>>(
            stream: _semesterPerformanceService.getSemesterPerformanceForStudent(_uuid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              var records = snapshot.data ?? [];

              // Initialize 4 semesters if missing
              if (records.length < 4) {
                _initializeSemesters(records);
              }

              // Ensure we have exactly 4 semesters in order
              final semestersOrder = ['Semester I', 'Semester II', 'Semester III', 'Semester IV'];
              final orderedRecords = <SemesterPerformanceModel>[];
              for (final sem in semestersOrder) {
                final record = records.firstWhere((e) => e.semester == sem,
                    orElse: () => SemesterPerformanceModel(
                          uuid: _uuid,
                          semester: sem,
                          createdOn: DateTime.now(),
                        ));
                orderedRecords.add(record);
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  return _buildSemesterPerformanceTable(orderedRecords, constraints.maxWidth);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSemesterPerformanceTable(List<SemesterPerformanceModel> records, double tableWidth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFF4F7FF)),
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
                          padding: EdgeInsets.only(left: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: smcText(
                              textToDisplay: 'Semester',
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
                        width: 100,
                        child: Center(
                          child: smcText(
                            textToDisplay: 'SGPA',
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
                            textToDisplay: 'CGPA',
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
                            textToDisplay: 'Backlogs',
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
                            textToDisplay: 'Status',
                            textSize: 12,
                            textBoldness: 4,
                            colorOfText: Color(0xFF5C6B8B),
                          ),
                        ),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: 200,
                        child: Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: smcText(
                              textToDisplay: 'Remarks',
                              textSize: 12,
                              textBoldness: 4,
                              colorOfText: Color(0xFF5C6B8B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  rows: records.asMap().entries.map((entry) {
                    final int index = entry.key;
                    final record = entry.value;
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
                            padding: const EdgeInsets.only(left: 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: smcText(
                                textToDisplay: record.semester,
                                textSize: 12,
                                colorOfText: const Color(0xFF2E3954),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: record.sgpa == 0.0 ? '' : record.sgpa.toString(),
                                decoration: const InputDecoration(
                                  hintText: 'Enter SGPA',
                                  hintStyle: TextStyle(fontSize: 12, color: Color(0xFF8A96B2)),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2E3954),
                                ),
                                textAlign: TextAlign.center,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (value) {
                                  if (record.id == null) return;
                                  final sgpa = double.tryParse(value.trim()) ?? 0.0;
                                  final updated = SemesterPerformanceModel(
                                    id: record.id,
                                    uuid: record.uuid,
                                    semester: record.semester,
                                    sgpa: sgpa,
                                    cgpa: record.cgpa,
                                    backlogs: record.backlogs,
                                    status: record.status,
                                    remarks: record.remarks,
                                    createdOn: record.createdOn,
                                  );
                                  _semesterPerformanceService.updateSemesterPerformance(record.id!, updated);
                                },
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: record.cgpa == 0.0 ? '' : record.cgpa.toString(),
                                decoration: const InputDecoration(
                                  hintText: 'Enter CGPA',
                                  hintStyle: TextStyle(fontSize: 12, color: Color(0xFF8A96B2)),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2E3954),
                                ),
                                textAlign: TextAlign.center,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (value) {
                                  if (record.id == null) return;
                                  final cgpa = double.tryParse(value.trim()) ?? 0.0;
                                  final updated = SemesterPerformanceModel(
                                    id: record.id,
                                    uuid: record.uuid,
                                    semester: record.semester,
                                    sgpa: record.sgpa,
                                    cgpa: cgpa,
                                    backlogs: record.backlogs,
                                    status: record.status,
                                    remarks: record.remarks,
                                    createdOn: record.createdOn,
                                  );
                                  _semesterPerformanceService.updateSemesterPerformance(record.id!, updated);
                                },
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: record.backlogs.toString(),
                                decoration: const InputDecoration(
                                  hintText: 'Backlogs',
                                  hintStyle: TextStyle(fontSize: 12, color: Color(0xFF8A96B2)),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2E3954),
                                ),
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  if (record.id == null) return;
                                  final backlogs = (double.tryParse(value.trim()) ?? 0).toInt();
                                  final updated = SemesterPerformanceModel(
                                    id: record.id,
                                    uuid: record.uuid,
                                    semester: record.semester,
                                    sgpa: record.sgpa,
                                    cgpa: record.cgpa,
                                    backlogs: backlogs,
                                    status: record.status,
                                    remarks: record.remarks,
                                    createdOn: record.createdOn,
                                  );
                                  _semesterPerformanceService.updateSemesterPerformance(record.id!, updated);
                                },
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: SizedBox(
                              width: 80,
                              child: DropdownButtonFormField<String>(
                                initialValue: record.status,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2E3954),
                                ),
                                items: const ['Clear', 'Active']
                                    .map((s) => DropdownMenuItem(
                                          value: s,
                                          child: smcText(
                                            textToDisplay: s,
                                            textSize: 12,
                                            colorOfText: const Color(0xFF2E3954),
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  if (record.id == null || value == null) return;
                                  final updated = SemesterPerformanceModel(
                                    id: record.id,
                                    uuid: record.uuid,
                                    semester: record.semester,
                                    sgpa: record.sgpa,
                                    cgpa: record.cgpa,
                                    backlogs: record.backlogs,
                                    status: value,
                                    remarks: record.remarks,
                                    createdOn: record.createdOn,
                                  );
                                  _semesterPerformanceService.updateSemesterPerformance(record.id!, updated);
                                },
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: TextFormField(
                              initialValue: record.remarks,
                              decoration: const InputDecoration(
                                hintText: 'Enter remarks',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 4),
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2E3954),
                              ),
                              maxLines: 2,
                              onChanged: (value) {
                                if (record.id == null) return;
                                final updated = SemesterPerformanceModel(
                                  id: record.id,
                                  uuid: record.uuid,
                                  semester: record.semester,
                                  sgpa: record.sgpa,
                                  cgpa: record.cgpa,
                                  backlogs: record.backlogs,
                                  status: record.status,
                                  remarks: value,
                                  createdOn: record.createdOn,
                                );
                                _semesterPerformanceService.updateSemesterPerformance(record.id!, updated);
                              },
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

  Widget _buildAcademicTable(List<AcademicRecordModel> records, double tableWidth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFF4F7FF)),
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
                        width: 250,
                        child: Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: smcText(
                              textToDisplay: 'Record Type',
                              textSize: 12,
                              textBoldness: 4,
                              colorOfText: Color(0xFF5C6B8B),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const DataColumn(
                      label: SizedBox(
                        width: 100,
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Document',
                            textSize: 12,
                            textBoldness: 4,
                            colorOfText: Color(0xFF5C6B8B),
                          ),
                        ),
                      ),
                    ),
                    DataColumn(
                      label: const SizedBox(
                        width: 120,
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Actions',
                            textSize: 12,
                            textBoldness: 4,
                            colorOfText: Color(0xFF5C6B8B),
                          ),
                        ),
                      ),
                    ),
                  ],
                  rows: records.asMap().entries.map((entry) {
                    final int index = entry.key;
                    final r = entry.value;
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
                            padding: const EdgeInsets.only(left: 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: smcText(
                                textToDisplay: r.recordType,
                                textSize: 12,
                                colorOfText: const Color(0xFF2E3954),
                                maxLines: 2,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: r.fileUrl != null
                                ? InkWell(
                                    onTap: () => _viewAcademicRecord(r),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE3EAF8)),
                                        color: const Color(0xFFF8FAFF),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: r.fileName?.toLowerCase().endsWith('.pdf') ?? false
                                          ? const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 20)
                                          : Image.network(
                                              r.fileUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 20, color: Colors.grey),
                                            ),
                                    ),
                                  )
                                : const smcText(textToDisplay: '—', textSize: 12, colorOfText: Colors.grey),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.green),
                                  onPressed: () => _openAcademicDialog(record: r),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                  onPressed: () => _deleteAcademicRecord(r),
                                  tooltip: 'Delete',
                                ),
                              ],
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

  void _openAcademicDialog({AcademicRecordModel? record}) async {
    final bool isEdit = record != null;
    final formKey = GlobalKey<FormState>();
    String? selectedRecordType = record?.recordType;
    final descCtrl = TextEditingController(text: record?.description ?? '');
    Uint8List? selectedFileBytes;
    String? selectedFileName = record?.fileName;
    String? existingUrl = record?.fileUrl;
    bool saving = false;

    final List<String> recordTypes = [
      '10th Mark Sheet',
      '12th Mark Sheet',
      'UG Consolidated Mark Sheet',
      'PG Degree - Sem 1: Mark Sheet',
      'PG Degree - Sem 2: Mark Sheet',
      'PG Degree - Sem 3: Mark Sheet',
      'PG Degree - Sem 4: Mark Sheet',
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          smcText(
                            textToDisplay: '${isEdit ? 'Edit' : 'Add'} Academic Record',
                            textSize: 18,
                            textBoldness: 5,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: selectedRecordType,
                        decoration: _dialogFieldDecor('Record Type *'),
                        items: recordTypes
                            .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setModalState(() => selectedRecordType = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: _dialogFieldDecor('Description (Optional)', hint: 'Add any additional notes'),
                      ),
                      const SizedBox(height: 20),
                      const smcText(textToDisplay: 'Document (PDF/JPG/PNG) *', textSize: 13, textBoldness: 4),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
                            withData: true,
                          );
                          if (result != null) {
                            setModalState(() {
                              selectedFileBytes = result.files.first.bytes;
                              selectedFileName = result.files.first.name;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                            color: const Color(0xFFF9FAFD),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.upload_file_rounded, color: ColorConst.primaryBlue, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedFileName ?? 'Tap to upload document',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: selectedFileName != null ? ColorConst.textPrimary : Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (selectedFileName != null)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setModalState(() {
                                    selectedFileBytes = null;
                                    selectedFileName = null;
                                    existingUrl = null;
                                  }),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: saving ? null : () async {
                            if (!formKey.currentState!.validate()) return;
                            if (selectedFileName == null && existingUrl == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a document')));
                              return;
                            }
                            
                            setModalState(() => saving = true);
                            try {
                              String? finalUrl = existingUrl;
                              if (selectedFileBytes != null) {
                                finalUrl = await _academicService.uploadAcademicFile(
                                  _uuid,
                                  selectedFileName!,
                                  selectedFileBytes!,
                                );
                              }

                              final r = AcademicRecordModel(
                                id: record?.id,
                                uuid: _uuid,
                                recordType: selectedRecordType!,
                                description: descCtrl.text.trim(),
                                fileUrl: finalUrl,
                                fileName: selectedFileName,
                                createdOn: record?.createdOn ?? DateTime.now(),
                              );

                              if (isEdit) {
                                await _academicService.updateAcademicRecord(record!.id!, r);
                              } else {
                                await _academicService.addAcademicRecord(r);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              setModalState(() => saving = false);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorConst.primaryBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: saving
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : smcText(textToDisplay: isEdit ? 'Save Changes' : 'Add Record', textSize: 14, colorOfText: Colors.white, textBoldness: 5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _viewAcademicRecord(AcademicRecordModel r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: smcText(textToDisplay: r.recordType, textSize: 18, textBoldness: 5),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.description != null && r.description!.isNotEmpty) ...[
              const smcText(textToDisplay: 'Description:', textSize: 13, textBoldness: 4),
              const SizedBox(height: 4),
              smcText(textToDisplay: r.description!, textSize: 13, maxLines: 5),
              const SizedBox(height: 16),
            ],
            const smcText(textToDisplay: 'Document Preview:', textSize: 13, textBoldness: 4),
            const SizedBox(height: 8),
            if (r.fileName?.toLowerCase().endsWith('.pdf') ?? false)
              OutlinedButton.icon(
                onPressed: () async {
                  if (await canLaunchUrl(Uri.parse(r.fileUrl!))) {
                    await launchUrl(Uri.parse(r.fileUrl!));
                  }
                },
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: const Text('Open PDF Document'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColorConst.primaryBlue,
                  side: const BorderSide(color: ColorConst.primaryBlue),
                ),
              )
            else if (r.fileUrl != null)
              GestureDetector(
                onTap: () async {
                  if (await canLaunchUrl(Uri.parse(r.fileUrl!))) {
                    await launchUrl(Uri.parse(r.fileUrl!));
                  }
                },
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ColorConst.borderSoft),
                    color: const Color(0xFFF7F9FF),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    r.fileUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _deleteAcademicRecord(AcademicRecordModel r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Academic Record'),
        content: Text('Are you sure you want to delete "${r.recordType}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _academicService.deleteAcademicRecord(r.id!, r.fileUrl);
    }
  }

  Widget _buildAchievements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const smcText(
                textToDisplay: 'Achievements',
                textSize: 16,
                textBoldness: 5,
                colorOfText: ColorConst.textPrimary,
              ),
              ElevatedButton.icon(
                onPressed: () => _openAchievementDialog(),
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                label: const smcText(
                  textToDisplay: 'Add Achievement',
                  textSize: 13,
                  textBoldness: 4,
                  colorOfText: Colors.white,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorConst.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AchievementModel>>(
            stream: _achievementService.getAchievementsForStudent(_uuid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final achievements = snapshot.data ?? [];

              if (achievements.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const smcText(
                          textToDisplay: "No achievements recorded yet. Click Add Achievement to add the accomplishments.",
                          textSize: 14,
                          colorOfText: ColorConst.textSecondary,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  return _buildAchievementTable(achievements, constraints.maxWidth);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementTable(List<AchievementModel> achievements, double tableWidth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFF4F7FF)),
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
                        width: 150,
                        child: Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: smcText(
                              textToDisplay: 'Title',
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
                        width: 120,
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Category',
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
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Level',
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
                            textToDisplay: 'Date',
                            textSize: 12,
                            textBoldness: 4,
                            colorOfText: Color(0xFF5C6B8B),
                          ),
                        ),
                      ),
                    ),
                    const DataColumn(
                      label: SizedBox(
                        width: 100,
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Certificate',
                            textSize: 12,
                            textBoldness: 4,
                            colorOfText: Color(0xFF5C6B8B),
                          ),
                        ),
                      ),
                    ),
                    DataColumn(
                      label: const SizedBox(
                        width: 120,
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Actions',
                            textSize: 12,
                            textBoldness: 4,
                            colorOfText: Color(0xFF5C6B8B),
                          ),
                        ),
                      ),
                    ),
                  ],
                  rows: achievements.asMap().entries.map((entry) {
                    final int index = entry.key;
                    final a = entry.value;
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
                            padding: const EdgeInsets.only(left: 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: smcText(
                                textToDisplay: a.title,
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF4FF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: smcText(
                                textToDisplay: a.category,
                                textSize: 11,
                                textBoldness: 3,
                                colorOfText: const Color(0xFF3558DA),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: smcText(
                              textToDisplay: a.level,
                              textSize: 12,
                              colorOfText: const Color(0xFF2E3954),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: smcText(
                              textToDisplay: _formatDisplayDate(a.date),
                              textSize: 12,
                              colorOfText: const Color(0xFF2E3954),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: a.certificateUrl != null
                                ? InkWell(
                                    onTap: () async {
                                      if (await canLaunchUrl(Uri.parse(a.certificateUrl!))) {
                                        await launchUrl(Uri.parse(a.certificateUrl!));
                                      }
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE3EAF8)),
                                        color: const Color(0xFFF8FAFF),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: a.certificateFileName?.toLowerCase().endsWith('.pdf') ?? false
                                          ? const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 20)
                                          : Image.network(
                                              a.certificateUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 20, color: Colors.grey),
                                            ),
                                    ),
                                  )
                                : const smcText(textToDisplay: '—', textSize: 12, colorOfText: Colors.grey),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined, size: 18, color: ColorConst.primaryBlue),
                                  onPressed: () => _viewAchievement(a),
                                  tooltip: 'View',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.green),
                                  onPressed: () => _openAchievementDialog(achievement: a),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                  onPressed: () => _deleteAchievement(a),
                                  tooltip: 'Delete',
                                ),
                              ],
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

  void _openAchievementDialog({AchievementModel? achievement}) async {
    final bool isEdit = achievement != null;
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: achievement?.title ?? '');
    final orgCtrl = TextEditingController(text: achievement?.organization ?? '');
    final descCtrl = TextEditingController(text: achievement?.description ?? '');
    final dateCtrl = TextEditingController(text: achievement?.date ?? '');
    String? selectedCategory = achievement?.category;
    String? selectedLevel = achievement?.level;
    Uint8List? selectedFileBytes;
    String? selectedFileName = achievement?.certificateFileName;
    String? existingUrl = achievement?.certificateUrl;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          smcText(
                            textToDisplay: '${isEdit ? 'Edit' : 'Add'} Achievement',
                            textSize: 18,
                            textBoldness: 5,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: titleCtrl,
                        decoration: _dialogFieldDecor('Achievement Title *', hint: 'e.g. First Place in Hackathon'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedCategory,
                              decoration: _dialogFieldDecor('Category *'),
                              items: ['Academic', 'Technical', 'Sports', 'Cultural', 'Certification', 'Other']
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                                  .toList(),
                              onChanged: (v) => setModalState(() => selectedCategory = v),
                              validator: (v) => v == null ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedLevel,
                              decoration: _dialogFieldDecor('Level *'),
                              items: ['College', 'State', 'National', 'International']
                                  .map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13))))
                                  .toList(),
                              onChanged: (v) => setModalState(() => selectedLevel = v),
                              validator: (v) => v == null ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: orgCtrl,
                              decoration: _dialogFieldDecor('Organization *', hint: 'e.g. VTU, Google'),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: dateCtrl,
                              readOnly: true,
                              decoration: _dialogFieldDecor('Achievement Date *').copyWith(
                                suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
                              ),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setModalState(() => dateCtrl.text = picked.toIso8601String().split('T')[0]);
                                }
                              },
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 3,
                        decoration: _dialogFieldDecor('Description', hint: 'Briefly describe the achievement'),
                      ),
                      const SizedBox(height: 20),
                      const smcText(textToDisplay: 'Certificate (PDF/JPG/PNG) *', textSize: 13, textBoldness: 4),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
                            withData: true,
                          );
                          if (result != null) {
                            setModalState(() {
                              selectedFileBytes = result.files.first.bytes;
                              selectedFileName = result.files.first.name;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                            color: const Color(0xFFF9FAFD),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.upload_file_rounded, color: ColorConst.primaryBlue, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedFileName ?? 'Tap to upload certificate',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: selectedFileName != null ? ColorConst.textPrimary : Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (selectedFileName != null)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setModalState(() {
                                    selectedFileBytes = null;
                                    selectedFileName = null;
                                    existingUrl = null;
                                  }),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: saving ? null : () async {
                            if (!formKey.currentState!.validate()) return;
                            if (selectedFileName == null && existingUrl == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a certificate')));
                              return;
                            }
                            setModalState(() => saving = true);
                            try {
                              String? finalUrl = existingUrl;
                              if (selectedFileBytes != null) {
                                finalUrl = await _achievementService.uploadCertificate(
                                  _uuid,
                                  selectedFileName!,
                                  selectedFileBytes!,
                                );
                              }

                              final a = AchievementModel(
                                id: achievement?.id,
                                uuid: _uuid,
                                title: titleCtrl.text.trim(),
                                category: selectedCategory!,
                                level: selectedLevel!,
                                organization: orgCtrl.text.trim(),
                                date: dateCtrl.text,
                                description: descCtrl.text.trim(),
                                certificateUrl: finalUrl,
                                certificateFileName: selectedFileName,
                                createdOn: achievement?.createdOn ?? DateTime.now(),
                              );

                              if (isEdit) {
                                await _achievementService.updateAchievement(achievement!.id!, a);
                              } else {
                                await _achievementService.addAchievement(a);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              setModalState(() => saving = false);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorConst.primaryBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: saving
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : smcText(textToDisplay: isEdit ? 'Save Changes' : 'Add Achievement', textSize: 14, colorOfText: Colors.white, textBoldness: 5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dialogFieldDecor(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 13, color: ColorConst.textSecondary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ColorConst.borderSoft)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  void _viewAchievement(AchievementModel a) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: smcText(textToDisplay: a.title, textSize: 18, textBoldness: 5),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Category', a.category),
            _buildDetailRow('Level', a.level),
            _buildDetailRow('Organization', a.organization),
            _buildDetailRow('Date', _formatDisplayDate(a.date)),
            const SizedBox(height: 12),
            const smcText(textToDisplay: 'Description:', textSize: 13, textBoldness: 4),
            const SizedBox(height: 4),
            smcText(textToDisplay: a.description.isEmpty ? '—' : a.description, textSize: 13, maxLines: 5),
            if (a.certificateUrl != null) ...[
              const SizedBox(height: 16),
              const smcText(textToDisplay: 'Certificate Preview:', textSize: 13, textBoldness: 4),
              const SizedBox(height: 8),
              if (a.certificateFileName?.toLowerCase().endsWith('.pdf') ?? false)
                OutlinedButton.icon(
                  onPressed: () async {
                    if (await canLaunchUrl(Uri.parse(a.certificateUrl!))) {
                      await launchUrl(Uri.parse(a.certificateUrl!));
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('Open PDF Certificate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColorConst.primaryBlue,
                    side: const BorderSide(color: ColorConst.primaryBlue),
                  ),
                )
              else
                GestureDetector(
                  onTap: () async {
                    if (await canLaunchUrl(Uri.parse(a.certificateUrl!))) {
                      await launchUrl(Uri.parse(a.certificateUrl!));
                    }
                  },
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ColorConst.borderSoft),
                      color: const Color(0xFFF7F9FF),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Image.network(
                          a.certificateUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined, color: ColorConst.textSecondary),
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _deleteAchievement(AchievementModel a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Achievement'),
        content: Text('Are you sure you want to delete "${a.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _achievementService.deleteAchievement(a.id!, a.certificateUrl);
    }
  }

  Widget _buildCoExtraActivities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const smcText(
                textToDisplay: 'Co & Extra Activities',
                textSize: 16,
                textBoldness: 5,
                colorOfText: ColorConst.textPrimary,
              ),
              ElevatedButton.icon(
                onPressed: () => _openCoExtraActivityDialog(),
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                label: const smcText(
                  textToDisplay: 'Add Activities',
                  textSize: 13,
                  textBoldness: 4,
                  colorOfText: Colors.white,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorConst.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<CoExtraActivityModel>>(
            stream: _coExtraActivityService.getActivitiesForStudent(_uuid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final activities = snapshot.data ?? [];

              if (activities.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_run_rounded, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const smcText(
                          textToDisplay: "No activities recorded yet. Click Add Activities to add them.",
                          textSize: 14,
                          colorOfText: ColorConst.textSecondary,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  return _buildCoExtraActivityTable(activities, constraints.maxWidth);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCoExtraActivityTable(List<CoExtraActivityModel> activities, double tableWidth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF4F7FF)),
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
                        width: 150,
                        child: Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: smcText(
                              textToDisplay: 'Activity',
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
                        width: 120,
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Type',
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
                            textToDisplay: 'Level',
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
                            textToDisplay: 'Date',
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
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Achievement',
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
                            textToDisplay: 'Certificate',
                            textSize: 12,
                            textBoldness: 4,
                            colorOfText: Color(0xFF5C6B8B),
                          ),
                        ),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: 80,
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Action',
                            textSize: 12,
                            textBoldness: 4,
                            colorOfText: Color(0xFF5C6B8B),
                          ),
                        ),
                      ),
                    ),
                  ],
                  rows: activities.asMap().entries.map((entry) {
                    final index = entry.key;
                    final activity = entry.value;
                    return DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 50,
                            child: Center(
                              child: smcText(
                                textToDisplay: '${index + 1}',
                                textSize: 12,
                                colorOfText: ColorConst.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 150,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: smcText(
                                  textToDisplay: activity.activityName,
                                  textSize: 12,
                                  textBoldness: 4,
                                  colorOfText: ColorConst.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 120,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F7FF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: smcText(
                                  textToDisplay: activity.type,
                                  textSize: 11,
                                  colorOfText: ColorConst.primaryBlue,
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 100,
                            child: Center(
                              child: smcText(
                                textToDisplay: activity.level,
                                textSize: 12,
                                colorOfText: ColorConst.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 100,
                            child: Center(
                              child: smcText(
                                textToDisplay: activity.date,
                                textSize: 12,
                                colorOfText: ColorConst.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 120,
                            child: Center(
                              child: smcText(
                                textToDisplay: activity.achievement,
                                textSize: 12,
                                colorOfText: ColorConst.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 100,
                            child: Center(
                              child: activity.certificate.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.download_rounded, size: 18, color: ColorConst.primaryBlue),
                                      onPressed: () async {
                                        final url = Uri.parse(activity.certificate);
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(url);
                                        }
                                      },
                                    )
                                  : const smcText(
                                      textToDisplay: '-',
                                      textSize: 12,
                                      colorOfText: ColorConst.textSecondary,
                                    ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 80,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 16, color: ColorConst.textSecondary),
                                  onPressed: () => _openCoExtraActivityDialog(activity: activity),
                                  splashRadius: 20,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                  onPressed: () => _deleteCoExtraActivity(activity.id!),
                                  splashRadius: 20,
                                ),
                              ],
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

  void _deleteCoExtraActivity(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const smcText(textToDisplay: 'Delete Activity', textSize: 16, textBoldness: 5),
        content: const smcText(textToDisplay: 'Are you sure you want to delete this activity?', textSize: 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const smcText(textToDisplay: 'Cancel', textSize: 14, colorOfText: ColorConst.textSecondary),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              _coExtraActivityService.deleteActivity(id);
              Navigator.pop(ctx);
            },
            child: const smcText(textToDisplay: 'Delete', textSize: 14, colorOfText: Colors.white),
          ),
        ],
      ),
    );
  }

  void _openCoExtraActivityDialog({CoExtraActivityModel? activity}) async {
    final bool isEdit = activity != null;
    final formKey = GlobalKey<FormState>();
    final activityCtrl = TextEditingController(text: activity?.activityName ?? '');
    final dateCtrl = TextEditingController(text: activity?.date ?? '');
    final achievementCtrl = TextEditingController(text: activity?.achievement ?? '');
    
    String? selectedType = activity?.type;
    if (selectedType != null && !['Co-curricular', 'Extra-curricular'].contains(selectedType)) {
      selectedType = null;
    }
    String? selectedLevel = activity?.level;
    if (selectedLevel != null && !['College', 'State', 'National', 'International'].contains(selectedLevel)) {
      selectedLevel = null;
    }
    
    Uint8List? selectedFileBytes;
    String? selectedFileName;
    String? existingUrl = activity?.certificate;
    
    bool saving = false;

    InputDecoration inputDecoration(String hint) {
      return InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE4E8F0)),
        ),
      );
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          smcText(
                            textToDisplay: isEdit ? 'Edit Activity' : 'Add Activity',
                            textSize: 18,
                            textBoldness: 5,
                            colorOfText: ColorConst.textPrimary,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: ColorConst.textSecondary),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: activityCtrl,
                        decoration: inputDecoration('Activity Name'),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: inputDecoration('Select Type'),
                        items: const [
                          DropdownMenuItem(value: 'Co-curricular', child: Text('Co-curricular')),
                          DropdownMenuItem(value: 'Extra-curricular', child: Text('Extra-curricular')),
                        ],
                        onChanged: (v) => selectedType = v,
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedLevel,
                        decoration: inputDecoration('Select Level'),
                        items: const [
                          DropdownMenuItem(value: 'College', child: Text('College')),
                          DropdownMenuItem(value: 'State', child: Text('State')),
                          DropdownMenuItem(value: 'National', child: Text('National')),
                          DropdownMenuItem(value: 'International', child: Text('International')),
                        ],
                        onChanged: (v) => selectedLevel = v,
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: dateCtrl,
                        decoration: inputDecoration('Date (e.g. Oct 2023)'),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: achievementCtrl,
                        decoration: inputDecoration('Achievement'),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          FilePickerResult? result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                          );
                          if (result != null) {
                            setModalState(() {
                              selectedFileBytes = result.files.single.bytes;
                              selectedFileName = result.files.single.name;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE4E8F0)),
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.upload_file, color: ColorConst.primaryBlue, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedFileName ?? (existingUrl != null && existingUrl!.isNotEmpty ? 'Certificate Uploaded' : 'Upload Original Certificate'),
                                  style: TextStyle(
                                    color: selectedFileName != null || (existingUrl != null && existingUrl!.isNotEmpty)
                                        ? ColorConst.textPrimary
                                        : Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (formKey.currentState!.validate()) {
                                    setModalState(() => saving = true);
                                    try {
                                      String finalUrl = existingUrl ?? '';
                                      if (selectedFileBytes != null) {
                                        finalUrl = await _coExtraActivityService.uploadCertificate(
                                          _uuid,
                                          selectedFileName!,
                                          selectedFileBytes!,
                                        );
                                      }

                                      final a = CoExtraActivityModel(
                                        id: activity?.id,
                                        uuid: _uuid,
                                        activityName: activityCtrl.text.trim(),
                                        type: selectedType!,
                                        level: selectedLevel!,
                                        date: dateCtrl.text.trim(),
                                        achievement: achievementCtrl.text.trim(),
                                        certificate: finalUrl,
                                        createdOn: activity?.createdOn ?? DateTime.now(),
                                      );

                                      if (isEdit) {
                                        await _coExtraActivityService.updateActivity(activity!.id!, a);
                                      } else {
                                        await _coExtraActivityService.addActivity(a);
                                      }
                                      if (ctx.mounted) Navigator.pop(ctx);
                                    } catch (e) {
                                      setModalState(() => saving = false);
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorConst.primaryBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: saving
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : smcText(textToDisplay: isEdit ? 'Save Changes' : 'Save Activity', textSize: 14, colorOfText: Colors.white, textBoldness: 5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPublications() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const smcText(
                textToDisplay: 'Publications',
                textSize: 16,
                textBoldness: 5,
                colorOfText: ColorConst.textPrimary,
              ),
              ElevatedButton.icon(
                onPressed: () => _openPublicationDialog(),
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                label: const smcText(
                  textToDisplay: 'Add Publication',
                  textSize: 13,
                  textBoldness: 4,
                  colorOfText: Colors.white,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorConst.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<PublicationModel>>(
            stream: _publicationService.getPublicationsForStudent(_uuid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final publications = snapshot.data ?? [];

              if (publications.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.library_books_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const smcText(
                          textToDisplay: "No publications recorded yet. Click Add Publication to add the research work.",
                          textSize: 14,
                          colorOfText: ColorConst.textSecondary,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  return _buildPublicationTable(publications, constraints.maxWidth);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPublicationTable(List<PublicationModel> publications, double tableWidth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFF4F7FF)),
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
                        width: 180,
                        child: Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: smcText(
                              textToDisplay: 'Title',
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
                        width: 120,
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Type',
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
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Publisher',
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
                            textToDisplay: 'Date',
                            textSize: 12,
                            textBoldness: 4,
                            colorOfText: Color(0xFF5C6B8B),
                          ),
                        ),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: 80,
                        child: Center(
                          child: smcText(
                            textToDisplay: 'PDF',
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
                            textToDisplay: 'Actions',
                            textSize: 12,
                            textBoldness: 4,
                            colorOfText: Color(0xFF5C6B8B),
                          ),
                        ),
                      ),
                    ),
                  ],
                  rows: publications.asMap().entries.map((entry) {
                    final int index = entry.key;
                    final p = entry.value;
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
                            padding: const EdgeInsets.only(left: 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: smcText(
                                textToDisplay: p.title,
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: smcText(
                                textToDisplay: p.type,
                                textSize: 11,
                                textBoldness: 3,
                                colorOfText: const Color(0xFF166534),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: smcText(
                              textToDisplay: p.publisher,
                              textSize: 12,
                              colorOfText: const Color(0xFF2E3954),
                              maxLines: 1,
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: smcText(
                              textToDisplay: _formatDisplayDate(p.date),
                              textSize: 12,
                              colorOfText: const Color(0xFF2E3954),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: p.pdfUrl != null
                                ? IconButton(
                                    icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 20),
                                    onPressed: () async {
                                      if (await canLaunchUrl(Uri.parse(p.pdfUrl!))) {
                                        await launchUrl(Uri.parse(p.pdfUrl!));
                                      }
                                    },
                                    tooltip: 'View PDF',
                                  )
                                : const smcText(textToDisplay: '—', textSize: 12, colorOfText: Colors.grey),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined, size: 18, color: ColorConst.primaryBlue),
                                  onPressed: () => _viewPublication(p),
                                  tooltip: 'View',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.green),
                                  onPressed: () => _openPublicationDialog(publication: p),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                  onPressed: () => _deletePublication(p),
                                  tooltip: 'Delete',
                                ),
                              ],
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

  void _openPublicationDialog({PublicationModel? publication}) async {
    final bool isEdit = publication != null;
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: publication?.title ?? '');
    final authorsCtrl = TextEditingController(text: publication?.authors ?? '');
    final publisherCtrl = TextEditingController(text: publication?.publisher ?? '');
    final dateCtrl = TextEditingController(text: publication?.date ?? '');
    final abstractCtrl = TextEditingController(text: publication?.abstract ?? '');
    String? selectedType = publication?.type;
    Uint8List? selectedFileBytes;
    String? selectedFileName = publication?.pdfFileName;
    String? existingUrl = publication?.pdfUrl;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          smcText(
                            textToDisplay: '${isEdit ? 'Edit' : 'Add'} Publication',
                            textSize: 18,
                            textBoldness: 5,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: titleCtrl,
                        decoration: _dialogFieldDecor('Publication Title *', hint: 'e.g. AI in Modern Education'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedType,
                              decoration: _dialogFieldDecor('Publication Type *'),
                              items: ['Journal', 'Conference', 'Research Paper', 'Book Chapter', 'Patent']
                                  .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
                                  .toList(),
                              onChanged: (v) => setModalState(() => selectedType = v),
                              validator: (v) => v == null ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: dateCtrl,
                              readOnly: true,
                              decoration: _dialogFieldDecor('Publication Date *').copyWith(
                                suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
                              ),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setModalState(() => dateCtrl.text = picked.toIso8601String().split('T')[0]);
                                }
                              },
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: authorsCtrl,
                        decoration: _dialogFieldDecor('Authors *', hint: 'e.g. John Doe, Jane Smith'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: publisherCtrl,
                        decoration: _dialogFieldDecor('Publisher *', hint: 'e.g. IEEE, Springer'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: abstractCtrl,
                        maxLines: 4,
                        decoration: _dialogFieldDecor('Abstract', hint: 'Brief summary of the publication'),
                      ),
                      const SizedBox(height: 20),
                      const smcText(textToDisplay: 'Full Paper (PDF Only) *', textSize: 13, textBoldness: 4),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf'],
                            withData: true,
                          );
                          if (result != null) {
                            setModalState(() {
                              selectedFileBytes = result.files.first.bytes;
                              selectedFileName = result.files.first.name;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                            color: const Color(0xFFF9FAFD),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedFileName ?? 'Tap to upload PDF',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: selectedFileName != null ? ColorConst.textPrimary : Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (selectedFileName != null)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setModalState(() {
                                    selectedFileBytes = null;
                                    selectedFileName = null;
                                    existingUrl = null;
                                  }),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: saving ? null : () async {
                            if (!formKey.currentState!.validate()) return;
                            if (selectedFileName == null && existingUrl == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload the full paper PDF')));
                              return;
                            }
                            setModalState(() => saving = true);
                            try {
                              String? finalUrl = existingUrl;
                              if (selectedFileBytes != null) {
                                finalUrl = await _publicationService.uploadPublicationPdf(
                                  _uuid,
                                  selectedFileName!,
                                  selectedFileBytes!,
                                );
                              }

                              final p = PublicationModel(
                                id: publication?.id,
                                uuid: _uuid,
                                title: titleCtrl.text.trim(),
                                type: selectedType!,
                                authors: authorsCtrl.text.trim(),
                                publisher: publisherCtrl.text.trim(),
                                date: dateCtrl.text,
                                abstract: abstractCtrl.text.trim(),
                                pdfUrl: finalUrl,
                                pdfFileName: selectedFileName,
                                createdOn: publication?.createdOn ?? DateTime.now(),
                              );

                              if (isEdit) {
                                await _publicationService.updatePublication(publication!.id!, p);
                              } else {
                                await _publicationService.addPublication(p);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              setModalState(() => saving = false);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorConst.primaryBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: saving
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : smcText(textToDisplay: isEdit ? 'Save Changes' : 'Add Publication', textSize: 14, colorOfText: Colors.white, textBoldness: 5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _viewPublication(PublicationModel p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: smcText(textToDisplay: p.title, textSize: 18, textBoldness: 5),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Type', p.type),
              _buildDetailRow('Authors', p.authors),
              _buildDetailRow('Publisher', p.publisher),
              _buildDetailRow('Date', _formatDisplayDate(p.date)),
              const SizedBox(height: 12),
              const smcText(textToDisplay: 'Abstract:', textSize: 13, textBoldness: 4),
              const SizedBox(height: 4),
              smcText(textToDisplay: p.abstract.isEmpty ? '—' : p.abstract, textSize: 13, maxLines: 10),
              if (p.pdfUrl != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    if (await canLaunchUrl(Uri.parse(p.pdfUrl!))) {
                      await launchUrl(Uri.parse(p.pdfUrl!));
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('View Full Paper'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColorConst.primaryBlue,
                    side: const BorderSide(color: ColorConst.primaryBlue),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _deletePublication(PublicationModel p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Publication'),
        content: Text('Are you sure you want to delete "${p.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _publicationService.deletePublication(p.id!, p.pdfUrl);
    }
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
  String? _currentSemester;
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
    _currentSemester = student.currentSemester.isEmpty
        ? null
        : student.currentSemester;
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
      currentSemester: _currentSemester ?? '',
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
                          _buildDropdown(
                            label: 'Current Semester',
                            value: _currentSemester,
                            options: StudentModel.semesterOptions,
                            onChanged: (value) =>
                                setState(() => _currentSemester = value),
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
