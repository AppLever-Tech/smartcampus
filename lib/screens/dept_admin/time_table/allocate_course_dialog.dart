import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_block_record.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_day.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_record.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_time_slot.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_block_firestore_service.dart';
import 'package:smartcampus/services/course_firestore_service.dart';
import 'package:smartcampus/services/faculty_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class AllocateCourseDialog {
  static Future<void> show({
    required BuildContext context,
    required TimeTableRecord timeTable,
    required TimeTableDay day,
    required TimeTableTimeSlot timeSlot,
  }) async {
    final courseService = CourseFirestoreService();
    final facultyService = FacultyFirestoreService();
    final timeBlockService = TimeBlockFirestoreService();

    CourseModel? selectedCourse;
    bool saving = false;
    bool loading = true;
    List<CourseModel> courses = const [];
    List<FacultyModel> facultyList = const [];
    String? loadError;

    try {
      final results = await Future.wait([
        courseService.getCoursesForOrg(orgId: timeTable.orgId).first,
        facultyService.listFacultyForOrg(timeTable.orgId),
      ]);
      courses = results[0] as List<CourseModel>;
      facultyList = results[1] as List<FacultyModel>;
      courses.sort((a, b) => a.courseCode.compareTo(b.courseCode));
    } catch (_) {
      loadError = 'Failed to load courses.';
    } finally {
      loading = false;
    }

    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> allocate() async {
              if (selectedCourse == null) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: smcText(
                      textToDisplay: 'Please select a course.',
                      textSize: 14,
                      colorOfText: Colors.white,
                    ),
                  ),
                );
                return;
              }

              setDialogState(() => saving = true);
              try {
                final faculty = _resolveFaculty(
                  course: selectedCourse!,
                  facultyList: facultyList,
                );
                await timeBlockService.replaceTimeBlockForCell(
                  TimeBlockRecord(
                    orgId: timeTable.orgId,
                    timeTableUid: timeTable.timeTableUid,
                    dayName: day.dayName,
                    dayUid: day.dayUid,
                    timeSlotName: timeSlot.timeslotName,
                    timeSlotUid: timeSlot.timeslotUid,
                    batch: timeTable.batch,
                    section: timeTable.section,
                    courseId: selectedCourse!.courseCode,
                    courseName: selectedCourse!.courseTitle,
                    facultyName: faculty.name,
                    facultyUid: faculty.uid,
                  ),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: smcText(
                        textToDisplay: 'Course allocated successfully.',
                        textSize: 14,
                        colorOfText: Colors.white,
                      ),
                    ),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  setDialogState(() => saving = false);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: smcText(
                        textToDisplay: 'Failed to allocate course.',
                        textSize: 14,
                        colorOfText: Colors.white,
                      ),
                    ),
                  );
                }
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const smcText(
                    textToDisplay: 'Allocate Course',
                    textSize: 18,
                    textBoldness: 5,
                  ),
                  const SizedBox(height: 4),
                  smcText(
                    textToDisplay:
                        '${day.dayName} • ${timeSlot.timeslotName}',
                    textSize: 12,
                    colorOfText: ColorConst.textSecondary,
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: loading
                    ? const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : loadError != null
                        ? smcText(
                            textToDisplay: loadError,
                            textSize: 14,
                            colorOfText: ColorConst.textSecondary,
                          )
                        : courses.isEmpty
                            ? const smcText(
                                textToDisplay: 'No courses found for this organisation.',
                                textSize: 14,
                                colorOfText: ColorConst.textSecondary,
                                maxLines: 3,
                              )
                            : SizedBox(
                                height: 320,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF4F7FF),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFE3EAF8),
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: smcText(
                                              textToDisplay: 'Course ID',
                                              textSize: 12,
                                              textBoldness: 5,
                                              colorOfText: Color(0xFF5C6B8B),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: smcText(
                                              textToDisplay: 'Course Title',
                                              textSize: 12,
                                              textBoldness: 5,
                                              colorOfText: Color(0xFF5C6B8B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: ListView.separated(
                                        itemCount: courses.length,
                                        separatorBuilder: (context, index) =>
                                            const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final course = courses[index];
                                          final isSelected =
                                              selectedCourse?.id == course.id;
                                          return RadioListTile<CourseModel>(
                                            value: course,
                                            groupValue: selectedCourse,
                                            onChanged: saving
                                                ? null
                                                : (value) {
                                                    setDialogState(
                                                      () => selectedCourse = value,
                                                    );
                                                  },
                                            title: Row(
                                              children: [
                                                Expanded(
                                                  flex: 2,
                                                  child: smcText(
                                                    textToDisplay:
                                                        course.courseCode,
                                                    textSize: 13,
                                                    textBoldness: 4,
                                                    colorOfText:
                                                        ColorConst.textPrimary,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: smcText(
                                                    textToDisplay:
                                                        course.courseTitle,
                                                    textSize: 13,
                                                    colorOfText:
                                                        ColorConst.textPrimary,
                                                    maxLines: 2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            selected: isSelected,
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving || selectedCourse == null ? null : allocate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorConst.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const smcText(
                          textToDisplay: 'Allocate Course',
                          textSize: 14,
                          textBoldness: 4,
                          colorOfText: Colors.white,
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static ({String name, String uid}) _resolveFaculty({
    required CourseModel course,
    required List<FacultyModel> facultyList,
  }) {
    for (final assignedId in course.assignedFacultyIds) {
      for (final faculty in facultyList) {
        final keys = <String>{
          if (faculty.documentId?.isNotEmpty == true) faculty.documentId!,
          faculty.facultyId,
        };
        if (keys.contains(assignedId)) {
          return (
            name: faculty.fullName,
            uid: faculty.documentId?.isNotEmpty == true
                ? faculty.documentId!
                : faculty.facultyId,
          );
        }
      }
    }

    return (name: course.faculty.trim(), uid: '');
  }
}
