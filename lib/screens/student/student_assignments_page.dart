import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/models/assessment_model.dart';
import 'package:smartcampus/models/assignment_model.dart';
import 'package:smartcampus/models/assignment_submission_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/services/assessment_firestore_service.dart';
import 'package:smartcampus/services/assignment_firestore_service.dart';
import 'package:smartcampus/services/assignment_submission_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays assignments + assessments for the courses the student is enrolled in.
class StudentAssignmentsPage extends StatefulWidget {
  final StudentModel student;
  final List<CourseModel> enrolledCourses;
  final List<String> studentSections;

  const StudentAssignmentsPage({
    super.key,
    required this.student,
    required this.enrolledCourses,
    this.studentSections = const ['A', 'B', 'C'],
  });

  @override
  State<StudentAssignmentsPage> createState() => _StudentAssignmentsPageState();
}

class _StudentAssignmentsPageState extends State<StudentAssignmentsPage> {
  final AssignmentFirestoreService _assignmentSvc = AssignmentFirestoreService();
  final AssessmentFirestoreService _assessmentSvc = AssessmentFirestoreService();
  final AssignmentSubmissionFirestoreService _submissionSvc = AssignmentSubmissionFirestoreService();

  late final List<StreamSubscription<List<AssignmentModel>>> _assignmentSubs;
  final Map<String, List<AssignmentModel>> _assignmentsByCourseid = {};

  StreamSubscription<List<AssessmentModel>>? _assessmentSub;
  List<AssessmentModel> _assessments = [];

  bool _loading = true;

  // Filter: 0 = All, 1 = Pending, 2 = Overdue
  int _filter = 0;

  // Track submissions for assignments
  final Map<String, AssignmentSubmissionModel?> _assignmentSubmissions = {};
  
  // Track submissions for assessments
  final Map<String, AssessmentSubmissionModel?> _assessmentSubmissions = {};

  @override
  void initState() {
    super.initState();
    _assignmentSubs = [];
    for (final course in widget.enrolledCourses) {
      final sub = _assignmentSvc
          .getAssignmentsForCourse(course.id)
          .listen((list) {
        if (!mounted) return;
        setState(() {
          _assignmentsByCourseid[course.id] = list;
          _loading = false;
        });
        // Load submissions for new assignments
        for (final assignment in list) {
          _loadSubmissionForAssignment(assignment.id);
        }
      }, onError: (_) {
        if (!mounted) return;
        setState(() => _loading = false);
      });
      _assignmentSubs.add(sub);
    }

    _assessmentSub = _assessmentSvc
        .getAssessmentsForStudent(
      studentId: widget.student.studentId,
      sections: widget.studentSections,
      batch: widget.student.batch,
      semester: widget.student.currentSemester,
      enrolledCourseIds: widget.enrolledCourses.map((c) => c.id).toList(),
    )
        .listen((list) {
      if (!mounted) return;
      setState(() {
        _assessments = list;
        _loading = false;
      });
      // Load submissions for new assessments
      for (final assessment in list) {
        _loadSubmissionForAssessment(assessment.id ?? '');
      }
    }, onError: (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    });

    if (widget.enrolledCourses.isEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _loading = false);
      });
    }
  }

  Future<void> _loadSubmissionForAssignment(String assignmentId) async {
    final submission = await _submissionSvc.getSubmissionByAssignmentAndStudent(
      assignmentId: assignmentId,
      studentId: widget.student.studentId,
    );
    if (mounted) {
      setState(() {
        _assignmentSubmissions[assignmentId] = submission;
      });
    }
  }

  Future<void> _loadSubmissionForAssessment(String assessmentId) async {
    final submission = await _assessmentSvc.getAssessmentSubmissionByAssessmentAndStudent(
      assessmentId: assessmentId,
      studentId: widget.student.studentId,
    );
    if (mounted) {
      setState(() {
        _assessmentSubmissions[assessmentId] = submission;
      });
    }
  }

  Future<void> _showSubmitDialog(BuildContext context, _WorkItem item) async {
    if (item.assignment == null) return;

    String? _pickedFileName;
    Uint8List? _pickedFileBytes;
    bool _isUploading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const smcText(
            textToDisplay: 'Submit Assignment',
            textSize: 17,
            textBoldness: 5,
            colorOfText: ColorConst.textPrimary,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              smcText(
                textToDisplay: item.title,
                textSize: 14,
                textBoldness: 4,
                colorOfText: ColorConst.textPrimary,
              ),
              const SizedBox(height: 16),
              if (_pickedFileBytes != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ColorConst.primaryBlue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined,
                          size: 18, color: ColorConst.primaryBlue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: smcText(
                          textToDisplay: _pickedFileName!,
                          textSize: 13,
                          textBoldness: 4,
                          colorOfText: ColorConst.primaryBlue,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setDialogState(() {
                          _pickedFileName = null;
                          _pickedFileBytes = null;
                        }),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: ColorConst.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: _isUploading
                      ? null
                      : () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                            withData: true,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            final f = result.files.first;
                            setDialogState(() {
                              _pickedFileName = f.name;
                              _pickedFileBytes = f.bytes;
                            });
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDCE2F4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.upload_file_outlined,
                            size: 20, color: ColorConst.textSecondary),
                        SizedBox(width: 10),
                        Expanded(
                          child: smcText(
                            textToDisplay:
                                'Tap to upload (PDF, JPG, PNG)',
                            textSize: 13,
                            colorOfText: ColorConst.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isUploading
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const smcText(
                textToDisplay: 'Cancel',
                textSize: 14,
                colorOfText: ColorConst.textSecondary,
              ),
            ),
            ElevatedButton(
              onPressed: _isUploading || _pickedFileBytes == null
                  ? null
                  : () async {
                      setDialogState(() => _isUploading = true);
                      try {
                        final fileUrl = await _submissionSvc.uploadSubmissionFile(
                          fileName: _pickedFileName!,
                          bytes: _pickedFileBytes!,
                          orgId: widget.student.orgId,
                          assignmentId: item.assignment!.id,
                          studentId: widget.student.studentId,
                        );

                        final submission = AssignmentSubmissionModel(
                          id: '${item.assignment!.id}_${widget.student.studentId}_${DateTime.now().millisecondsSinceEpoch}',
                          assignmentId: item.assignment!.id,
                          studentId: widget.student.studentId,
                          studentName: widget.student.fullName,
                          submittedAt: DateTime.now().toIso8601String(),
                          fileUrl: fileUrl,
                          fileName: _pickedFileName!,
                          fileType: _pickedFileName!.split('.').last.toLowerCase(),
                        );

                        await _submissionSvc.createSubmission(submission);

                        if (!mounted) return;
                        setState(() {
                          _assignmentSubmissions[item.assignment!.id] = submission;
                        });

                        if (!mounted) return;
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Assignment submitted successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        setDialogState(() => _isUploading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to submit: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorConst.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const smcText(
                      textToDisplay: 'Submit',
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

  Future<void> _showAssessmentSubmitDialog(BuildContext context, _WorkItem item) async {
    if (item.assessment == null) return;

    String? _pickedFileName;
    Uint8List? _pickedFileBytes;
    bool _isUploading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const smcText(
            textToDisplay: 'Submit Assessment',
            textSize: 17,
            textBoldness: 5,
            colorOfText: ColorConst.textPrimary,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              smcText(
                textToDisplay: item.title,
                textSize: 14,
                textBoldness: 4,
                colorOfText: ColorConst.textPrimary,
              ),
              const SizedBox(height: 8),
              smcText(
                textToDisplay: '${item.assessmentType} • ${item.totalMarks.toStringAsFixed(item.totalMarks % 1 == 0 ? 0 : 1)} marks',
                textSize: 12,
                colorOfText: ColorConst.textSecondary,
              ),
              const SizedBox(height: 16),
              if (_pickedFileBytes != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ColorConst.primaryBlue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined,
                          size: 18, color: ColorConst.primaryBlue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: smcText(
                          textToDisplay: _pickedFileName!,
                          textSize: 13,
                          textBoldness: 4,
                          colorOfText: ColorConst.primaryBlue,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setDialogState(() {
                          _pickedFileName = null;
                          _pickedFileBytes = null;
                        }),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: ColorConst.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: _isUploading
                      ? null
                      : () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                            withData: true,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            final f = result.files.first;
                            setDialogState(() {
                              _pickedFileName = f.name;
                              _pickedFileBytes = f.bytes;
                            });
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDCE2F4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.upload_file_outlined,
                            size: 20, color: ColorConst.textSecondary),
                        SizedBox(width: 10),
                        Expanded(
                          child: smcText(
                            textToDisplay:
                                'Tap to upload (PDF, JPG, PNG)',
                            textSize: 13,
                            colorOfText: ColorConst.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isUploading
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const smcText(
                textToDisplay: 'Cancel',
                textSize: 14,
                colorOfText: ColorConst.textSecondary,
              ),
            ),
            ElevatedButton(
              onPressed: _isUploading || _pickedFileBytes == null
                  ? null
                  : () async {
                      setDialogState(() => _isUploading = true);
                      try {
                        final fileUrl = await _assessmentSvc.uploadAssessmentSubmissionFile(
                          fileName: _pickedFileName!,
                          bytes: _pickedFileBytes!,
                          orgId: widget.student.orgId,
                          assessmentId: item.assessment!.id ?? '',
                          studentId: widget.student.studentId,
                        );

                        final submission = AssessmentSubmissionModel(
                          id: '${item.assessment!.id}_${widget.student.studentId}_${DateTime.now().millisecondsSinceEpoch}',
                          assessmentId: item.assessment!.id ?? '',
                          studentId: widget.student.studentId,
                          studentName: widget.student.fullName,
                          submittedAt: DateTime.now().toIso8601String(),
                          fileUrl: fileUrl,
                          fileName: _pickedFileName!,
                          fileType: _pickedFileName!.split('.').last.toLowerCase(),
                        );

                        await _assessmentSvc.createAssessmentSubmission(submission);

                        if (!mounted) return;
                        setState(() {
                          _assessmentSubmissions[item.assessment!.id ?? ''] = submission;
                        });

                        if (!mounted) return;
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Assessment submitted successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        setDialogState(() => _isUploading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to submit: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorConst.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const smcText(
                      textToDisplay: 'Submit',
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

  @override
  void dispose() {
    for (final s in _assignmentSubs) {
      s.cancel();
    }
    _assessmentSub?.cancel();
    super.dispose();
  }

  List<_WorkItem> get _allItems {
    final out = <_WorkItem>[];
    for (final course in widget.enrolledCourses) {
      for (final a in _assignmentsByCourseid[course.id] ?? const []) {
      out.add(_WorkItem(
        kind: _WorkKind.assignment,
        assignment: a,
        course: course,
        title: a.title,
        description: a.description,
        courseName: '${course.courseCode} - ${course.courseTitle}',
        dueDateIso: a.submitDate,
        attachmentUrl: a.documentUrl,
        attachmentName: a.documentName,
        submission: _assignmentSubmissions[a.id],
      ));
    }
    }
    for (final assessment in _assessments) {
      // Check if student is enrolled in the course
      final isEnrolledInCourse = widget.enrolledCourses.any((c) => c.id == assessment.courseId);
      if (!isEnrolledInCourse) {
        continue; // Skip assessments for courses the student isn't enrolled in
      }
      
      final course = widget.enrolledCourses
          .where((c) => c.id == assessment.courseId)
          .firstOrNull;
      out.add(_WorkItem(
        kind: _WorkKind.assessment,
        assessment: assessment,
        course: course,
        title: assessment.title,
        description: assessment.description ?? '',
        courseName: assessment.courseName.isNotEmpty
            ? assessment.courseName
            : (course != null
                ? '${course.courseCode} - ${course.courseTitle}'
                : (assessment.scheme.isNotEmpty && assessment.semester.isNotEmpty
                    ? '${assessment.scheme} - ${assessment.semester}'
                    : (assessment.section.isNotEmpty
                        ? 'Section ${assessment.section}'
                        : 'Assessment'))),
        dueDateIso: assessment.dueDate.toIso8601String(),
        assessmentType: assessment.assessmentType,
        totalMarks: assessment.totalMarks,
        showMarks: assessment.showMarksToStudents,
        marksEntry: assessment.marksEntries.where((m) =>
            m.studentId == widget.student.studentId ||
            m.studentId == (widget.student.documentId ?? '')).firstOrNull,
        allowLateSubmission: assessment.allowLateSubmission,
        assessmentSubmission: _assessmentSubmissions[assessment.id ?? ''],
        assessmentAttachmentUrls: assessment.attachmentUrls,
        assessmentAttachmentNames: assessment.attachmentNames,
      ));
    }
    out.sort((a, b) => a._due.compareTo(b._due));
    return out;
  }

  List<_WorkItem> get _filteredItems {
    final now = DateTime.now();
    final all = _allItems;
    switch (_filter) {
      case 1:
        return all.where((e) => e._due.isAfter(now)).toList();
      case 2:
        return all.where((e) => e._due.isBefore(now)).toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageHeader(),
        const SizedBox(height: 20),
        _buildFilterRow(),
        const SizedBox(height: 20),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildPageHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF3EEFF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.assignment_outlined,
              color: Color(0xFF7C3AED), size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const smcText(
              textToDisplay: 'My Assignments & Assessments',
              textSize: 18,
              textBoldness: 5,
              colorOfText: ColorConst.textPrimary,
            ),
            smcText(
              textToDisplay:
                  '${widget.enrolledCourses.length} enrolled course(s)',
              textSize: 12,
              colorOfText: ColorConst.textSecondary,
            ),
          ],
        ),
        const Spacer(),
        if (!_loading)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: smcText(
              textToDisplay: '${_allItems.length} total',
              textSize: 12,
              textBoldness: 3,
              colorOfText: ColorConst.primaryBlue,
            ),
          ),
      ],
    );
  }

  Widget _buildFilterRow() {
    final filters = ['All', 'Pending', 'Overdue'];
    return Row(
      children: List.generate(filters.length, (i) {
        final isSelected = _filter == i;
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () => setState(() => _filter = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: isSelected
                    ? (i == 2
                        ? const Color(0xFFFFECEA)
                        : const Color(0xFFEAF0FF))
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? (i == 2
                          ? const Color(0xFFD93025)
                          : ColorConst.primaryBlue)
                      : const Color(0xFFE3EAF8),
                ),
              ),
              child: smcText(
                textToDisplay: filters[i],
                textSize: 13,
                textBoldness: isSelected ? 4 : 3,
                colorOfText: isSelected
                    ? (i == 2
                        ? const Color(0xFFD93025)
                        : ColorConst.primaryBlue)
                    : ColorConst.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.enrolledCourses.isEmpty && _assessments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.menu_book_outlined,
        message: 'You are not enrolled in any courses yet.',
      );
    }

    final items = _filteredItems;
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assignment_outlined,
        message: _filter == 0
            ? 'No assignments or assessments posted yet.'
            : _filter == 1
                ? 'No pending items.'
                : 'No overdue items.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length,
      separatorBuilder: (_, _i) => const SizedBox(height: 14),
      itemBuilder: (_, i) => _StudentWorkCard(
        item: items[i],
        onSubmit: () {
          if (items[i].kind == _WorkKind.assignment) {
            _showSubmitDialog(context, items[i]);
          } else {
            _showAssessmentSubmitDialog(context, items[i]);
          }
        },
      ),
    );
  }

  Widget _buildEmptyState(
      {required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          smcText(
            textToDisplay: message,
            textSize: 14,
            colorOfText: ColorConst.textSecondary,
          ),
        ],
      ),
    );
  }
}

// ── Unified item ─────────────────────────────────────────────────────────

enum _WorkKind { assignment, assessment }

class _WorkItem {
  final _WorkKind kind;
  final AssignmentModel? assignment;
  final AssessmentModel? assessment;
  final CourseModel? course;
  final String title;
  final String description;
  final String courseName;
  final String dueDateIso;
  final String attachmentUrl;
  final String attachmentName;
  final String assessmentType;
  final double totalMarks;
  final bool showMarks;
  final AssessmentMarkEntry? marksEntry;
  final bool allowLateSubmission;
  final AssignmentSubmissionModel? submission;
  final AssessmentSubmissionModel? assessmentSubmission;
  final List<String> assessmentAttachmentUrls;
  final List<String> assessmentAttachmentNames;

  _WorkItem({
    required this.kind,
    this.assignment,
    this.assessment,
    this.course,
    required this.title,
    required this.description,
    required this.courseName,
    required this.dueDateIso,
    this.attachmentUrl = '',
    this.attachmentName = '',
    this.assessmentType = '',
    this.totalMarks = 0,
    this.showMarks = false,
    this.marksEntry,
    this.allowLateSubmission = false,
    this.submission,
    this.assessmentSubmission,
    this.assessmentAttachmentUrls = const [],
    this.assessmentAttachmentNames = const [],
  });

  DateTime get _due {
    try {
      return DateTime.parse(dueDateIso);
    } catch (_) {
      return DateTime.now();
    }
  }
}

// ── Unified card ─────────────────────────────────────────────────────────

class _StudentWorkCard extends StatelessWidget {
  final _WorkItem item;
  final VoidCallback onSubmit;
  const _StudentWorkCard({required this.item, required this.onSubmit});

  bool get _isOverdue => item._due.isBefore(DateTime.now());

  int get _daysRemaining => item._due.difference(DateTime.now()).inDays;

  String _fmt(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
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
        return _fmt(iso);
      }
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAssessment = item.kind == _WorkKind.assessment;

    final dueBadgeColor =
        _isOverdue ? const Color(0xFFFFECEA) : const Color(0xFFE8F5E9);
    final dueBadgeText = _isOverdue
        ? const Color(0xFFD93025)
        : const Color(0xFF2E7D32);
    final dueLabel = _isOverdue
        ? 'Overdue'
        : _daysRemaining == 0
            ? 'Due today'
            : 'Due in $_daysRemaining day(s)';

    final courseBadgeBg = isAssessment
        ? const Color(0xFFEAF0FF)
        : const Color(0xFFF3EEFF);
    final courseBadgeFg = isAssessment
        ? ColorConst.primaryBlue
        : const Color(0xFF7C3AED);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isOverdue
              ? const Color(0xFFFDECEE)
              : const Color(0xFFE3EAF8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top badge row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: courseBadgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: smcText(
                  textToDisplay: item.courseName,
                  textSize: 11,
                  textBoldness: 3,
                  colorOfText: courseBadgeFg,
                  maxLines: 1,
                ),
              ),
              if (isAssessment && item.assessmentType.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: smcText(
                    textToDisplay: '📝 ${item.assessmentType}',
                    textSize: 11,
                    textBoldness: 3,
                    colorOfText: const Color(0xFFB26A00),
                    maxLines: 1,
                  ),
                ),
              if (!isAssessment)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8E9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: smcText(
                    textToDisplay: '📎 Assignment',
                    textSize: 11,
                    textBoldness: 3,
                    colorOfText: const Color(0xFF2E7D32),
                    maxLines: 1,
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: dueBadgeColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: smcText(
                  textToDisplay: dueLabel,
                  textSize: 11,
                  textBoldness: 3,
                  colorOfText: dueBadgeText,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          smcText(
            textToDisplay: item.title,
            textSize: 15,
            textBoldness: 5,
            colorOfText: ColorConst.textPrimary,
          ),

          // Description
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            smcText(
              textToDisplay: item.description,
              textSize: 13,
              colorOfText: ColorConst.textSecondary,
              maxLines: 4,
            ),
          ],

          // Assessment: Marks row (if visible)
          if (isAssessment && item.showMarks && item.marksEntry != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE3EAF8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.grade_outlined,
                      size: 18, color: ColorConst.primaryBlue),
                  const SizedBox(width: 8),
                  smcText(
                    textToDisplay: 'Marks: ',
                    textSize: 13,
                    colorOfText: ColorConst.textSecondary,
                  ),
                  smcText(
                    textToDisplay: item.marksEntry!.marksObtained == null
                        ? 'Not published yet'
                        : '${item.marksEntry!.marksObtained}/${item.totalMarks.toStringAsFixed(item.totalMarks % 1 == 0 ? 0 : 1)}',
                    textSize: 13,
                    textBoldness: 5,
                    colorOfText: ColorConst.primaryBlue,
                  ),
                  if (item.marksEntry?.remarks?.isNotEmpty == true) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: smcText(
                        textToDisplay:
                            '· ${item.marksEntry!.remarks!}',
                        textSize: 12,
                        colorOfText: ColorConst.textSecondary,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF0F4FF)),
          const SizedBox(height: 12),

          // Meta row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _meta(Icons.calendar_today_outlined,
                  'Due: ${_fmt(item.dueDateIso)}'),
              if (isAssessment)
                _meta(Icons.confirmation_num_outlined,
                    'Max: ${item.totalMarks.toStringAsFixed(item.totalMarks % 1 == 0 ? 0 : 1)} marks'),
              if (isAssessment && item.allowLateSubmission)
                _meta(Icons.history_outlined, 'Late submission allowed'),
              if (item.attachmentUrl.isNotEmpty)
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(item.attachmentUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EEFF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.download_rounded,
                            size: 14, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 6),
                        smcText(
                          textToDisplay: item.attachmentName.isNotEmpty
                              ? item.attachmentName
                              : 'Download Attachment',
                          textSize: 12,
                          textBoldness: 3,
                          colorOfText: Color(0xFF7C3AED),
                          decoration: TextDecoration.underline,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              if (isAssessment && item.assessmentAttachmentUrls.isNotEmpty)
                _meta(Icons.attach_file,
                    '${item.assessmentAttachmentUrls.length} attachment${item.assessmentAttachmentUrls.length > 1 ? 's' : ''}'),
            ],
          ),

          // Assessment attachments display
          if (isAssessment && item.assessmentAttachmentUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE3EAF8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  smcText(
                    textToDisplay: 'Faculty Attachments',
                    textSize: 12,
                    textBoldness: 4,
                    colorOfText: ColorConst.textSecondary,
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(item.assessmentAttachmentUrls.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () async {
                          final uri = Uri.parse(item.assessmentAttachmentUrls[index]);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file,
                                size: 14, color: ColorConst.primaryBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: smcText(
                                textToDisplay: index < item.assessmentAttachmentNames.length
                                    ? item.assessmentAttachmentNames[index]
                                    : 'Attachment ${index + 1}',
                                textSize: 12,
                                colorOfText: ColorConst.primaryBlue,
                                decoration: TextDecoration.underline,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // Assignment submission section
          if (!isAssessment) ...[
            const SizedBox(height: 12),
            if (item.submission != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC8E6C9)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 18, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          smcText(
                            textToDisplay: 'Submitted',
                            textSize: 13,
                            textBoldness: 4,
                            colorOfText: Color(0xFF2E7D32),
                          ),
                          if (item.submission!.fileName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            smcText(
                              textToDisplay: item.submission!.fileName,
                              textSize: 11,
                              colorOfText: const Color(0xFF2E7D32),
                              maxLines: 1,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (item.submission!.fileUrl.isNotEmpty)
                      GestureDetector(
                        onTap: () async {
                          final uri = Uri.parse(item.submission!.fileUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.visibility_rounded,
                                  size: 14, color: Color(0xFF2E7D32)),
                              const SizedBox(width: 4),
                              smcText(
                                textToDisplay: 'View',
                                textSize: 11,
                                textBoldness: 3,
                                colorOfText: Color(0xFF2E7D32),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: onSubmit,
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('Submit Assignment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorConst.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],

          // Assessment submission section
          if (isAssessment) ...[
            const SizedBox(height: 12),
            if (item.assessmentSubmission != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC8E6C9)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 18, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          smcText(
                            textToDisplay: 'Submitted',
                            textSize: 13,
                            textBoldness: 4,
                            colorOfText: Color(0xFF2E7D32),
                          ),
                          if (item.assessmentSubmission!.fileName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            smcText(
                              textToDisplay: item.assessmentSubmission!.fileName,
                              textSize: 11,
                              colorOfText: Color(0xFF2E7D32),
                              maxLines: 1,
                            ),
                          ],
                          const SizedBox(height: 2),
                          smcText(
                            textToDisplay: _formatSubmissionDate(item.assessmentSubmission!.submittedAt),
                            textSize: 10,
                            colorOfText: Color(0xFF2E7D32),
                          ),
                        ],
                      ),
                    ),
                    if (item.assessmentSubmission!.fileUrl.isNotEmpty)
                      GestureDetector(
                        onTap: () async {
                          final uri = Uri.parse(item.assessmentSubmission!.fileUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.visibility_rounded,
                                  size: 14, color: Color(0xFF2E7D32)),
                              const SizedBox(width: 4),
                              smcText(
                                textToDisplay: 'View',
                                textSize: 11,
                                textBoldness: 3,
                                colorOfText: Color(0xFF2E7D32),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: onSubmit,
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('Submit Assessment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorConst.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: ColorConst.textSecondary),
        const SizedBox(width: 5),
        smcText(
          textToDisplay: label,
          textSize: 12,
          colorOfText: ColorConst.textSecondary,
          maxLines: 1,
        ),
      ],
    );
  }
}
