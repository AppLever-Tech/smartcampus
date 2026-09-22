import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/models/assignment_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/services/assignment_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/services/student_firestore_service.dart';
import 'package:smartcampus/services/course_firestore_service.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/class_attendance_firestore_service.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_date_utils.dart';
import 'package:smartcampus/screens/faculty/faculty_course_management/faculty_course_internal_marks_tab.dart';
import 'package:url_launcher/url_launcher.dart';

class FacultyCourseManagementPage extends StatefulWidget {
  final FacultyModel faculty;
  final CourseModel course;

  const FacultyCourseManagementPage({
    super.key,
    required this.faculty,
    required this.course,
  });

  @override
  State<FacultyCourseManagementPage> createState() =>
      _FacultyCourseManagementPageState();
}

class _FacultyCourseManagementPageState
    extends State<FacultyCourseManagementPage> {
  final StudentFirestoreService _studentService = StudentFirestoreService();
  final ClassAttendanceFirestoreService _attendanceService =
      ClassAttendanceFirestoreService();
  final AssignmentFirestoreService _assignmentService =
      AssignmentFirestoreService();

  List<StudentModel> _enrolledStudents = [];
  bool _loading = true;
  String? _loadError;
  StudentModel? _selectedStudent;

  String _studentKey(StudentModel student) {
    return CourseFirestoreService.studentEnrollmentKey(student);
  }

  String get _facultyUid =>
      CourseFirestoreService.facultyAssignmentKey(widget.faculty);

  String _formatDate(DateTime date) {
    final normalized = FacultyClassDateUtils.dateOnly(date);
    final day = normalized.day.toString().padLeft(2, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    return '$day/$month/${normalized.year}';
  }

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final allStudents =
          await _studentService.listStudentsForOrg(widget.faculty.orgId);
      final enrolled = allStudents
          .where((student) => CourseFirestoreService.isCourseEnrolledForStudent(
                widget.course,
                student,
              ))
          .toList()
        ..sort((a, b) =>
            a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _loading = false;
        _enrolledStudents = enrolled;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Failed to load students: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              textToDisplay: widget.course.courseTitle,
              textSize: 16,
              textBoldness: 5,
              colorOfText: Colors.white,
            ),
            smcText(
              textToDisplay: 'Course Code: ${widget.course.courseCode}',
              textSize: 12,
              colorOfText: Colors.white.withOpacity(0.8),
            ),
          ],
        ),
      ),
      body: Row(
        children: [
          // Left Pane: Student List
          Expanded(
            flex: 5,
            child: _buildStudentList(),
          ),
          // Right Pane: Selected Student Details
          if (_selectedStudent != null)
            Expanded(
              flex: 5,
              child: _buildStudentDetailsPane(),
            ),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: smcText(
          textToDisplay: _loadError!,
          textSize: 14,
          colorOfText: Colors.red,
        ),
      );
    }
    if (_enrolledStudents.isEmpty) {
      return const Center(
        child: smcText(
          textToDisplay: 'No students enrolled in this course.',
          textSize: 14,
          colorOfText: ColorConst.textSecondary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE3EAF8)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: smcText(
                  textToDisplay:
                      'Enrolled Students (${_enrolledStudents.length})',
                  textSize: 16,
                  textBoldness: 5,
                  colorOfText: ColorConst.textPrimary,
                ),
              ),
              // ── Create Assignment button ──────────────────────────────────
              ElevatedButton.icon(
                onPressed: () => _showAssignmentDialog(context),
                icon: const Icon(Icons.assignment_add, size: 18),
                label: const Text('Create Assignment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // ── Take Attendance button ────────────────────────────────────
              ElevatedButton.icon(
                onPressed: _showTakeAttendanceDialog,
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('Take Attendance'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorConst.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _enrolledStudents.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final student = _enrolledStudents[index];
              final isSelected =
                  _selectedStudent?.documentId == student.documentId;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedStudent = student;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? const Color(0xFFE8F0FE) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1967D2)
                          : const Color(0xFFE3EAF8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F7FF),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE3EAF8)),
                        ),
                        alignment: Alignment.center,
                        child: smcText(
                          textToDisplay: '${index + 1}',
                          textSize: 12,
                          textBoldness: 4,
                          colorOfText: const Color(0xFF5C6B8B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            smcText(
                              textToDisplay: student.fullName,
                              textSize: 14,
                              textBoldness: 5,
                              colorOfText: ColorConst.textPrimary,
                            ),
                            const SizedBox(height: 4),
                            smcText(
                              textToDisplay: 'USN: ${student.studentId}',
                              textSize: 12,
                              colorOfText: ColorConst.textSecondary,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF5C6B8B),
                      ),
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

  Widget _buildStudentDetailsPane() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Color(0xFFE3EAF8), width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: ColorConst.primaryBlue,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      smcText(
                        textToDisplay: _selectedStudent!.fullName,
                        textSize: 15,
                        textBoldness: 5,
                        colorOfText: Colors.white,
                        maxLines: 1,
                      ),
                      smcText(
                        textToDisplay: 'USN: ${_selectedStudent!.studentId}',
                        textSize: 12,
                        colorOfText: Colors.white.withOpacity(0.85),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  tooltip: 'Close details',
                  onPressed: () {
                    setState(() {
                      _selectedStudent = null;
                    });
                  },
                ),
              ],
            ),
          ),

          // Tabs
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE3EAF8)),
                      ),
                    ),
                    child: const TabBar(
                      labelColor: ColorConst.primaryBlue,
                      unselectedLabelColor: ColorConst.textSecondary,
                      indicatorColor: ColorConst.primaryBlue,
                      labelStyle: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      tabs: [
                        Tab(text: 'Internal Marks'),
                        Tab(text: 'Attendance'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildInternalMarksTab(),
                        _buildAttendanceTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInternalMarksTab() {
    return FacultyCourseInternalMarksTab(
      student: _selectedStudent!,
      course: widget.course,
    );
  }

  Widget _buildAttendanceTab() {
    return const Center(child: Text('Attendance summary coming soon'));
  }

  // ─── Create / Edit Assignment Dialog ──────────────────────────────────────

  void _showAssignmentDialog(BuildContext context,
      {AssignmentModel? existing}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _AssignmentDialog(
        courseId: widget.course.id,
        facultyId: widget.faculty.facultyId,
        orgId: widget.faculty.orgId,
        assignmentService: _assignmentService,
        existing: existing,
      ),
    );
  }

  // ─── Take Attendance Dialog ────────────────────────────────────────────────

  Future<void> _showTakeAttendanceDialog() async {
    if (_enrolledStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No enrolled students available.')),
      );
      return;
    }

    DateTime selectedDate = FacultyClassDateUtils.dateOnly(DateTime.now());
    int selectedHour = 1;
    final Map<String, bool> attendanceByStudentKey = {
      for (final student in _enrolledStudents) _studentKey(student): true,
    };
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        Future<void> saveAttendance(StateSetter setDialogState) async {
          setDialogState(() => isSaving = true);

          try {
            final String batch =
                _enrolledStudents.isNotEmpty ? _enrolledStudents.first.batch : '';
            final String semester = _enrolledStudents.isNotEmpty
                ? _enrolledStudents.first.currentSemester
                : '';
            final String timeSlotName = '$selectedHour Hr';
            final String timeSlotUid = 'hour_$selectedHour';

            final existingRecord =
                await _attendanceService.findClassRecordForSession(
              orgId: widget.faculty.orgId,
              facultyUid: _facultyUid,
              classDate: selectedDate,
              timeBlockUid: '',
              timeTableUid: '',
              courseId: widget.course.id,
              batch: batch,
              section: '',
              semester: semester,
              dayUid: '',
              dayName: '',
              timeSlotUid: timeSlotUid,
              timeSlotName: timeSlotName,
            );

            final String recordId = existingRecord?.id ??
                await _attendanceService.startClass(
                  orgId: widget.faculty.orgId,
                  facultyUid: _facultyUid,
                  facultyName: widget.faculty.fullName,
                  classDate: selectedDate,
                  courseId: widget.course.id,
                  courseName: widget.course.courseTitle,
                  dayName: '',
                  dayUid: '',
                  timeSlotName: timeSlotName,
                  timeSlotUid: timeSlotUid,
                  timeTableUid: '',
                  timeBlockUid: '',
                  batch: batch,
                  section: '',
                  semester: semester,
                );

            await _attendanceService.saveAttendance(
              recordId: recordId,
              attendanceByStudentKey: attendanceByStudentKey,
            );

            if (existingRecord == null || !existingRecord.isCompleted) {
              await _attendanceService.completeClass(recordId: recordId);
            }

            if (!mounted) {
              return;
            }
            Navigator.pop(dialogContext);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Attendance saved for ${_formatDate(selectedDate)} - $timeSlotName.',
                ),
              ),
            );
          } catch (e) {
            if (!mounted) {
              return;
            }
            setDialogState(() => isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to save attendance: $e')),
            );
          }
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 860,
                  maxHeight: 680,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: smcText(
                              textToDisplay:
                                  'Take Attendance - ${widget.course.courseTitle}',
                              textSize: 18,
                              textBoldness: 5,
                              colorOfText: ColorConst.textPrimary,
                              maxLines: 2,
                            ),
                          ),
                          IconButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final pickedDate = await showDatePicker(
                                      context: dialogContext,
                                      initialDate: selectedDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    if (pickedDate == null) {
                                      return;
                                    }
                                    setDialogState(() {
                                      selectedDate =
                                          FacultyClassDateUtils.dateOnly(
                                        pickedDate,
                                      );
                                    });
                                  },
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(
                              'Attendance Date: ${_formatDate(selectedDate)}',
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: DropdownButtonFormField<int>(
                              value: selectedHour,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Hour',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: List.generate(7, (index) {
                                final hour = index + 1;
                                return DropdownMenuItem<int>(
                                  value: hour,
                                  child: Text('$hour Hr'),
                                );
                              }),
                              onChanged: isSaving
                                  ? null
                                  : (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      setDialogState(() {
                                        selectedHour = value;
                                      });
                                    },
                            ),
                          ),
                          ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () {
                                    setDialogState(() {
                                      for (final student in _enrolledStudents) {
                                        attendanceByStudentKey[
                                            _studentKey(student)] = true;
                                      }
                                    });
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE8F0FE),
                              foregroundColor: ColorConst.primaryBlue,
                              elevation: 0,
                            ),
                            child: const Text('Mark All Present'),
                          ),
                          ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () => saveAttendance(setDialogState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorConst.primaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Save Attendance'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE3EAF8)),
                          ),
                        ),
                        child: Row(
                          children: const [
                            Expanded(
                              flex: 4,
                              child: smcText(
                                textToDisplay: 'Student',
                                textSize: 13,
                                textBoldness: 5,
                                colorOfText: ColorConst.textPrimary,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: smcText(
                                textToDisplay: 'USN',
                                textSize: 13,
                                textBoldness: 5,
                                colorOfText: ColorConst.textPrimary,
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: smcText(
                                textToDisplay: 'Attendance',
                                textSize: 13,
                                textBoldness: 5,
                                colorOfText: ColorConst.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _enrolledStudents.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final student = _enrolledStudents[index];
                            final key = _studentKey(student);
                            final bool isPresent =
                                attendanceByStudentKey[key] ?? true;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: smcText(
                                      textToDisplay: student.fullName,
                                      textSize: 14,
                                      textBoldness: 4,
                                      colorOfText: ColorConst.textPrimary,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: smcText(
                                      textToDisplay: student.studentId,
                                      textSize: 14,
                                      colorOfText: ColorConst.textSecondary,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ChoiceChip(
                                          label: const Text('Present'),
                                          selected: isPresent,
                                          selectedColor:
                                              const Color(0xFFD7F5E8),
                                          onSelected: isSaving
                                              ? null
                                              : (_) {
                                                  setDialogState(() {
                                                    attendanceByStudentKey[
                                                        key] = true;
                                                  });
                                                },
                                        ),
                                        ChoiceChip(
                                          label: const Text('Absent'),
                                          selected: !isPresent,
                                          selectedColor:
                                              const Color(0xFFFDECEE),
                                          onSelected: isSaving
                                              ? null
                                              : (_) {
                                                  setDialogState(() {
                                                    attendanceByStudentKey[
                                                        key] = false;
                                                  });
                                                },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Assignment Dialog  (Create + Edit)
// ═══════════════════════════════════════════════════════════════════════════

class _AssignmentDialog extends StatefulWidget {
  final String courseId;
  final String facultyId;
  final String orgId;
  final AssignmentFirestoreService assignmentService;
  final AssignmentModel? existing; // null = create mode

  const _AssignmentDialog({
    required this.courseId,
    required this.facultyId,
    required this.orgId,
    required this.assignmentService,
    this.existing,
  });

  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  DateTime? _dueDate;
  bool _isSaving = false;

  // Document attachment (optional)
  String? _pickedFileName;
  Uint8List? _pickedFileBytes;
  // If editing an existing assignment that already has a document
  String? _existingDocUrl;
  String? _existingDocName;
  bool _removeExistingDoc = false;

  bool get _isEditMode => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _titleCtrl = TextEditingController(text: a?.title ?? '');
    _descCtrl = TextEditingController(text: a?.description ?? '');
    if (a != null && a.submitDate.isNotEmpty) {
      try {
        _dueDate = DateTime.parse(a.submitDate);
      } catch (_) {}
    }
    _existingDocUrl = a?.documentUrl;
    _existingDocName = a?.documentName;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
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
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'jpg', 'png'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _pickedFileName = file.name;
        _pickedFileBytes = file.bytes;
        _removeExistingDoc = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a due date.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String docUrl = '';
      String docName = '';

      // Handle document upload / preservation / removal
      if (_pickedFileBytes != null && _pickedFileName != null) {
        // New file selected → upload
        docUrl = await widget.assignmentService.uploadDocument(
          fileName: _pickedFileName!,
          bytes: _pickedFileBytes!,
          orgId: widget.orgId,
          courseId: widget.courseId,
        );
        docName = _pickedFileName!;
      } else if (!_removeExistingDoc &&
          (_existingDocUrl?.isNotEmpty ?? false)) {
        // Keep existing file
        docUrl = _existingDocUrl!;
        docName = _existingDocName ?? '';
      }
      // else: doc removed or none

      final now = DateTime.now();
      final assignment = AssignmentModel(
        id: widget.existing?.id ?? '',
        courseId: widget.courseId,
        facultyId: widget.facultyId,
        orgId: widget.orgId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        startDate: DateFormat('yyyy-MM-dd').format(now),
        submitDate: DateFormat('yyyy-MM-dd').format(_dueDate!),
        documentUrl: docUrl,
        documentName: docName,
      );

      if (_isEditMode) {
        await widget.assignmentService.updateAssignment(assignment);
      } else {
        await widget.assignmentService.createAssignment(assignment);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Assignment updated successfully.'
                : 'Assignment posted to all enrolled students.',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save assignment: $e')),
      );
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3EEFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assignment_add,
                          color: Color(0xFF7C3AED), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: smcText(
                        textToDisplay: _isEditMode
                            ? 'Edit Assignment'
                            : 'Create Assignment',
                        textSize: 18,
                        textBoldness: 5,
                        colorOfText: ColorConst.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: ColorConst.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                smcText(
                  textToDisplay: _isEditMode
                      ? 'Update the assignment details below.'
                      : 'Once saved, this will be visible to all enrolled students.',
                  textSize: 13,
                  colorOfText: ColorConst.textSecondary,
                ),
                const SizedBox(height: 24),

                // ── Title ────────────────────────────────────────────────────
                _fieldLabel('Title'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleCtrl,
                  enabled: !_isSaving,
                  decoration: _inputDecoration('Enter assignment title'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),

                // ── Due Date ─────────────────────────────────────────────────
                _fieldLabel('Due Date'),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _isSaving ? null : _pickDueDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _dueDate != null
                            ? ColorConst.primaryBlue
                            : const Color(0xFFDCE2F4),
                        width: _dueDate != null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: _dueDate != null
                              ? ColorConst.primaryBlue
                              : ColorConst.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _dueDate != null
                                ? _fmt(_dueDate!)
                                : 'Select due date',
                            style: TextStyle(
                              fontSize: 14,
                              color: _dueDate != null
                                  ? ColorConst.textPrimary
                                  : ColorConst.textSecondary,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: ColorConst.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ── Description ──────────────────────────────────────────────
                _fieldLabel('Description'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descCtrl,
                  enabled: !_isSaving,
                  maxLines: 5,
                  decoration: _inputDecoration(
                    'Describe the assignment, questions, or instructions...',
                    alignHint: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),

                // ── Document Upload (optional) ───────────────────────────────
                Row(
                  children: [
                    _fieldLabel('Attachment'),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const smcText(
                        textToDisplay: 'Optional',
                        textSize: 11,
                        colorOfText: ColorConst.primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildDocumentPicker(),
                const SizedBox(height: 28),

                // ── Action Buttons ───────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ColorConst.textSecondary,
                        side:
                            const BorderSide(color: Color(0xFFDCE2F4)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(_isEditMode ? 'Update' : 'Post Assignment'),
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

  Widget _buildDocumentPicker() {
    final hasNewFile = _pickedFileBytes != null && _pickedFileName != null;
    final hasExisting =
        !_removeExistingDoc && (_existingDocUrl?.isNotEmpty ?? false);

    if (hasNewFile) {
      return _attachmentChip(
        name: _pickedFileName!,
        onRemove: () => setState(() {
          _pickedFileName = null;
          _pickedFileBytes = null;
        }),
      );
    }

    if (hasExisting) {
      return _attachmentChip(
        name: _existingDocName ?? 'Attached document',
        onRemove: () => setState(() {
          _removeExistingDoc = true;
        }),
        isExisting: true,
        url: _existingDocUrl,
      );
    }

    // No file: show picker
    return GestureDetector(
      onTap: _isSaving ? null : _pickDocument,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFDCE2F4),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.upload_file_outlined,
                size: 20, color: ColorConst.textSecondary),
            const SizedBox(width: 10),
            const Expanded(
              child: smcText(
                textToDisplay: 'Tap to upload a document (PDF, DOCX, PPT…)',
                textSize: 13,
                colorOfText: ColorConst.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentChip({
    required String name,
    required VoidCallback onRemove,
    bool isExisting = false,
    String? url,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorConst.primaryBlue.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined,
              size: 20, color: ColorConst.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: (isExisting && url != null && url.isNotEmpty)
                  ? () async {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    }
                  : null,
              child: smcText(
                textToDisplay: name,
                textSize: 13,
                textBoldness: 4,
                colorOfText: ColorConst.primaryBlue,
                decoration: (isExisting && url != null && url.isNotEmpty)
                    ? TextDecoration.underline
                    : TextDecoration.none,
                maxLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 18, color: ColorConst.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return smcText(
      textToDisplay: text,
      textSize: 13,
      textBoldness: 4,
      colorOfText: ColorConst.textPrimary,
    );
  }

  InputDecoration _inputDecoration(String hint,
      {bool alignHint = false}) {
    return InputDecoration(
      hintText: hint,
      alignLabelWithHint: alignHint,
      hintStyle: const TextStyle(
          fontSize: 13, color: ColorConst.textSecondary),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: const Color(0xFFF8F9FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDCE2F4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDCE2F4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: ColorConst.primaryBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}
