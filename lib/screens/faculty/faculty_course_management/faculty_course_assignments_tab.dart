import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/models/assignment_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/services/assignment_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays all assignments for a given course and lets the faculty
/// create, edit, and delete them.
class FacultyCourseAssignmentsTab extends StatefulWidget {
  final StudentModel student;
  final CourseModel course;
  final String facultyId;
  final String orgId;

  const FacultyCourseAssignmentsTab({
    super.key,
    required this.student,
    required this.course,
    required this.facultyId,
    required this.orgId,
  });

  @override
  State<FacultyCourseAssignmentsTab> createState() =>
      _FacultyCourseAssignmentsTabState();
}

class _FacultyCourseAssignmentsTabState
    extends State<FacultyCourseAssignmentsTab> {
  final AssignmentFirestoreService _assignmentService =
      AssignmentFirestoreService();

  void _openCreateDialog() => _openDialog(null);
  void _openEditDialog(AssignmentModel a) => _openDialog(a);

  void _openDialog(AssignmentModel? existing) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AssignmentFormDialog(
        courseId: widget.course.id,
        facultyId: widget.facultyId,
        orgId: widget.orgId,
        assignmentService: _assignmentService,
        existing: existing,
      ),
    );
  }

  Future<void> _confirmDelete(AssignmentModel a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const smcText(
          textToDisplay: 'Delete Assignment',
          textSize: 17,
          textBoldness: 5,
          colorOfText: ColorConst.textPrimary,
        ),
        content: smcText(
          textToDisplay:
              'Are you sure you want to delete "${a.title}"? This cannot be undone.',
          textSize: 14,
          colorOfText: ColorConst.textSecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const smcText(
                textToDisplay: 'Cancel',
                textSize: 14,
                colorOfText: ColorConst.textSecondary),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const smcText(
                textToDisplay: 'Delete',
                textSize: 14,
                textBoldness: 4,
                colorOfText: Colors.white),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await _assignmentService.deleteAssignment(a.id,
          documentUrl: a.documentUrl.isNotEmpty ? a.documentUrl : null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignment deleted.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header ───────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const smcText(
                textToDisplay: 'Assignments',
                textSize: 16,
                textBoldness: 5,
                colorOfText: ColorConst.textPrimary,
              ),
              ElevatedButton.icon(
                onPressed: _openCreateDialog,
                icon: const Icon(Icons.add_rounded, size: 18),
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
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE3EAF8)),

        // ── Assignment List ───────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<AssignmentModel>>(
            stream:
                _assignmentService.getAssignmentsForCourse(widget.course.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: smcText(
                    textToDisplay:
                        'Error loading assignments: ${snapshot.error}',
                    textSize: 14,
                    colorOfText: Colors.red,
                  ),
                );
              }
              final assignments = snapshot.data ?? [];
              if (assignments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined,
                          size: 52, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const smcText(
                        textToDisplay: 'No assignments created yet.',
                        textSize: 14,
                        colorOfText: ColorConst.textSecondary,
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: assignments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (_, i) =>
                    _AssignmentCard(
                  assignment: assignments[i],
                  onEdit: () => _openEditDialog(assignments[i]),
                  onDelete: () => _confirmDelete(assignments[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Assignment Card ────────────────────────────────────────────────────────

class _AssignmentCard extends StatelessWidget {
  final AssignmentModel assignment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AssignmentCard({
    required this.assignment,
    required this.onEdit,
    required this.onDelete,
  });

  String _fmt(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  bool get _isOverdue {
    try {
      return DateTime.parse(assignment.submitDate)
          .isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE3EAF8)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row + actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.assignment_outlined,
                    size: 18, color: Color(0xFF7C3AED)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: smcText(
                  textToDisplay: assignment.title,
                  textSize: 15,
                  textBoldness: 5,
                  colorOfText: ColorConst.textPrimary,
                ),
              ),
              // Edit
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.edit_outlined,
                      size: 18, color: ColorConst.primaryBlue),
                ),
              ),
              const SizedBox(width: 4),
              // Delete
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.redAccent),
                ),
              ),
            ],
          ),
          if (assignment.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            smcText(
              textToDisplay: assignment.description,
              textSize: 13,
              colorOfText: ColorConst.textSecondary,
              maxLines: 3,
            ),
          ],
          const SizedBox(height: 12),

          // Due date + document chip
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              // Due date chip
              _chip(
                icon: Icons.calendar_today_rounded,
                label: 'Due: ${_fmt(assignment.submitDate)}',
                color: _isOverdue
                    ? const Color(0xFFFFECEA)
                    : const Color(0xFFF0F4FF),
                textColor: _isOverdue
                    ? const Color(0xFFD93025)
                    : ColorConst.primaryBlue,
                iconColor: _isOverdue
                    ? const Color(0xFFD93025)
                    : ColorConst.primaryBlue,
              ),
              // Document attachment
              if (assignment.documentUrl.isNotEmpty)
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(assignment.documentUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: _chip(
                    icon: Icons.attach_file_rounded,
                    label: assignment.documentName.isNotEmpty
                        ? assignment.documentName
                        : 'Attachment',
                    color: const Color(0xFFF3EEFF),
                    textColor: const Color(0xFF7C3AED),
                    iconColor: const Color(0xFF7C3AED),
                    underline: true,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required Color iconColor,
    bool underline = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 5),
          smcText(
            textToDisplay: label,
            textSize: 12,
            textBoldness: 3,
            colorOfText: textColor,
            decoration: underline ? TextDecoration.underline : null,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Assignment Form Dialog (create + edit)
// ═══════════════════════════════════════════════════════════════════════════

class _AssignmentFormDialog extends StatefulWidget {
  final String courseId;
  final String facultyId;
  final String orgId;
  final AssignmentFirestoreService assignmentService;
  final AssignmentModel? existing;

  const _AssignmentFormDialog({
    required this.courseId,
    required this.facultyId,
    required this.orgId,
    required this.assignmentService,
    this.existing,
  });

  @override
  State<_AssignmentFormDialog> createState() => _AssignmentFormDialogState();
}

class _AssignmentFormDialogState extends State<_AssignmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  DateTime? _dueDate;
  bool _isSaving = false;

  String? _pickedFileName;
  Uint8List? _pickedFileBytes;
  String? _existingDocUrl;
  String? _existingDocName;
  bool _removeExistingDoc = false;

  bool get _isEdit => widget.existing != null;

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
              primary: ColorConst.primaryBlue),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'ppt', 'pptx', 'jpg', 'png'
      ],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final f = result.files.first;
      setState(() {
        _pickedFileName = f.name;
        _pickedFileBytes = f.bytes;
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

      if (_pickedFileBytes != null && _pickedFileName != null) {
        docUrl = await widget.assignmentService.uploadDocument(
          fileName: _pickedFileName!,
          bytes: _pickedFileBytes!,
          orgId: widget.orgId,
          courseId: widget.courseId,
        );
        docName = _pickedFileName!;
      } else if (!_removeExistingDoc &&
          (_existingDocUrl?.isNotEmpty ?? false)) {
        docUrl = _existingDocUrl!;
        docName = _existingDocName ?? '';
      }

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

      if (_isEdit) {
        await widget.assignmentService.updateAssignment(assignment);
      } else {
        await widget.assignmentService.createAssignment(assignment);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit
              ? 'Assignment updated.'
              : 'Assignment posted to all enrolled students.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final hasNewFile = _pickedFileBytes != null;
    final hasExisting =
        !_removeExistingDoc && (_existingDocUrl?.isNotEmpty ?? false);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
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
                        textToDisplay:
                            _isEdit ? 'Edit Assignment' : 'Create Assignment',
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
                const SizedBox(height: 6),
                smcText(
                  textToDisplay: _isEdit
                      ? 'Update the assignment details below.'
                      : 'Once saved, this will be visible to all enrolled students.',
                  textSize: 13,
                  colorOfText: ColorConst.textSecondary,
                ),
                const SizedBox(height: 24),

                // Title
                _label('Title'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleCtrl,
                  enabled: !_isSaving,
                  decoration: _dec('Enter assignment title'),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 18),

                // Due Date
                _label('Due Date'),
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
                        Icon(Icons.calendar_today_outlined,
                            size: 18,
                            color: _dueDate != null
                                ? ColorConst.primaryBlue
                                : ColorConst.textSecondary),
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

                // Description
                _label('Description'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descCtrl,
                  enabled: !_isSaving,
                  maxLines: 5,
                  decoration: _dec(
                    'Describe the assignment, questions, or instructions...',
                    alignHint: true,
                  ),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 18),

                // Document (optional)
                Row(
                  children: [
                    _label('Attachment'),
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
                if (hasNewFile)
                  _fileChip(
                    name: _pickedFileName!,
                    onRemove: () => setState(() {
                      _pickedFileName = null;
                      _pickedFileBytes = null;
                    }),
                  )
                else if (hasExisting)
                  _fileChip(
                    name: _existingDocName ?? 'Attached document',
                    isExisting: true,
                    url: _existingDocUrl,
                    onRemove: () =>
                        setState(() => _removeExistingDoc = true),
                  )
                else
                  GestureDetector(
                    onTap: _isSaving ? null : _pickDocument,
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
                                  'Tap to upload (PDF, DOCX, PPT…)',
                              textSize: 13,
                              colorOfText: ColorConst.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 28),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ColorConst.textSecondary,
                        side: const BorderSide(color: Color(0xFFDCE2F4)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
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
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(_isEdit ? 'Update' : 'Post Assignment'),
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

  Widget _fileChip({
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
        border: Border.all(color: ColorConst.primaryBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined,
              size: 18, color: ColorConst.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: (isExisting && (url?.isNotEmpty ?? false))
                  ? () async {
                      final uri = Uri.parse(url!);
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
                decoration: (isExisting && (url?.isNotEmpty ?? false))
                    ? TextDecoration.underline
                    : null,
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

  Widget _label(String text) => smcText(
        textToDisplay: text,
        textSize: 13,
        textBoldness: 4,
        colorOfText: ColorConst.textPrimary,
      );

  InputDecoration _dec(String hint, {bool alignHint = false}) {
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
