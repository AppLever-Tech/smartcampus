import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_time_slot.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class FacultyClassCard extends StatelessWidget {
  final String title;
  final String? courseCode;
  final String? dayName;
  final String? timing;
  final String? batch;
  final String? section;
  final String? semester;
  final IconData icon;
  final String studentsActionLabel;
  final VoidCallback? onStudentsTap;
  final VoidCallback? onNotesTap;
  final VoidCallback? onSyllabusTap;
  final VoidCallback? onMoreTap;

  const FacultyClassCard({
    super.key,
    required this.title,
    this.courseCode,
    this.dayName,
    this.timing,
    this.batch,
    this.section,
    this.semester,
    this.icon = Icons.menu_book_rounded,
    this.studentsActionLabel = 'Students',
    this.onStudentsTap,
    this.onNotesTap,
    this.onSyllabusTap,
    this.onMoreTap,
  });

  static String? resolveTimingLabel({
    required String timeSlotUid,
    required String timeSlotName,
    List<TimeTableTimeSlot> timeSlots = const [],
  }) {
    TimeTableTimeSlot? matchedSlot;
    final uid = timeSlotUid.trim();
    final name = timeSlotName.trim().toLowerCase();

    for (final slot in timeSlots) {
      if (uid.isNotEmpty && slot.timeslotUid.trim() == uid) {
        matchedSlot = slot;
        break;
      }
    }

    if (matchedSlot == null && name.isNotEmpty) {
      for (final slot in timeSlots) {
        if (slot.timeslotName.trim().toLowerCase() == name) {
          matchedSlot = slot;
          break;
        }
      }
    }

    if (matchedSlot != null) {
      final start = matchedSlot.timeslotStartTime.trim();
      final end = matchedSlot.timeslotEndTime.trim();
      if (start.isNotEmpty && end.isNotEmpty) {
        return '$start - $end';
      }
      if (start.isNotEmpty) {
        return start;
      }
    }

    final fallback = timeSlotName.trim();
    return fallback.isEmpty ? null : fallback;
  }

  bool get _hasDetailLine =>
      (dayName?.trim().isNotEmpty ?? false) ||
      (timing?.trim().isNotEmpty ?? false) ||
      (batch?.trim().isNotEmpty ?? false) ||
      (section?.trim().isNotEmpty ?? false) ||
      (semester?.trim().isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EAF8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ColorConst.primaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: ColorConst.primaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitleLine(),
                if (_hasDetailLine) ...[
                  const SizedBox(height: 4),
                  _buildDetailLine(),
                ],
                const SizedBox(height: 4),
                _buildFooterRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleLine() {
    const titleSize = 15.0;
    const titleColor = ColorConst.textPrimary;
    final name = title.trim();
    final code = courseCode?.trim() ?? '';

    if (name.isNotEmpty && code.isNotEmpty) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: name,
              style: GoogleFonts.poppins(
                fontSize: titleSize,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            TextSpan(
              text: ' ($code)',
              style: GoogleFonts.poppins(
                fontSize: titleSize,
                fontWeight: FontWeight.w400,
                color: titleColor,
              ),
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return smcText(
      textToDisplay: name.isNotEmpty ? name : code,
      textSize: titleSize,
      textBoldness: 5,
      colorOfText: titleColor,
      maxLines: 2,
    );
  }

  Widget _buildDetailLine() {
    const detailSize = 12.0;
    const detailColor = ColorConst.textSecondary;
    final normalStyle = GoogleFonts.poppins(
      fontSize: detailSize,
      fontWeight: FontWeight.w400,
      color: detailColor,
    );
    final boldStyle = GoogleFonts.poppins(
      fontSize: detailSize,
      fontWeight: FontWeight.w700,
      color: detailColor,
    );

    final spans = <InlineSpan>[];
    var hasContent = false;

    void addSeparator() {
      if (hasContent) {
        spans.add(TextSpan(text: ' · ', style: normalStyle));
      }
    }

    void addPart(String? value, {required bool bold}) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) {
        return;
      }
      addSeparator();
      spans.add(
        TextSpan(
          text: text,
          style: bold ? boldStyle : normalStyle,
        ),
      );
      hasContent = true;
    }

    addPart(dayName, bold: true);
    addPart(timing, bold: true);
    addPart(batch, bold: false);
    if (semester?.trim().isNotEmpty ?? false) {
      addPart('Sem: ${semester!.trim()}', bold: false);
    }
    addPart(section, bold: false);

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFooterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFooterAction(
            icon: Icons.people_outline_rounded,
            label: studentsActionLabel,
            onTap: onStudentsTap,
          ),
          const SizedBox(width: 6),
          _buildFooterAction(
            icon: Icons.sticky_note_2_outlined,
            label: 'Notes',
            onTap: onNotesTap,
          ),
          const SizedBox(width: 6),
          _buildFooterAction(
            icon: Icons.description_outlined,
            label: 'Syllabus',
            onTap: onSyllabusTap,
          ),
          const SizedBox(width: 6),
          _buildFooterAction(
            icon: Icons.more_horiz_rounded,
            label: 'More',
            onTap: onMoreTap,
          ),
        ],
      ),
    );
  }

  Widget _buildFooterAction({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE3EAF8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: ColorConst.textSecondary,
              ),
              const SizedBox(width: 4),
              smcText(
                textToDisplay: label,
                textSize: 11,
                textBoldness: 4,
                colorOfText: ColorConst.textSecondary,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FacultyClassesEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const FacultyClassesEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.class_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3EAF8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 40,
              color: ColorConst.textSecondary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            smcText(
              textToDisplay: title,
              textSize: 16,
              textBoldness: 4,
              colorOfText: ColorConst.textPrimary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            smcText(
              textToDisplay: message,
              textSize: 14,
              colorOfText: ColorConst.textSecondary,
              maxLines: 3,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
