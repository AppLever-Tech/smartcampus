import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/services/course_firestore_service.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/class_attendance_firestore_service.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/completed_class_record.dart';
import 'package:smartcampus/screens/student/student_class_management/student_class_resolver.dart';
import 'package:smartcampus/widgets/smc_text.dart';
import 'package:smartcampus/screens/student/student_course_registration/student_course_registration_page.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentCoursesPage extends StatefulWidget {
  final StudentModel student;
  final String orgId;

  const StudentCoursesPage({
    super.key,
    required this.student,
    required this.orgId,
  });

  @override
  State<StudentCoursesPage> createState() => _StudentCoursesPageState();
}

class _StudentCoursesPageState extends State<StudentCoursesPage> {
  final CourseFirestoreService _courseService = CourseFirestoreService();
  final ClassAttendanceFirestoreService _attendanceService = ClassAttendanceFirestoreService();

  List<CourseModel> _allCourses = [];
  List<CompletedClassRecord> _classRecords = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Fetch all courses for the student's organization
      final coursesStream = _courseService.getCoursesForOrg(orgId: widget.orgId);
      final courses = await coursesStream.first;
      
      // Fetch completed class records for attendance
      final classesStream = _attendanceService.watchClassesForOrg(orgId: widget.orgId);
      final classes = await classesStream.first;

      if (mounted) {
        setState(() {
          _allCourses = courses;
          _classRecords = classes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<CourseModel> get _enrolledCourses {
    return CourseFirestoreService.filterCoursesForStudent(_allCourses, widget.student);
  }

  String _getAcademicYearForSemester(int semIndex) {
    final batch = widget.student.batch.trim();
    if (batch.contains('-')) {
      final parts = batch.split('-');
      final startYearStr = parts[0];
      final endYearStr = parts[1];
      final startYear = int.tryParse(startYearStr);
      if (startYear != null) {
        if (semIndex <= 2) {
          final nextYearShort = (startYear + 1) % 100;
          final nextYearShortStr = nextYearShort.toString().padLeft(2, '0');
          return '$startYear-$nextYearShortStr';
        } else {
          final nextYear = startYear + 1;
          final endYearShort = int.tryParse(endYearStr);
          final endYearShortStr = endYearShort != null ? endYearStr.padLeft(2, '0') : '${(startYear + 2) % 100}';
          return '$nextYear-$endYearShortStr';
        }
      }
    }
    
    // Fallback if batch is single year
    final year = int.tryParse(batch);
    if (year != null) {
      if (semIndex <= 2) {
        return '$year-${(year + 1) % 100}';
      } else {
        return '${year + 1}-${(year + 2) % 100}';
      }
    }

    // Default fallback
    final now = DateTime.now();
    final curYear = now.year;
    if (semIndex <= 2) {
      return '${curYear - 1}-${curYear % 100}';
    } else {
      return '$curYear-${(curYear + 1) % 100}';
    }
  }

  String _getSemesterCode(int semIndex) {
    switch (semIndex) {
      case 1:
        return 'I';
      case 2:
        return 'II';
      case 3:
        return 'III';
      case 4:
        return 'IV';
      default:
        return 'I';
    }
  }

  void _showRegisteredCoursesDialog(String semester, List<CourseModel> courses) {

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(24),
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        smcText(
                          textToDisplay: 'Registered Courses - Semester $semester',
                          textSize: 18,
                          textBoldness: 4,
                          colorOfText: ColorConst.textPrimary,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: ColorConst.borderSoft),
                    if (courses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: smcText(
                            textToDisplay: 'No courses registered in this semester.',
                            textSize: 14,
                            colorOfText: ColorConst.textSecondary,
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(const Color(0xFFF4F7FF)),
                              dividerThickness: 1,
                              border: const TableBorder(
                                horizontalInside: BorderSide(color: Color(0xFFE3EAF8)),
                                verticalInside: BorderSide(color: Color(0xFFE3EAF8)),
                                top: BorderSide(color: Color(0xFFE3EAF8)),
                                bottom: BorderSide(color: Color(0xFFE3EAF8)),
                                left: BorderSide(color: Color(0xFFE3EAF8)),
                                right: BorderSide(color: Color(0xFFE3EAF8)),
                              ),
                              columns: const [
                                DataColumn(label: smcText(textToDisplay: 'Sl. No', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                                DataColumn(label: smcText(textToDisplay: 'Course Code', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                                DataColumn(label: smcText(textToDisplay: 'Course Title', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                                DataColumn(label: smcText(textToDisplay: 'Course Type', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                                DataColumn(label: smcText(textToDisplay: 'Credits', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                                DataColumn(label: smcText(textToDisplay: 'Syllabus', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                              ],
                              rows: courses.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final course = entry.value;
                                final hasSyllabus = course.syllabusPdfUrl.isNotEmpty;
                                return DataRow(cells: [
                                  DataCell(Center(child: smcText(textToDisplay: '${idx + 1}', textSize: 12))),
                                  DataCell(smcText(textToDisplay: course.courseCode, textSize: 12, textBoldness: 2)),
                                  DataCell(smcText(textToDisplay: course.courseTitle, textSize: 12)),
                                  DataCell(smcText(textToDisplay: course.courseType, textSize: 12)),
                                  DataCell(Center(child: smcText(textToDisplay: course.credits, textSize: 12))),
                                  DataCell(
                                    Center(
                                      child: hasSyllabus
                                          ? IconButton(
                                              icon: const Icon(Icons.download_rounded, color: ColorConst.primaryBlue, size: 20),
                                              tooltip: 'View Syllabus PDF',
                                              onPressed: () async {
                                                final uri = Uri.parse(course.syllabusPdfUrl);
                                                if (await canLaunchUrl(uri)) {
                                                  await launchUrl(uri);
                                                }
                                              },
                                            )
                                          : const smcText(textToDisplay: '—', textSize: 12, colorOfText: ColorConst.textSecondary),
                                    ),
                                  ),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showInternalAssessmentDialog(String semester, List<CourseModel> courses) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 750),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    smcText(
                      textToDisplay: 'Internal Assessment - Semester $semester',
                      textSize: 18,
                      textBoldness: 4,
                      colorOfText: ColorConst.textPrimary,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 24, color: ColorConst.borderSoft),
                if (courses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: smcText(
                        textToDisplay: 'No courses registered in this semester.',
                        textSize: 14,
                        colorOfText: ColorConst.textSecondary,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF4F7FF)),
                          dividerThickness: 1,
                          border: const TableBorder(
                            horizontalInside: BorderSide(color: Color(0xFFE3EAF8)),
                            verticalInside: BorderSide(color: Color(0xFFE3EAF8)),
                            top: BorderSide(color: Color(0xFFE3EAF8)),
                            bottom: BorderSide(color: Color(0xFFE3EAF8)),
                            left: BorderSide(color: Color(0xFFE3EAF8)),
                            right: BorderSide(color: Color(0xFFE3EAF8)),
                          ),
                          columns: const [
                            DataColumn(label: smcText(textToDisplay: 'Sl. No', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                            DataColumn(label: smcText(textToDisplay: 'Course Code', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                            DataColumn(label: smcText(textToDisplay: 'Course Title', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                            DataColumn(label: smcText(textToDisplay: 'Max CIE Marks', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                            DataColumn(label: smcText(textToDisplay: 'Obtained CIE Marks', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                          ],
                          rows: courses.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final course = entry.value;

                            // Only use actual stored grade points - no simulation!
                            final gradePointsStr = widget.student.enrolledCourseMarks[course.id]?['gradePoints'] ?? '';
                            final gp = double.tryParse(gradePointsStr);
                            int? obtained;
                            if (gp != null) {
                              obtained = ((gp / 10.0) * course.cieMarks).round();
                            }

                            final obtainedDisplay = obtained == null ? 'Awaiting Entry' : '$obtained';

                            return DataRow(cells: [
                              DataCell(Center(child: smcText(textToDisplay: '${idx + 1}', textSize: 12))),
                              DataCell(smcText(textToDisplay: course.courseCode, textSize: 12, textBoldness: 2)),
                              DataCell(smcText(textToDisplay: course.courseTitle, textSize: 12)),
                              DataCell(Center(child: smcText(textToDisplay: '${course.cieMarks}', textSize: 12))),
                              DataCell(
                                Center(
                                  child: smcText(
                                    textToDisplay: obtainedDisplay,
                                    textSize: 12,
                                    textBoldness: obtained != null ? 3 : 1,
                                    colorOfText: obtained == null ? ColorConst.textSecondary : ColorConst.textPrimary,
                                  ),
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
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

  void _showAttendanceDialog(String semester, List<CourseModel> courses, List<CompletedClassRecord> classRecords) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        smcText(
                          textToDisplay: 'Attendance Details - Semester $semester',
                          textSize: 18,
                          textBoldness: 4,
                          colorOfText: ColorConst.textPrimary,
                        ),
                        const SizedBox(height: 4),
                        const smcText(
                          textToDisplay: 'Note: Minimum 75% attendance is required for exam eligibility.',
                          textSize: 11,
                          colorOfText: ColorConst.textSecondary,
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 24, color: ColorConst.borderSoft),
                if (courses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: smcText(
                        textToDisplay: 'No courses registered in this semester.',
                        textSize: 14,
                        colorOfText: ColorConst.textSecondary,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF4F7FF)),
                          dividerThickness: 1,
                          border: const TableBorder(
                            horizontalInside: BorderSide(color: Color(0xFFE3EAF8)),
                            verticalInside: BorderSide(color: Color(0xFFE3EAF8)),
                            top: BorderSide(color: Color(0xFFE3EAF8)),
                            bottom: BorderSide(color: Color(0xFFE3EAF8)),
                            left: BorderSide(color: Color(0xFFE3EAF8)),
                            right: BorderSide(color: Color(0xFFE3EAF8)),
                          ),
                          columns: const [
                            DataColumn(label: smcText(textToDisplay: 'Sl. No', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                            DataColumn(label: smcText(textToDisplay: 'Course Code', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                            DataColumn(label: smcText(textToDisplay: 'Course Title', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                            DataColumn(label: smcText(textToDisplay: 'Conducted', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                            DataColumn(label: smcText(textToDisplay: 'Attended', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                            DataColumn(label: smcText(textToDisplay: 'Attendance %', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                            DataColumn(label: smcText(textToDisplay: 'Eligibility Status', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                          ],
                          rows: courses.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final course = entry.value;

                            // Only use real class records - no simulation!
                            final courseRecords = classRecords.where((r) => r.courseId == course.id && r.isCompleted).toList();
                            final conducted = courseRecords.length;
                            final studentKey = StudentClassResolver.studentAttendanceKey(widget.student);
                            final attended = courseRecords.where((r) => r.attendance[studentKey] == true).length;

                            final double percentage = conducted > 0 ? (attended / conducted) * 100 : 0.0;
                            final String percentageStr = conducted > 0 ? '${percentage.toStringAsFixed(1)}%' : '—';

                            String statusText;
                            Color statusColor;
                            if (conducted == 0) {
                              statusText = 'Awaiting Entry';
                              statusColor = ColorConst.textSecondary;
                            } else {
                              final bool isEligible = percentage >= 75.0;
                              statusText = isEligible ? 'Eligible' : 'Shortage';
                              statusColor = isEligible ? Colors.green : Colors.red;
                            }

                            return DataRow(cells: [
                              DataCell(Center(child: smcText(textToDisplay: '${idx + 1}', textSize: 12))),
                              DataCell(smcText(textToDisplay: course.courseCode, textSize: 12, textBoldness: 2)),
                              DataCell(
                                smcText(textToDisplay: course.courseTitle, textSize: 12),
                              ),
                              DataCell(Center(child: smcText(textToDisplay: conducted > 0 ? '$conducted' : '—', textSize: 12))),
                              DataCell(Center(child: smcText(textToDisplay: conducted > 0 ? '$attended' : '—', textSize: 12))),
                              DataCell(Center(child: smcText(textToDisplay: percentageStr, textSize: 12, textBoldness: 3))),
                              DataCell(
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: conducted > 0 ? statusColor.withAlpha((0.1 * 255).round()) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: conducted > 0 ? statusColor.withAlpha((0.5 * 255).round()) : Colors.transparent),
                                    ),
                                    child: smcText(
                                      textToDisplay: statusText,
                                      textSize: 11,
                                      textBoldness: 3,
                                      colorOfText: statusColor,
                                    ),
                                  ),
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
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

  Widget _buildStudentInfoRow(String label, String value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: ColorConst.textPrimary,
            ),
            children: [
              TextSpan(
                text: '$label : ',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ColorConst.textPrimary,
                ),
              ),
              TextSpan(
                text: value.isEmpty ? '—' : value,
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  color: ColorConst.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHyperlink(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: smcText(
          textToDisplay: text,
          textSize: 13,
          textBoldness: 3,
          colorOfText: ColorConst.primaryBlue,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final student = widget.student;
    
    // Resolve Program Name based on department or fallback to MCA
    final String programName = student.deptId.toUpperCase() == 'MCA'
        ? 'Master of Computer Applications'
        : 'Master of Computer Applications (${student.deptId})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const Center(
          child: smcText(
            textToDisplay: 'Student Course Details',
            textSize: 22,
            textBoldness: 4,
            colorOfText: ColorConst.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        // Student Info Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorConst.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStudentInfoRow('Student Reg No', student.studentId),
                  _buildStudentInfoRow('Student Name', student.fullName),
                  _buildStudentInfoRow('Program Name', programName),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStudentInfoRow('Scheme Name', student.batch.isEmpty ? 'UGNEP2021' : student.batch),
                  _buildStudentInfoRow('Current Term/Semester', student.currentSemester),
                  const Spacer(), // Balance layout
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Semester Details Table
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorConst.borderSoft),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(ColorConst.primaryBlue),
                  dividerThickness: 1,
                  dataRowMinHeight: 60,
                  dataRowMaxHeight: 70,
                  border: const TableBorder(
                    horizontalInside: BorderSide(color: Color(0xFFE3EAF8)),
                    verticalInside: BorderSide(color: Color(0xFFE3EAF8)),
                  ),
                  columns: const [
                    DataColumn(
                      label: Expanded(
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Sl. No',
                            textSize: 14,
                            textBoldness: 4,
                            colorOfText: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Expanded(
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Academic Year',
                            textSize: 14,
                            textBoldness: 4,
                            colorOfText: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Expanded(
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Term/Semester',
                            textSize: 14,
                            textBoldness: 4,
                            colorOfText: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Expanded(
                        child: Center(
                          child: smcText(
                            textToDisplay: 'Action',
                            textSize: 14,
                            textBoldness: 4,
                            colorOfText: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                  rows: List.generate(4, (index) {
                    final semIndex = index + 1;
                    final semCode = _getSemesterCode(semIndex);
                    final acadYear = _getAcademicYearForSemester(semIndex);
                    
                    final semesterCourses = _enrolledCourses.where((c) => c.semester == semCode).toList();
                    final isRegistered = semesterCourses.isNotEmpty;

                    return DataRow(
                      cells: [
                        DataCell(Center(child: smcText(textToDisplay: '$semIndex', textSize: 13))),
                        DataCell(Center(child: smcText(textToDisplay: acadYear, textSize: 13))),
                        DataCell(Center(child: smcText(textToDisplay: semCode, textSize: 13))),
                        DataCell(
                          Center(
                            child: isRegistered
                                ? Wrap(
                                    spacing: 8,
                                    children: [
                                      _buildHyperlink('View Registered Courses', () => _showRegisteredCoursesDialog(semCode, semesterCourses)),
                                      _buildHyperlink('View Internal Assessment', () => _showInternalAssessmentDialog(semCode, semesterCourses)),
                                      _buildHyperlink('View Attendance', () => _showAttendanceDialog(semCode, semesterCourses, _classRecords)),
                                    ],
                                  )
                                : _buildHyperlink(
                                    'Course Registration',
                                    () async {
                                      final registered = await Navigator.push<bool>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => StudentCourseRegistrationPage(
                                            student: student,
                                            orgId: widget.orgId,
                                            initialSemester: semCode,
                                          ),
                                        ),
                                      );
                                      if (registered == true) {
                                        _loadData();
                                      }
                                    },
                                  ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
