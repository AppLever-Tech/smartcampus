import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/services/settings_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class CourseListTable extends StatefulWidget {
  final List<CourseModel> courses;
  final List<CourseModel> totalsCourses;
  final int startIndex;
  final String? selectedCourseId;
  final ValueChanged<CourseModel>? onCourseTap;
  final ValueChanged<CourseModel>? onEditCourse;
  final ValueChanged<CourseModel>? onDeleteCourse;
  final bool showTotalsRow;
  final List<SettingsItem> courseTypes;
  final ScrollController? horizontalScrollController;
  final ScrollController? verticalScrollController;

  const CourseListTable({
    super.key,
    required this.courses,
    required this.totalsCourses,
    this.startIndex = 0,
    this.selectedCourseId,
    this.onCourseTap,
    this.onEditCourse,
    this.onDeleteCourse,
    this.showTotalsRow = true,
    this.courseTypes = const [],
    this.horizontalScrollController,
    this.verticalScrollController,
  });

  @override
  State<CourseListTable> createState() => _CourseListTableState();
}

class _CourseListTableState extends State<CourseListTable> {
  ScrollController? _ownedHorizontalController;
  ScrollController? _ownedVerticalController;

  ScrollController get _horizontalController =>
      widget.horizontalScrollController ??
      (_ownedHorizontalController ??= ScrollController());

  ScrollController get _verticalController =>
      widget.verticalScrollController ??
      (_ownedVerticalController ??= ScrollController());

  String _courseTypeLabel(String courseTypeName) {
    for (final courseType in widget.courseTypes) {
      if (courseType.name == courseTypeName) {
        final code = courseType.code?.trim() ?? '';
        if (code.isNotEmpty) {
          return '$code - ${courseType.name}';
        }
        return courseType.name;
      }
    }
    return courseTypeName;
  }

  bool get _showActions =>
      widget.onEditCourse != null || widget.onDeleteCourse != null;

  @override
  void dispose() {
    _ownedHorizontalController?.dispose();
    _ownedVerticalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double tableWidth = constraints.maxWidth;
        const List<double> baseMinColumnWidths = [
          52,
          76,
          76,
          180,
          128,
          220,
          68,
          72,
          72,
          72,
          72,
          88,
          128,
          112,
          108,
          92,
        ];
        final List<double> minColumnWidths = [
          ...baseMinColumnWidths,
          if (_showActions) 88,
        ];
        final double minTableWidth =
            minColumnWidths.fold(0.0, (a, b) => a + b);
        final double contentWidth =
            tableWidth < minTableWidth ? minTableWidth : tableWidth;
        final List<double> colWidths = List<double>.from(minColumnWidths);
        if (contentWidth > minTableWidth) {
          colWidths[5] += contentWidth - minTableWidth;
        }

        int totalCreditsSum = 0;
        int totalLectureHrs = 0;
        int totalTutorialHrs = 0;
        int totalPracticalHrs = 0;
        int totalOthersHrs = 0;
        int totalCieMarks = 0;
        int totalSeeTheoryMarks = 0;
        int totalSeeLabMarks = 0;
        int totalMarksSum = 0;
        for (final CourseModel course in widget.totalsCourses) {
          final String creditsRaw = course.credits.trim();
          if (creditsRaw.isNotEmpty) {
            totalCreditsSum += int.tryParse(creditsRaw) ??
                double.tryParse(creditsRaw)?.round() ??
                0;
          }
          totalLectureHrs += course.lectureHrs;
          totalTutorialHrs += course.tutorialHrs;
          totalPracticalHrs += course.practicalHrs;
          totalOthersHrs += course.othersHrs;
          totalCieMarks += course.cieMarks;
          totalSeeTheoryMarks += course.seeTheoryMarks;
          totalSeeLabMarks += course.seeLabMarks;
          totalMarksSum += course.totalMarks;
        }

        Widget buildCourseTableContent() {
          const Color borderColor = Color(0xFFE3EAF8);
          const Color headerColor = Color(0xFFF4F7FF);
          const double groupHeaderHeight = 30;
          const double columnHeaderHeight = 44;
          const double dataRowHeight = 52;

          final Map<int, TableColumnWidth> columnWidthsMap = {
            for (int i = 0; i < colWidths.length; i++)
              i: FixedColumnWidth(colWidths[i]),
          };

          String cellText(String value) =>
              value.trim().isEmpty ? '—' : value.trim();

          Widget headerLabel(
            String text, {
            Alignment alignment = Alignment.center,
            int maxLines = 2,
          }) {
            return Container(
              height: columnHeaderHeight,
              alignment: alignment,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: smcText(
                textToDisplay: text,
                textSize: 12,
                textBoldness: 4,
                colorOfText: const Color(0xFF5C6B8B),
                maxLines: maxLines,
              ),
            );
          }

          Widget dataCell(
            Widget child, {
            Alignment alignment = Alignment.center,
            Color? backgroundColor,
            VoidCallback? onTap,
          }) {
            return GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: dataRowHeight,
                alignment: alignment,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                color: backgroundColor ?? Colors.white,
                child: child,
              ),
            );
          }

          Widget numericDataCell(
            int value, {
            bool boldWhenNonZero = false,
            Color? backgroundColor,
            VoidCallback? onTap,
          }) {
            return dataCell(
              smcText(
                textToDisplay: '$value',
                textSize: 12,
                textBoldness: boldWhenNonZero && value != 0 ? 5 : 1,
                colorOfText: const Color(0xFF2E3954),
                maxLines: 1,
              ),
              backgroundColor: backgroundColor,
              onTap: onTap,
            );
          }

          Widget textDataCell(
            String value, {
            bool boldWhenNonEmpty = false,
            Color? backgroundColor,
            VoidCallback? onTap,
          }) {
            final String display = cellText(value);
            final bool emphasize = boldWhenNonEmpty &&
                value.trim().isNotEmpty &&
                display != '—';
            return dataCell(
              smcText(
                textToDisplay: display,
                textSize: 12,
                textBoldness: emphasize ? 5 : 1,
                colorOfText: const Color(0xFF2E3954),
                maxLines: 2,
              ),
              backgroundColor: backgroundColor,
              onTap: onTap,
            );
          }

          Widget totalRowCell(
            Widget child, {
            Alignment alignment = Alignment.center,
          }) {
            return Container(
              height: dataRowHeight,
              alignment: alignment,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              color: headerColor,
              child: child,
            );
          }

          Widget totalRowNumericCell(int value) {
            return totalRowCell(
              smcText(
                textToDisplay: '$value',
                textSize: 12,
                textBoldness: 5,
                colorOfText: const Color(0xFF2E3954),
                maxLines: 1,
              ),
            );
          }

          Widget actionsDataCell({
            required CourseModel course,
            Color? backgroundColor,
          }) {
            return dataCell(
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onEditCourse != null)
                    IconButton(
                      onPressed: () => widget.onEditCourse!(course),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: ColorConst.primaryBlue,
                      ),
                      tooltip: 'Edit',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  if (widget.onDeleteCourse != null)
                    IconButton(
                      onPressed: () => widget.onDeleteCourse!(course),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red,
                      ),
                      tooltip: 'Delete',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                ],
              ),
              backgroundColor: backgroundColor,
            );
          }

          const BorderSide headerBorderSide = BorderSide(
            color: borderColor,
            width: 1,
          );

          final double prefixColumnsWidth =
              colWidths.sublist(0, 7).fold(0.0, (a, b) => a + b);
          final double teachingHoursWidth =
              colWidths.sublist(7, 11).fold(0.0, (a, b) => a + b);
          final double examSchemeWidth =
              colWidths.sublist(11, 15).fold(0.0, (a, b) => a + b);

          Widget buildGroupHeaderRow() {
            return Row(
              children: [
                Container(
                  width: prefixColumnsWidth,
                  height: groupHeaderHeight,
                  decoration: const BoxDecoration(
                    color: headerColor,
                    border: Border(
                      top: headerBorderSide,
                      left: headerBorderSide,
                      bottom: headerBorderSide,
                    ),
                  ),
                ),
                Container(
                  width: teachingHoursWidth,
                  height: groupHeaderHeight,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: headerColor,
                    border: Border(
                      top: headerBorderSide,
                      left: headerBorderSide,
                      right: headerBorderSide,
                      bottom: headerBorderSide,
                    ),
                  ),
                  child: const smcText(
                    textToDisplay: 'Teaching Hours / Week',
                    textSize: 12,
                    textBoldness: 4,
                    colorOfText: Color(0xFF5C6B8B),
                    maxLines: 1,
                  ),
                ),
                Container(
                  width: examSchemeWidth,
                  height: groupHeaderHeight,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: headerColor,
                    border: Border(
                      top: headerBorderSide,
                      right: headerBorderSide,
                      bottom: headerBorderSide,
                    ),
                  ),
                  child: const smcText(
                    textToDisplay: 'Exam Scheme',
                    textSize: 12,
                    textBoldness: 4,
                    colorOfText: Color(0xFF5C6B8B),
                    maxLines: 1,
                  ),
                ),
                Container(
                  width: colWidths[15],
                  height: groupHeaderHeight,
                  decoration: const BoxDecoration(
                    color: headerColor,
                    border: Border(
                      top: headerBorderSide,
                      right: headerBorderSide,
                      bottom: headerBorderSide,
                    ),
                  ),
                ),
                if (_showActions)
                  Container(
                    width: colWidths[16],
                    height: groupHeaderHeight,
                    decoration: const BoxDecoration(
                      color: headerColor,
                      border: Border(
                        top: headerBorderSide,
                        right: headerBorderSide,
                        bottom: headerBorderSide,
                      ),
                    ),
                  ),
              ],
            );
          }

          final List<Widget> headerCells = [
            headerLabel('S.No'),
            headerLabel('Scheme'),
            headerLabel('Semester'),
            headerLabel('Course Type'),
            headerLabel('Course Code', alignment: Alignment.centerLeft),
            headerLabel('Course Title', alignment: Alignment.centerLeft),
            headerLabel('Credits'),
            headerLabel('Lecture'),
            headerLabel('Tutorial'),
            headerLabel('Practical'),
            headerLabel('Others'),
            headerLabel('CIE Marks', maxLines: 2),
            headerLabel('SEE Exam Duration', maxLines: 2),
            headerLabel('SEE Theory Marks', maxLines: 2),
            headerLabel('SEE Lab Marks', maxLines: 2),
            headerLabel('Total Marks', maxLines: 2),
          ];
          if (_showActions) {
            headerCells.add(headerLabel('Actions'));
          }

          final List<TableRow> tableRows = [
            TableRow(
              decoration: const BoxDecoration(color: headerColor),
              children: headerCells,
            ),
            ...widget.courses.asMap().entries.map((entry) {
              final int index = entry.key;
              final CourseModel course = entry.value;
              final int serialNo = widget.startIndex + index + 1;
              final bool isSelected =
                  widget.selectedCourseId != null &&
                      widget.selectedCourseId == course.id;
              final Color rowColor =
                  isSelected ? const Color(0xFFE8F0FE) : Colors.white;
              void handleTap() => widget.onCourseTap?.call(course);

              final rowCells = <Widget>[
                dataCell(
                  smcText(
                    textToDisplay: '$serialNo',
                    textSize: 12,
                    colorOfText: const Color(0xFF2E3954),
                  ),
                  backgroundColor: rowColor,
                  onTap: widget.onCourseTap == null ? null : handleTap,
                ),
                dataCell(
                  smcText(
                    textToDisplay: cellText(course.batch),
                    textSize: 12,
                    colorOfText: const Color(0xFF2E3954),
                    maxLines: 1,
                  ),
                  backgroundColor: rowColor,
                  onTap: widget.onCourseTap == null ? null : handleTap,
                ),
                dataCell(
                  smcText(
                    textToDisplay: cellText(course.semester),
                    textSize: 12,
                    colorOfText: const Color(0xFF2E3954),
                    maxLines: 1,
                  ),
                  backgroundColor: rowColor,
                  onTap: widget.onCourseTap == null ? null : handleTap,
                ),
                dataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF4FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: smcText(
                      textToDisplay: cellText(
                        _courseTypeLabel(course.courseType),
                      ),
                      textSize: 11,
                      textBoldness: 3,
                      colorOfText: const Color(0xFF3558DA),
                      maxLines: 2,
                    ),
                  ),
                  backgroundColor: rowColor,
                  onTap: widget.onCourseTap == null ? null : handleTap,
                ),
                dataCell(
                  smcText(
                    textToDisplay: cellText(course.courseCode),
                    textSize: 12,
                    textBoldness: 4,
                    colorOfText: const Color(0xFF2E3954),
                    maxLines: 1,
                  ),
                  alignment: Alignment.centerLeft,
                  backgroundColor: rowColor,
                  onTap: widget.onCourseTap == null ? null : handleTap,
                ),
                dataCell(
                  smcText(
                    textToDisplay: cellText(course.courseTitle),
                    textSize: 12,
                    colorOfText: const Color(0xFF2E3954),
                    maxLines: 2,
                  ),
                  alignment: Alignment.centerLeft,
                  backgroundColor: rowColor,
                  onTap: widget.onCourseTap == null ? null : handleTap,
                ),
                dataCell(
                  smcText(
                    textToDisplay: cellText(course.credits),
                    textSize: 12,
                    colorOfText: const Color(0xFF2E3954),
                    maxLines: 1,
                  ),
                  backgroundColor: rowColor,
                  onTap: widget.onCourseTap == null ? null : handleTap,
                ),
                numericDataCell(
                  course.lectureHrs,
                  boldWhenNonZero: true,
                  backgroundColor: rowColor,
                  onTap: widget.onCourseTap == null ? null : handleTap,
                ),
                numericDataCell(
                  course.tutorialHrs,
                  boldWhenNonZero: true,
                  backgroundColor: rowColor,
                  onTap: widget.onCourseTap == null ? null : handleTap,
                ),
                numericDataCell(
                  course.practicalHrs,
                  boldWhenNonZero: true,
                  backgroundColor: rowColor,
                  onTap: widget.onCourseTap == null ? null : handleTap,
                ),
                numericDataCell(
                  course.othersHrs,
                  boldWhenNonZero: true,
                  backgroundColor: rowColor,
                  onTap: widget.onCourseTap == null ? null : handleTap,
                ),
                numericDataCell(
                  course.cieMarks,
                  boldWhenNonZero: true,
                  backgroundColor: rowColor,
                  onTap: widget.onCourseTap == null ? null : handleTap,
                ),
                textDataCell(
                  course.seeExamDuration,
                  boldWhenNonEmpty: true,
                  backgroundColor: rowColor,
                  onTap: widget.onCourseTap == null ? null : handleTap,
                ),
                numericDataCell(
                  course.seeTheoryMarks,
                  boldWhenNonZero: true,
                  backgroundColor: rowColor,
                  onTap: widget.onCourseTap == null ? null : handleTap,
                ),
                numericDataCell(
                  course.seeLabMarks,
                  boldWhenNonZero: true,
                  backgroundColor: rowColor,
                  onTap: widget.onCourseTap == null ? null : handleTap,
                ),
                numericDataCell(
                  course.totalMarks,
                  boldWhenNonZero: true,
                  backgroundColor: rowColor,
                  onTap: widget.onCourseTap == null ? null : handleTap,
                ),
              ];
              if (_showActions) {
                rowCells.add(
                  actionsDataCell(
                    course: course,
                    backgroundColor: rowColor,
                  ),
                );
              }

              return TableRow(children: rowCells);
            }),
            if (widget.showTotalsRow && widget.totalsCourses.isNotEmpty)
              TableRow(
                children: [
                  totalRowCell(const SizedBox.shrink()),
                  totalRowCell(const SizedBox.shrink()),
                  totalRowCell(const SizedBox.shrink()),
                  totalRowCell(const SizedBox.shrink()),
                  totalRowCell(const SizedBox.shrink()),
                  totalRowCell(
                    const Align(
                      alignment: Alignment.centerRight,
                      child: smcText(
                        textToDisplay: 'Total',
                        textSize: 12,
                        textBoldness: 5,
                        colorOfText: Color(0xFF2E3954),
                      ),
                    ),
                    alignment: Alignment.centerRight,
                  ),
                  totalRowNumericCell(totalCreditsSum),
                  totalRowNumericCell(totalLectureHrs),
                  totalRowNumericCell(totalTutorialHrs),
                  totalRowNumericCell(totalPracticalHrs),
                  totalRowNumericCell(totalOthersHrs),
                  totalRowNumericCell(totalCieMarks),
                  totalRowCell(const SizedBox.shrink()),
                  totalRowNumericCell(totalSeeTheoryMarks),
                  totalRowNumericCell(totalSeeLabMarks),
                  totalRowNumericCell(totalMarksSum),
                  if (_showActions) totalRowCell(const SizedBox.shrink()),
                ],
              ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildGroupHeaderRow(),
              Table(
                columnWidths: columnWidthsMap,
                border: TableBorder.all(color: borderColor, width: 1),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: tableRows,
              ),
            ],
          );
        }

        return ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
          ),
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            interactive: true,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: SizedBox(
                width: contentWidth,
                child: Scrollbar(
                  controller: _verticalController,
                  thumbVisibility: true,
                  interactive: true,
                  child: SingleChildScrollView(
                    controller: _verticalController,
                    physics: const ClampingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    child: buildCourseTableContent(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
