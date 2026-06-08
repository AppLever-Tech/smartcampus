import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/screens/dept_admin/time_table/allocate_course_dialog.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_block_record.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_day.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_record.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_time_slot.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_block_firestore_service.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_delete_confirm_dialog.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_settings_firestore_service.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_settings_list_actions.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class TimeTableDetailPage extends StatefulWidget {
  final TimeTableRecord timeTable;

  const TimeTableDetailPage({
    super.key,
    required this.timeTable,
  });

  @override
  State<TimeTableDetailPage> createState() => _TimeTableDetailPageState();
}

class _TimeTableDetailPageState extends State<TimeTableDetailPage> {
  bool isTransposed = false;
  bool isEditEnabled = false;

  static const Color _borderColor = Color(0xFFE3EAF8);
  static const Color _headerColor = Color(0xFFF4F7FF);
  static const double _dayColumnWidth = 120;
  static const double _timeBlockColumnWidth = 108 * 1.3;
  static const double _rowHeight = 88;
  static const Color _breakCellColor = Color(0xFFE8ECF2);
  static const Set<String> _breakCourseLabels = {
    'TEA BREAK',
    'LUNCH BREAK',
  };

  String get _title =>
      widget.timeTable.displayLabel;

  void _toggleTranspose() {
    setState(() => isTransposed = !isTransposed);
  }

  void _openAllocateCourse({
    required TimeTableDay day,
    required TimeTableTimeSlot timeSlot,
  }) {
    AllocateCourseDialog.show(
      context: context,
      timeTable: widget.timeTable,
      day: day,
      timeSlot: timeSlot,
    );
  }

  void _toggleEdit() {
    setState(() => isEditEnabled = !isEditEnabled);
  }

  Future<void> _confirmDeleteAllocation(TimeBlockRecord block) async {
    final confirmed = await TimeTableDeleteConfirmDialog.show(
      context: context,
      title: 'Delete Course Allocation',
      message:
          'Are you sure you want to remove "${block.courseId}" from ${block.dayName} • ${block.timeSlotName}?',
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      await TimeBlockFirestoreService().deleteTimeBlock(block.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: smcText(
              textToDisplay: 'Course allocation deleted.',
              textSize: 14,
              colorOfText: Colors.white,
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: smcText(
              textToDisplay: 'Failed to delete course allocation.',
              textSize: 14,
              colorOfText: Colors.white,
            ),
          ),
        );
      }
    }
  }

  Widget _buildToolbarButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: ColorConst.primaryBlue),
      label: smcText(
        textToDisplay: label,
        textSize: 13,
        textBoldness: 4,
        colorOfText: ColorConst.primaryBlue,
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: _borderColor),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        _buildToolbarButton(
          onPressed: _toggleTranspose,
          icon: Icons.swap_horiz_rounded,
          label: 'Transpose',
        ),
        const SizedBox(width: 8),
        _buildToolbarButton(
          onPressed: _toggleEdit,
          icon: isEditEnabled ? Icons.edit_off_outlined : Icons.edit_outlined,
          label: isEditEnabled ? 'Disable Edit' : 'Enable Edit',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = TimeTableSettingsFirestoreService();
    final timeBlockService = TimeBlockFirestoreService();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: ColorConst.primaryBlue,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const smcText(
              textToDisplay: 'Time Table',
              textSize: 16,
              textBoldness: 5,
              colorOfText: Colors.white,
            ),
            smcText(
              textToDisplay: _title,
              textSize: 12,
              colorOfText: Colors.white.withValues(alpha: 0.85),
              maxLines: 2,
            ),
          ],
        ),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: settingsService.watchSettings(orgId: widget.timeTable.orgId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final days = settingsService.parseDays(snapshot.data);
          final timeSlots = settingsService.parseTimeSlots(snapshot.data);

          if (days.isEmpty || timeSlots.isEmpty) {
            return Center(
              child: smcText(
                textToDisplay: days.isEmpty
                    ? 'Configure days in Time Table Settings to view the schedule.'
                    : 'Configure time slots in Time Table Settings to view the schedule.',
                textSize: 14,
                colorOfText: ColorConst.textSecondary,
                maxLines: 3,
              ),
            );
          }

          return StreamBuilder<List<TimeBlockRecord>>(
            stream: timeBlockService.watchTimeBlocks(
              orgId: widget.timeTable.orgId,
              timeTableUid: widget.timeTable.timeTableUid,
            ),
            builder: (context, blockSnapshot) {
              final blockMap = TimeBlockFirestoreService.mapBlocksByCell(
                blockSnapshot.data ?? const [],
              );

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildToolbar(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _borderColor),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: _buildTimeTableGrid(
                                days: days,
                                timeSlots: timeSlots,
                                blockMap: blockMap,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTimeTableGrid({
    required List<TimeTableDay> days,
    required List<TimeTableTimeSlot> timeSlots,
    required Map<String, TimeBlockRecord> blockMap,
  }) {
    if (isTransposed) {
      return _buildTransposedGrid(
        days: days,
        timeSlots: timeSlots,
        blockMap: blockMap,
      );
    }
    return _buildDefaultGrid(
      days: days,
      timeSlots: timeSlots,
      blockMap: blockMap,
    );
  }

  Widget _buildDefaultGrid({
    required List<TimeTableDay> days,
    required List<TimeTableTimeSlot> timeSlots,
    required Map<String, TimeBlockRecord> blockMap,
  }) {
    return Table(
      border: _tableBorder,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        0: const FixedColumnWidth(_dayColumnWidth),
        for (int index = 0; index < timeSlots.length; index++)
          index + 1: const FixedColumnWidth(_timeBlockColumnWidth),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: _headerColor),
          children: [
            _headerCell('Day'),
            ...timeSlots.map((slot) => _timeSlotHeaderCell(slot)),
          ],
        ),
        ...days.map(
          (day) => TableRow(
            children: [
              _dayCell(day),
              ...timeSlots.map(
                (slot) => _scheduleTableCell(
                  day: day,
                  timeSlot: slot,
                  block: blockMap['${day.dayUid}|${slot.timeslotUid}'],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransposedGrid({
    required List<TimeTableDay> days,
    required List<TimeTableTimeSlot> timeSlots,
    required Map<String, TimeBlockRecord> blockMap,
  }) {
    return Table(
      border: _tableBorder,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        0: const IntrinsicColumnWidth(),
        for (int index = 0; index < days.length; index++)
          index + 1: const FixedColumnWidth(_timeBlockColumnWidth),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: _headerColor),
          children: [
            _headerCell('Time Slot', shrinkWrap: true),
            ...days.map((day) => _headerCell(day.dayName)),
          ],
        ),
        ...timeSlots.map(
          (slot) => TableRow(
            children: [
              _timeSlotRowCell(slot),
              ...days.map(
                (day) => _scheduleTableCell(
                  day: day,
                  timeSlot: slot,
                  block: blockMap['${day.dayUid}|${slot.timeslotUid}'],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  TableBorder get _tableBorder {
    return const TableBorder(
      top: BorderSide(color: _borderColor),
      bottom: BorderSide(color: _borderColor),
      left: BorderSide(color: _borderColor),
      right: BorderSide(color: _borderColor),
      horizontalInside: BorderSide(color: _borderColor),
      verticalInside: BorderSide(color: _borderColor),
    );
  }

  Widget _headerCell(String label, {bool shrinkWrap = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Center(
        child: smcText(
          textToDisplay: label,
          textSize: 12,
          textBoldness: 5,
          colorOfText: const Color(0xFF5C6B8B),
          textAlign: TextAlign.center,
          maxLines: shrinkWrap ? 3 : 2,
        ),
      ),
    );
  }

  Widget _timeSlotHeaderCell(TimeTableTimeSlot slot) {
    return SizedBox(
      width: _timeBlockColumnWidth,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            smcText(
              textToDisplay: slot.timeslotName,
              textSize: 11,
              textBoldness: 5,
              colorOfText: const Color(0xFF5C6B8B),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            const SizedBox(height: 2),
            smcText(
              textToDisplay:
                  '${slot.timeslotStartTime} - ${slot.timeslotEndTime}',
              textSize: 9,
              colorOfText: ColorConst.textSecondary,
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeSlotRowCell(TimeTableTimeSlot slot) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          smcText(
            textToDisplay: slot.timeslotName,
            textSize: 13,
            textBoldness: 5,
            colorOfText: ColorConst.textPrimary,
          ),
          const SizedBox(height: 4),
          smcText(
            textToDisplay:
                '${slot.timeslotStartTime} - ${slot.timeslotEndTime}',
            textSize: 11,
            colorOfText: ColorConst.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _dayCell(TimeTableDay day) {
    return SizedBox(
      height: _rowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: smcText(
            textToDisplay: day.dayName,
            textSize: 13,
            textBoldness: 5,
            colorOfText: ColorConst.textPrimary,
            maxLines: 2,
          ),
        ),
      ),
    );
  }

  Widget _scheduleTableCell({
    required TimeTableDay day,
    required TimeTableTimeSlot timeSlot,
    TimeBlockRecord? block,
  }) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: _scheduleCell(
        day: day,
        timeSlot: timeSlot,
        block: block,
      ),
    );
  }

  String _facultyDisplayLabel(TimeBlockRecord block) {
    final facultyName = block.facultyName.trim();
    return facultyName.isEmpty ? 'Unassigned' : facultyName;
  }

  bool _isBreakAllocation(TimeBlockRecord? block) {
    if (block == null) {
      return false;
    }

    for (final value in [block.courseName, block.courseId]) {
      final normalized = value.trim().toUpperCase();
      if (_breakCourseLabels.contains(normalized)) {
        return true;
      }
    }
    return false;
  }

  Widget _scheduleCell({
    required TimeTableDay day,
    required TimeTableTimeSlot timeSlot,
    TimeBlockRecord? block,
  }) {
    final bool hasAllocation =
        block != null &&
        (block.courseId.isNotEmpty || block.courseName.isNotEmpty);
    final bool isBreakCell = _isBreakAllocation(block);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellHeight = constraints.maxHeight.isFinite &&
                constraints.maxHeight >= _rowHeight
            ? constraints.maxHeight
            : _rowHeight;

        final double bottomInset = isEditEnabled ? 30 : 6;

        return SizedBox(
          width: _timeBlockColumnWidth,
          height: cellHeight,
          child: ColoredBox(
            color: isBreakCell ? _breakCellColor : const Color(0xFFFCFDFF),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(6, 6, 6, bottomInset),
                    child: Center(
                      child: hasAllocation
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                smcText(
                                  textToDisplay: block.courseName,
                                  textSize: 11,
                                  textBoldness: 5,
                                  colorOfText: ColorConst.textPrimary,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                ),
                                if (block.courseId.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  smcText(
                                    textToDisplay: block.courseId,
                                    textSize: 10,
                                    colorOfText: ColorConst.primaryBlue,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                  ),
                                ],
                                if (!isBreakCell) ...[
                                  const SizedBox(height: 2),
                                  smcText(
                                    textToDisplay: _facultyDisplayLabel(block),
                                    textSize: 9,
                                    textBoldness:
                                        block.facultyName.trim().isEmpty
                                            ? 3
                                            : 5,
                                    colorOfText:
                                        block.facultyName.trim().isEmpty
                                            ? ColorConst.textSecondary
                                            : ColorConst.textPrimary,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                  ),
                                ],
                              ],
                            )
                          : isEditEnabled
                              ? const SizedBox.shrink()
                              : smcText(
                                  textToDisplay: '-',
                                  textSize: 12,
                                  colorOfText: ColorConst.textSecondary,
                                ),
                    ),
                  ),
                ),
                if (isEditEnabled)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Center(
                      child: hasAllocation
                          ? TimeTableSettingsListActions(
                              onEdit: () => _openAllocateCourse(
                                day: day,
                                timeSlot: timeSlot,
                              ),
                              onDelete: () => _confirmDeleteAllocation(block),
                            )
                          : IconButton(
                              onPressed: () => _openAllocateCourse(
                                day: day,
                                timeSlot: timeSlot,
                              ),
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: ColorConst.primaryBlue,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              tooltip: 'Allocate course',
                            ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
