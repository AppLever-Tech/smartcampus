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
  final String? footer;
  final IconData icon;

  const FacultyClassCard({
    super.key,
    required this.title,
    this.courseCode,
    this.dayName,
    this.timing,
    this.batch,
    this.section,
    this.footer,
    this.icon = Icons.menu_book_rounded,
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
      (courseCode?.trim().isNotEmpty ?? false) ||
      (dayName?.trim().isNotEmpty ?? false) ||
      (timing?.trim().isNotEmpty ?? false) ||
      (batch?.trim().isNotEmpty ?? false) ||
      (section?.trim().isNotEmpty ?? false);

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
                smcText(
                  textToDisplay: title,
                  textSize: 15,
                  textBoldness: 5,
                  colorOfText: ColorConst.textPrimary,
                  maxLines: 2,
                ),
                if (_hasDetailLine) ...[
                  const SizedBox(height: 4),
                  _buildDetailLine(),
                ],
                if (footer != null && footer!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  smcText(
                    textToDisplay: footer!,
                    textSize: 12,
                    colorOfText: ColorConst.textSecondary,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailLine() {
    const detailSize = 13.0;
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

    addPart(courseCode, bold: false);
    addPart(dayName, bold: false);
    addPart(timing, bold: true);
    if (batch?.trim().isNotEmpty ?? false) {
      addPart('Batch ${batch!.trim()}', bold: false);
    }
    if (section?.trim().isNotEmpty ?? false) {
      addPart('Sec ${section!.trim()}', bold: false);
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
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
