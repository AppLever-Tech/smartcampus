import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/class_attendance_firestore_service.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_date_utils.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_resolver.dart';
import 'package:smartcampus/services/course_firestore_service.dart';
import 'package:smartcampus/services/student_firestore_service.dart';
import 'package:smartcampus/widgets/profile_photo_avatar.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class FacultyClassStudentsPage extends StatefulWidget {
  final String orgId;
  final FacultyModel faculty;
  final List<CourseModel> assignedCourses;
  final String courseId;
  final String courseName;
  final String batch;
  final String section;
  final String semester;
  final String? dayName;
  final String? timing;
  final String timeSlotName;
  final String timeSlotUid;
  final String timeTableUid;
  final String timeBlockUid;
  final String dayUid;
  final DateTime classDate;
  final String? activeClassRecordId;
  final bool useTableLayout;

  const FacultyClassStudentsPage({
    super.key,
    required this.orgId,
    required this.faculty,
    required this.assignedCourses,
    required this.courseId,
    required this.courseName,
    required this.batch,
    required this.section,
    required this.semester,
    this.dayName,
    this.timing,
    this.timeSlotName = '',
    this.timeSlotUid = '',
    this.timeTableUid = '',
    this.timeBlockUid = '',
    this.dayUid = '',
    required this.classDate,
    this.activeClassRecordId,
    this.useTableLayout = false,
  });

  static const double _webLayoutBreakpoint = 768;

  static bool isWebLayout(BuildContext context) {
    return kIsWeb ||
        MediaQuery.sizeOf(context).width >= _webLayoutBreakpoint;
  }

  static Future<void> open({
    required BuildContext context,
    required String orgId,
    required FacultyModel faculty,
    required List<CourseModel> assignedCourses,
    required String courseId,
    required String courseName,
    required String batch,
    required String section,
    required String semester,
    String? dayName,
    String? timing,
    String timeSlotName = '',
    String timeSlotUid = '',
    String timeTableUid = '',
    String timeBlockUid = '',
    String dayUid = '',
    DateTime? classDate,
    String? activeClassRecordId,
  }) {
    final useTableLayout = isWebLayout(context);
    final content = FacultyClassStudentsPage(
      orgId: orgId,
      faculty: faculty,
      assignedCourses: assignedCourses,
      courseId: courseId,
      courseName: courseName,
      batch: batch,
      section: section,
      semester: semester,
      dayName: dayName,
      timing: timing,
      timeSlotName: timeSlotName,
      timeSlotUid: timeSlotUid,
      timeTableUid: timeTableUid,
      timeBlockUid: timeBlockUid,
      dayUid: dayUid,
      classDate: FacultyClassDateUtils.dateOnly(
        classDate ?? DateTime.now(),
      ),
      activeClassRecordId: activeClassRecordId,
      useTableLayout: useTableLayout,
    );

    if (useTableLayout) {
      return showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1040,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.85,
            ),
            child: content,
          ),
        ),
      );
    }

    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => content),
    );
  }

  @override
  State<FacultyClassStudentsPage> createState() =>
      _FacultyClassStudentsPageState();
}

class _FacultyClassStudentsPageState extends State<FacultyClassStudentsPage> {
  final TextEditingController _searchController = TextEditingController();
  final StudentFirestoreService _studentService = StudentFirestoreService();
  final ClassAttendanceFirestoreService _attendanceService =
      ClassAttendanceFirestoreService();

  bool _loading = true;
  bool _attendanceMode = false;
  bool _savingAttendance = false;
  bool _startingClass = false;
  String? _loadError;
  String? _classRecordId;
  List<StudentModel> _enrolledStudents = const [];
  Map<String, bool> _attendanceByStudentKey = {};

  @override
  void initState() {
    super.initState();
    _classRecordId = widget.activeClassRecordId?.trim().isNotEmpty ?? false
        ? widget.activeClassRecordId!.trim()
        : null;
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _studentKey(StudentModel student) {
    return CourseFirestoreService.studentEnrollmentKey(student);
  }

  String get _facultyUid =>
      CourseFirestoreService.facultyAssignmentKey(widget.faculty);

  bool get _classStarted => _classRecordId?.trim().isNotEmpty ?? false;

  bool get _canStartClass =>
      !_loading &&
      !_startingClass &&
      _loadError == null &&
      _enrolledStudents.isNotEmpty &&
      !_attendanceMode &&
      !_classStarted &&
      FacultyClassDateUtils.isSameDay(
        widget.classDate,
        FacultyClassDateUtils.dateOnly(DateTime.now()),
      );

  Future<void> _loadStudents() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final course = FacultyClassResolver.resolveCourseForTimeBlock(
        courses: widget.assignedCourses,
        courseId: widget.courseId,
        batch: widget.batch,
        semester: widget.semester,
      );

      if (course == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _enrolledStudents = const [];
          _loadError = 'Course record not found for this class.';
        });
        return;
      }

      final allStudents =
          await _studentService.listStudentsForOrg(widget.orgId);
      final enrolled = allStudents
          .where(
            (student) =>
                CourseFirestoreService.isCourseEnrolledForStudent(
                  course,
                  student,
                ),
          )
          .toList()
        ..sort(
          (a, b) =>
              a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        );

      if (!mounted) return;
      setState(() {
        _loading = false;
        _enrolledStudents = enrolled;
      });
      await _restoreActiveClassState();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Failed to load students: $e';
      });
    }
  }

  Future<void> _restoreActiveClassState() async {
    if (_classRecordId != null) {
      if (mounted) {
        _beginAttendanceMode();
      }
      return;
    }

    try {
      final activeRecord = await _attendanceService.findActiveClassForSession(
        orgId: widget.orgId,
        facultyUid: _facultyUid,
        classDate: widget.classDate,
        timeBlockUid: widget.timeBlockUid,
        timeTableUid: widget.timeTableUid,
        courseId: widget.courseId,
        batch: widget.batch,
        section: widget.section,
        semester: widget.semester,
        dayUid: widget.dayUid,
        dayName: widget.dayName ?? '',
        timeSlotUid: widget.timeSlotUid,
        timeSlotName: widget.timeSlotName,
      );

      if (!mounted || activeRecord == null) {
        return;
      }

      setState(() {
        _classRecordId = activeRecord.id;
      });
      _beginAttendanceMode(initialAttendance: activeRecord.attendance);
    } catch (_) {
      // Active class lookup is best-effort; students list still works.
    }
  }

  Future<void> _confirmStartClass() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const smcText(
          textToDisplay: 'Start Class',
          textSize: 18,
          textBoldness: 4,
          colorOfText: ColorConst.textPrimary,
        ),
        content: const smcText(
          textToDisplay:
              'Are you sure you want to start this class? A class record will be created and you can mark attendance.',
          textSize: 14,
          colorOfText: ColorConst.textSecondary,
          maxLines: 4,
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

    setState(() => _startingClass = true);

    try {
      final recordId = await _attendanceService.startClass(
        orgId: widget.orgId,
        facultyUid: _facultyUid,
        facultyName: widget.faculty.fullName,
        classDate: widget.classDate,
        courseId: widget.courseId,
        courseName: widget.courseName,
        dayName: widget.dayName ?? '',
        dayUid: widget.dayUid,
        timeSlotName: widget.timeSlotName,
        timeSlotUid: widget.timeSlotUid,
        timeTableUid: widget.timeTableUid,
        timeBlockUid: widget.timeBlockUid,
        batch: widget.batch,
        section: widget.section,
        semester: widget.semester,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _startingClass = false;
        _classRecordId = recordId;
      });
      _beginAttendanceMode();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _startingClass = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start class: $e')),
      );
    }
  }

  void _beginAttendanceMode({Map<String, bool>? initialAttendance}) {
    setState(() {
      _attendanceMode = true;
      _attendanceByStudentKey = {
        for (final student in _enrolledStudents)
          _studentKey(student): initialAttendance?[_studentKey(student)] ?? false,
      };
    });
  }

  void _cancelAttendance() {
    setState(() {
      _attendanceMode = false;
      _attendanceByStudentKey = {};
    });
  }

  Future<void> _saveAttendance() async {
    final recordId = _classRecordId?.trim() ?? '';
    if (recordId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start the class before saving attendance.'),
        ),
      );
      return;
    }

    setState(() => _savingAttendance = true);

    try {
      await _attendanceService.saveAttendance(
        recordId: recordId,
        attendanceByStudentKey: _attendanceByStudentKey,
      );

      if (!mounted) return;
      setState(() {
        _savingAttendance = false;
        _attendanceMode = false;
        _attendanceByStudentKey = {};
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance saved successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingAttendance = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save attendance: $e')),
      );
    }
  }

  String get _headerTitle {
    final name = widget.courseName.trim();
    final code = widget.courseId.trim();
    if (name.isNotEmpty && code.isNotEmpty) {
      return '$name ($code)';
    }
    return name.isNotEmpty ? name : code;
  }

  String? get _headerSubtitle {
    final parts = <String>[
      if (widget.dayName?.trim().isNotEmpty ?? false) widget.dayName!.trim(),
      if (widget.timing?.trim().isNotEmpty ?? false) widget.timing!.trim(),
      if (widget.batch.trim().isNotEmpty) widget.batch.trim(),
      if (widget.semester.trim().isNotEmpty) 'Sem: ${widget.semester.trim()}',
      if (widget.section.trim().isNotEmpty) widget.section.trim(),
    ];
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' · ');
  }

  List<StudentModel> get _filteredStudents {
    final searchTerm = _searchController.text.trim().toLowerCase();
    if (searchTerm.isEmpty) {
      return _enrolledStudents;
    }
    return _enrolledStudents
        .where(
          (student) =>
              '${student.studentId} ${student.fullName} ${student.email} ${student.mobile} ${student.batch} ${student.gender}'
                  .toLowerCase()
                  .contains(searchTerm),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useTableLayout) {
      return _buildDialogContent();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: ColorConst.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const smcText(
              textToDisplay: 'Enrolled Students',
              textSize: 16,
              textBoldness: 5,
              colorOfText: ColorConst.textPrimary,
            ),
            if (_headerSubtitle != null)
              smcText(
                textToDisplay: _headerSubtitle!,
                textSize: 12,
                colorOfText: ColorConst.textSecondary,
                maxLines: 2,
              ),
          ],
        ),
        actions: [
          if (_canStartClass) _buildStartClassButton(compact: true),
          if (_classStarted && !_attendanceMode && !_loading)
            _buildMarkAttendanceButton(compact: true),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildPanelContent(),
      ),
    );
  }

  Widget _buildMarkAttendanceButton({bool compact = false}) {
    return Padding(
      padding: EdgeInsets.only(right: compact ? 8 : 0),
      child: ElevatedButton.icon(
        onPressed: _beginAttendanceMode,
        icon: const Icon(Icons.fact_check_outlined, size: 18),
        label: const smcText(
          textToDisplay: 'Mark Attendance',
          textSize: 13,
          textBoldness: 4,
          colorOfText: Colors.white,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorConst.primaryBlue,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 8 : 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildStartClassButton({bool compact = false}) {
    return Padding(
      padding: EdgeInsets.only(right: compact ? 8 : 0),
      child: ElevatedButton.icon(
        onPressed: _startingClass ? null : _confirmStartClass,
        icon: const Icon(Icons.play_arrow_rounded, size: 18),
        label: const smcText(
          textToDisplay: 'Start Class',
          textSize: 13,
          textBoldness: 4,
          colorOfText: Colors.white,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorConst.primaryBlue,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 8 : 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const smcText(
                      textToDisplay: 'Enrolled Students',
                      textSize: 18,
                      textBoldness: 5,
                      colorOfText: ColorConst.textPrimary,
                    ),
                    const SizedBox(height: 4),
                    smcText(
                      textToDisplay: _headerTitle,
                      textSize: 14,
                      textBoldness: 4,
                      colorOfText: ColorConst.textPrimary,
                      maxLines: 2,
                    ),
                    if (_headerSubtitle != null) ...[
                      const SizedBox(height: 4),
                      smcText(
                        textToDisplay: _headerSubtitle!,
                        textSize: 12,
                        colorOfText: ColorConst.textSecondary,
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
              if (_canStartClass) ...[
                _buildStartClassButton(),
                const SizedBox(width: 8),
              ],
              if (_classStarted && !_attendanceMode && !_loading) ...[
                _buildMarkAttendanceButton(),
                const SizedBox(width: 8),
              ],
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: ColorConst.textSecondary,
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildPanelContent()),
        ],
      ),
    );
  }

  Widget _buildPanelContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.useTableLayout) ...[
          smcText(
            textToDisplay: _headerTitle,
            textSize: 15,
            textBoldness: 5,
            colorOfText: ColorConst.textPrimary,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search by USN, name, email...',
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: ColorConst.textSecondary,
            ),
            filled: true,
            fillColor: widget.useTableLayout
                ? const Color(0xFFF6F7FB)
                : Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE3EAF8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE3EAF8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: ColorConst.primaryBlue),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const smcText(
              textToDisplay: 'Students',
              textSize: 14,
              textBoldness: 5,
              colorOfText: ColorConst.textPrimary,
            ),
            const SizedBox(width: 6),
            smcText(
              textToDisplay: _loading ? '...' : '${_filteredStudents.length}',
              textSize: 14,
              colorOfText: ColorConst.textSecondary,
            ),
            if (_attendanceMode) ...[
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const smcText(
                  textToDisplay: 'Attendance mode',
                  textSize: 11,
                  textBoldness: 4,
                  colorOfText: Color(0xFF2E7D32),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: widget.useTableLayout ? _buildTableBody() : _buildListBody(),
        ),
      ],
    );
  }

  Widget _buildAttendanceActions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE3EAF8))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _savingAttendance ? null : _cancelAttendance,
            style: OutlinedButton.styleFrom(
              foregroundColor: ColorConst.textSecondary,
              side: const BorderSide(color: Color(0xFFE3EAF8)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
            onPressed: _savingAttendance ? null : _saveAttendance,
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorConst.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _savingAttendance
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const smcText(
                    textToDisplay: 'Save',
                    textSize: 13,
                    textBoldness: 4,
                    colorOfText: Colors.white,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSwitch(StudentModel student) {
    final key = _studentKey(student);
    return Switch(
      value: _attendanceByStudentKey[key] ?? false,
      onChanged: (value) {
        setState(() => _attendanceByStudentKey[key] = value);
      },
      activeThumbColor: ColorConst.primaryBlue,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  List<DataColumn> _buildTableColumns() {
    final columns = <DataColumn>[
      const DataColumn(
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
      const DataColumn(
        label: SizedBox(
          width: 110,
          child: Padding(
            padding: EdgeInsets.only(left: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: smcText(
                textToDisplay: 'USN / ID',
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
          width: 220,
          child: Center(
            child: smcText(
              textToDisplay: 'Name',
              textSize: 12,
              textBoldness: 4,
              colorOfText: Color(0xFF5C6B8B),
            ),
          ),
        ),
      ),
      const DataColumn(
        label: SizedBox(
          width: 200,
          child: Center(
            child: smcText(
              textToDisplay: 'Email',
              textSize: 12,
              textBoldness: 4,
              colorOfText: Color(0xFF5C6B8B),
            ),
          ),
        ),
      ),
      const DataColumn(
        label: SizedBox(
          width: 120,
          child: Center(
            child: smcText(
              textToDisplay: 'Mobile #',
              textSize: 12,
              textBoldness: 4,
              colorOfText: Color(0xFF5C6B8B),
            ),
          ),
        ),
      ),
      const DataColumn(
        label: SizedBox(
          width: 90,
          child: Center(
            child: smcText(
              textToDisplay: 'Batch',
              textSize: 12,
              textBoldness: 4,
              colorOfText: Color(0xFF5C6B8B),
            ),
          ),
        ),
      ),
      const DataColumn(
        label: SizedBox(
          width: 90,
          child: Center(
            child: smcText(
              textToDisplay: 'Gender',
              textSize: 12,
              textBoldness: 4,
              colorOfText: Color(0xFF5C6B8B),
            ),
          ),
        ),
      ),
    ];

    if (_attendanceMode) {
      columns.add(
        const DataColumn(
          label: SizedBox(
            width: 110,
            child: Center(
              child: smcText(
                textToDisplay: 'Attendance',
                textSize: 12,
                textBoldness: 4,
                colorOfText: Color(0xFF5C6B8B),
              ),
            ),
          ),
        ),
      );
    }

    return columns;
  }

  Widget _buildTableBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: smcText(
          textToDisplay: _loadError!,
          textSize: 14,
          colorOfText: ColorConst.textSecondary,
          textAlign: TextAlign.center,
          maxLines: 4,
        ),
      );
    }

    final students = _filteredStudents;
    if (students.isEmpty) {
      return Center(
        child: smcText(
          textToDisplay: _searchController.text.trim().isEmpty
              ? 'No students enrolled in this course yet.'
              : 'No students match your search.',
          textSize: 14,
          colorOfText: ColorConst.textSecondary,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EAF8)),
      ),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        showCheckboxColumn: false,
                        headingRowHeight: 48,
                        dataRowMinHeight: 52,
                        dataRowMaxHeight: 58,
                        horizontalMargin: 0,
                        columnSpacing: 0,
                        dividerThickness: 1,
                        border: const TableBorder(
                          horizontalInside:
                              BorderSide(color: Color(0xFFE3EAF8)),
                          verticalInside:
                              BorderSide(color: Color(0xFFE3EAF8)),
                        ),
                        headingRowColor: MaterialStateProperty.all(
                          const Color(0xFFF4F7FF),
                        ),
                        columns: _buildTableColumns(),
                        rows: students.asMap().entries.map((entry) {
                          final int index = entry.key;
                          final StudentModel student = entry.value;
                          final initial = student.fullName.trim().isEmpty
                              ? '?'
                              : student.fullName
                                  .trim()
                                  .substring(0, 1)
                                  .toUpperCase();

                          final cells = <DataCell>[
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
                                    textToDisplay: student.studentId,
                                    textSize: 12,
                                    textBoldness: 4,
                                    colorOfText: const Color(0xFF2E3954),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  children: [
                                    ProfilePhotoAvatar(
                                      photoUrl: student.photographUrl,
                                      fallbackInitial: initial,
                                      radius: 16,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: smcText(
                                        textToDisplay:
                                            student.fullName.trim().isEmpty
                                                ? student.studentId
                                                : student.fullName,
                                        textSize: 12,
                                        colorOfText: const Color(0xFF2E3954),
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(
                              Center(
                                child: smcText(
                                  textToDisplay: student.email,
                                  textSize: 12,
                                  colorOfText: const Color(0xFF2E3954),
                                  maxLines: 1,
                                ),
                              ),
                            ),
                            DataCell(
                              Center(
                                child: smcText(
                                  textToDisplay: student.mobile,
                                  textSize: 12,
                                  colorOfText: const Color(0xFF2E3954),
                                  maxLines: 1,
                                ),
                              ),
                            ),
                            DataCell(
                              Center(
                                child: smcText(
                                  textToDisplay: student.batch.isEmpty
                                      ? '—'
                                      : student.batch,
                                  textSize: 12,
                                  colorOfText: const Color(0xFF2E3954),
                                  maxLines: 1,
                                ),
                              ),
                            ),
                            DataCell(
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF4FF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: smcText(
                                    textToDisplay: student.gender.isEmpty
                                        ? '—'
                                        : student.gender,
                                    textSize: 11,
                                    textBoldness: 3,
                                    colorOfText: const Color(0xFF3558DA),
                                  ),
                                ),
                              ),
                            ),
                          ];

                          if (_attendanceMode) {
                            cells.add(
                              DataCell(
                                Center(
                                  child: _buildAttendanceSwitch(student),
                                ),
                              ),
                            );
                          }

                          return DataRow(cells: cells);
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_attendanceMode) _buildAttendanceActions(),
        ],
      ),
    );
  }

  Widget _buildListBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: smcText(
          textToDisplay: _loadError!,
          textSize: 14,
          colorOfText: ColorConst.textSecondary,
          textAlign: TextAlign.center,
          maxLines: 4,
        ),
      );
    }

    final students = _filteredStudents;
    if (students.isEmpty) {
      return Center(
        child: smcText(
          textToDisplay: _searchController.text.trim().isEmpty
              ? 'No students enrolled in this course yet.'
              : 'No students match your search.',
          textSize: 14,
          colorOfText: ColorConst.textSecondary,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EAF8)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: students.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                color: Color(0xFFE3EAF8),
              ),
              itemBuilder: (context, index) {
                final student = students[index];
                final initial = student.fullName.trim().isEmpty
                    ? '?'
                    : student.fullName.trim().substring(0, 1).toUpperCase();

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  leading: ProfilePhotoAvatar(
                    photoUrl: student.photographUrl,
                    fallbackInitial: initial,
                    radius: 20,
                  ),
                  title: smcText(
                    textToDisplay: student.fullName.trim().isEmpty
                        ? student.studentId
                        : student.fullName,
                    textSize: 14,
                    textBoldness: 5,
                    colorOfText: ColorConst.textPrimary,
                    maxLines: 1,
                  ),
                  subtitle: smcText(
                    textToDisplay: _studentSubtitle(student),
                    textSize: 12,
                    colorOfText: ColorConst.textSecondary,
                    maxLines: 2,
                  ),
                  trailing: _attendanceMode
                      ? _buildAttendanceSwitch(student)
                      : null,
                );
              },
            ),
          ),
          if (_attendanceMode) _buildAttendanceActions(),
        ],
      ),
    );
  }

  String _studentSubtitle(StudentModel student) {
    final parts = <String>[
      if (student.studentId.trim().isNotEmpty) student.studentId.trim(),
      if (student.batch.trim().isNotEmpty) student.batch.trim(),
      if (student.email.trim().isNotEmpty) student.email.trim(),
    ];
    return parts.join(' · ');
  }
}
