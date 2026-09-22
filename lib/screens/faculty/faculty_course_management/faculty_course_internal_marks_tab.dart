import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/services/student_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class FacultyCourseInternalMarksTab extends StatefulWidget {
  final StudentModel student;
  final CourseModel course;

  const FacultyCourseInternalMarksTab({
    super.key,
    required this.student,
    required this.course,
  });

  @override
  State<FacultyCourseInternalMarksTab> createState() =>
      _FacultyCourseInternalMarksTabState();
}

class _FacultyCourseInternalMarksTabState
    extends State<FacultyCourseInternalMarksTab> {
  final StudentFirestoreService _studentService = StudentFirestoreService();
  final TextEditingController _ia1Controller = TextEditingController();
  final TextEditingController _ia2Controller = TextEditingController();

  bool _isSaving = false;
  String? _saveError;
  String? _saveSuccess;
  static const double _maxAssessmentMarks = 50;

  @override
  void initState() {
    super.initState();
    _loadExistingMarks();
  }

  @override
  void didUpdateWidget(covariant FacultyCourseInternalMarksTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student.documentId != widget.student.documentId) {
      _saveError = null;
      _saveSuccess = null;
      _loadExistingMarks();
    }
  }

  void _loadExistingMarks() {
    final Map<String, String>? marksForCourse =
    widget.student.enrolledCourseMarks[widget.course.id];

    _ia1Controller.text = marksForCourse?['ia1Marks'] ?? '';
    _ia2Controller.text = marksForCourse?['ia2Marks'] ?? '';
  }

  @override
  void dispose() {
    _ia1Controller.dispose();
    _ia2Controller.dispose();
    super.dispose();
  }

  double? _parseMark(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.tryParse(trimmed);
  }

  String _formatMark(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  double? get _computedFinalCie {
    final ia1 = _parseMark(_ia1Controller.text);
    final ia2 = _parseMark(_ia2Controller.text);
    if (ia1 == null || ia2 == null) {
      return null;
    }
    return (ia1 + ia2) / 2;
  }

  Future<void> _saveMarks() async {
    setState(() {
      _isSaving = true;
      _saveError = null;
      _saveSuccess = null;
    });

    try {
      final String ia1MarksStr = _ia1Controller.text.trim();
      final String ia2MarksStr = _ia2Controller.text.trim();
      final double? ia1Marks = _parseMark(ia1MarksStr);
      final double? ia2Marks = _parseMark(ia2MarksStr);

      if (ia1MarksStr.isNotEmpty &&
          (ia1Marks == null ||
              ia1Marks < 0 ||
              ia1Marks > _maxAssessmentMarks)) {
        setState(() {
          _saveError = 'Please enter IA-1 marks between 0 and 50.';
          _isSaving = false;
        });
        return;
      }

      if (ia2MarksStr.isNotEmpty &&
          (ia2Marks == null ||
              ia2Marks < 0 ||
              ia2Marks > _maxAssessmentMarks)) {
        setState(() {
          _saveError = 'Please enter IA-2 marks between 0 and 50.';
          _isSaving = false;
        });
        return;
      }

      final String finalCie =
      (ia1Marks != null && ia2Marks != null)
          ? _formatMark((ia1Marks + ia2Marks) / 2)
          : '';

      final Map<String, Map<String, String>> updatedMarks =
      Map<String, Map<String, String>>.from(widget.student.enrolledCourseMarks);

      final Map<String, String> currentCourseMarks =
      Map<String, String>.from(updatedMarks[widget.course.id] ?? {});

      currentCourseMarks['ia1Marks'] = ia1MarksStr;
      currentCourseMarks['ia2Marks'] = ia2MarksStr;
      currentCourseMarks['finalCie'] = finalCie;
      currentCourseMarks['cieMarks'] = finalCie;
      updatedMarks[widget.course.id] = currentCourseMarks;

      await _studentService.saveEnrolledCourseMarks(
        documentId: widget.student.documentId!,
        marksByCourseId: updatedMarks,
        semesterSgpaBySemester: widget.student.semesterSgpa,
        cgpa: widget.student.cgpa,
      );

      // Mutate local object so it stays updated without full reload (or caller can reload)
      widget.student.enrolledCourseMarks[widget.course.id] = currentCourseMarks;

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveSuccess =
        finalCie.isEmpty
            ? 'IA marks saved. Final CIE will appear once both IA-1 and IA-2 are entered.'
            : 'IA marks and Final CIE saved successfully.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = 'Failed to save marks: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          smcText(
            textToDisplay: 'Internal Assessments',
            textSize: 16,
            textBoldness: 5,
            colorOfText: ColorConst.textPrimary,
          ),
          const SizedBox(height: 8),
          smcText(
            textToDisplay:
            'Enter IA-1 and IA-2 marks out of 50. Final CIE is calculated automatically as the average.',
            textSize: 14,
            colorOfText: ColorConst.textSecondary,
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool compact = constraints.maxWidth < 720;
              final fields = [
                _buildMarkField(
                  label: 'Internal Assessment 1',
                  controller: _ia1Controller,
                  hintText: 'e.g. 42',
                  onChanged: (_) => setState(() {}),
                ),
                _buildMarkField(
                  label: 'Internal Assessment 2',
                  controller: _ia2Controller,
                  hintText: 'e.g. 46',
                  onChanged: (_) => setState(() {}),
                ),
              ];

              if (compact) {
                return Column(
                  children: [
                    fields[0],
                    const SizedBox(height: 16),
                    fields[1],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: 16),
                  Expanded(child: fields[1]),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE3EAF8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                smcText(
                  textToDisplay: 'Calculated Final CIE',
                  textSize: 13,
                  textBoldness: 5,
                  colorOfText: ColorConst.textPrimary,
                ),
                const SizedBox(height: 8),
                smcText(
                  textToDisplay:
                  _computedFinalCie == null
                      ? 'Awaiting both IA-1 and IA-2 marks'
                      : '${_formatMark(_computedFinalCie!)} / 50',
                  textSize: 20,
                  textBoldness: 5,
                  colorOfText:
                  _computedFinalCie == null
                      ? ColorConst.textSecondary
                      : ColorConst.primaryBlue,
                ),
                const SizedBox(height: 6),
                smcText(
                  textToDisplay: 'Formula: (IA-1 + IA-2) / 2',
                  textSize: 12,
                  colorOfText: ColorConst.textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_saveError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: smcText(
                      textToDisplay: _saveError!,
                      textSize: 13,
                      colorOfText: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_saveSuccess != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: smcText(
                      textToDisplay: _saveSuccess!,
                      textSize: 13,
                      colorOfText: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveMarks,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorConst.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text(
                'Save IA Marks',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        smcText(
          textToDisplay: label,
          textSize: 13,
          textBoldness: 5,
          colorOfText: ColorConst.textPrimary,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: hintText,
            suffixText: '/ 50',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE3EAF8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE3EAF8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ColorConst.primaryBlue),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
