import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_record.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_detail_page.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_card.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_resolver.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/faculty_assigned_class.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class FacultyTimetableTab extends StatefulWidget {
  final List<FacultyAssignedClass> assignedClasses;
  final FacultyModel faculty;
  final List<CourseModel> assignedCourses;

  const FacultyTimetableTab({
    super.key,
    required this.assignedClasses,
    required this.faculty,
    required this.assignedCourses,
  });

  @override
  State<FacultyTimetableTab> createState() => _FacultyTimetableTabState();
}

class _FacultyTimetableTabState extends State<FacultyTimetableTab> {
  TimeTableRecord? _selectedTimeTable;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedTimeTable;
    if (selected != null) {
      return TimeTableDetailPage(
        key: ValueKey<String>(selected.timeTableUid),
        timeTable: selected,
        readOnly: true,
        embedded: true,
        facultyView: true,
        facultyKeys: FacultyClassResolver.facultyKeysFor(widget.faculty),
        facultyCourseKeys:
            FacultyClassResolver.assignedCourseKeys(widget.assignedCourses),
        onBack: () => setState(() => _selectedTimeTable = null),
      );
    }

    final timetables = _timetablesWithAssignments(widget.assignedClasses);

    if (timetables.isEmpty) {
      return const FacultyClassesEmptyState(
        title: 'No timetables found',
        message:
            'Time tables with at least one class assigned to you will appear here.',
        icon: Icons.calendar_month_outlined,
      );
    }

    return ListView.separated(
      itemCount: timetables.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final timeTable = timetables[index];
        final classCount = widget.assignedClasses
            .where(
              (assignedClass) =>
                  assignedClass.timeTable.timeTableUid ==
                  timeTable.timeTableUid,
            )
            .length;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _selectedTimeTable = timeTable),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE3EAF8)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ColorConst.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_month_outlined,
                      color: ColorConst.primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        smcText(
                          textToDisplay: timeTable.displayLabel,
                          textSize: 15,
                          textBoldness: 5,
                          colorOfText: ColorConst.textPrimary,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 4),
                        smcText(
                          textToDisplay:
                              '$classCount class${classCount == 1 ? '' : 'es'} assigned',
                          textSize: 12,
                          colorOfText: ColorConst.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: ColorConst.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static List<TimeTableRecord> _timetablesWithAssignments(
    List<FacultyAssignedClass> assignedClasses,
  ) {
    final byUid = <String, TimeTableRecord>{};
    for (final assignedClass in assignedClasses) {
      final uid = assignedClass.timeTable.timeTableUid.trim();
      if (uid.isEmpty) {
        continue;
      }
      byUid[uid] = assignedClass.timeTable;
    }

    final timetables = byUid.values.toList()
      ..sort((a, b) {
        final semesterCompare = a.semester.compareTo(b.semester);
        if (semesterCompare != 0) {
          return semesterCompare;
        }
        final batchCompare = a.batch.compareTo(b.batch);
        if (batchCompare != 0) {
          return batchCompare;
        }
        return a.section.compareTo(b.section);
      });
    return timetables;
  }
}
