import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/mock_master_data.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/screens/landing_page.dart';
import 'package:smartcampus/screens/person_detail_page.dart';
import 'package:smartcampus/services/faculty_firestore_service.dart';
import 'package:smartcampus/services/student_firestore_service.dart';
import 'package:smartcampus/services/org_role_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';
import '../models/course_model.dart';
import '../services/course_firestore_service.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'package:smartcampus/widgets/student_import_dialog.dart';
class DeptAdminDashboardPage extends StatefulWidget {
  final String orgId;
  final String deptId;
  final String adminName;
  const DeptAdminDashboardPage({
    super.key,
    required this.orgId,
    this.deptId = '',
    required this.adminName,

  });

  @override
  State<DeptAdminDashboardPage> createState() => DeptAdminDashboardPageState();
}

class DeptAdminDashboardPageState extends State<DeptAdminDashboardPage> {
  final OrgRoleFirestoreService roleService = OrgRoleFirestoreService();
  final FacultyFirestoreService facultyService = FacultyFirestoreService();
  final StudentFirestoreService studentService = StudentFirestoreService();
  final CourseFirestoreService
  courseService =
  CourseFirestoreService();

  bool loading = true;
  int selectedMenuIndex = 0; // 0: Dashboard, 1: Students, 2: Faculties
  List<OrgUserRoleMappingItem> facultyAndStudents = [];
  List<DepartmentMasterItem> departments = [];
  List<FacultyModel> facultyList = [];
  List<StudentModel> studentList = [];
  List<CourseModel> courseList = [];
  bool coursesLoaded = false;
  int totalCourses = 0;
  String organizationDisplayName = '';
  bool canEditOrDelete = false;

  Stream<QuerySnapshot> getCoursesStream() {

    return FirebaseFirestore.instance
        .collection('courses')
        .snapshots();
  }
  // Search and Pagination for Students
  final TextEditingController studentSearchController = TextEditingController();
  int studentRowsPerPage = 100;
  int studentCurrentPage = 1;
  String studentBatchFilter = 'All Batches';
  String studentGenderFilter = 'All Gender';

  // Search and Pagination for Faculty
  final TextEditingController facultySearchController = TextEditingController();
  int facultyRowsPerPage = 10;
  int facultyCurrentPage = 1;
  String facultyGenderFilter = 'All';

  // Search and Pagination for Courses
  final TextEditingController courseSearchController = TextEditingController();
  int courseRowsPerPage = 100;
  int courseCurrentPage = 1;
  String courseSchemeFilter = 'All Schemes';
  String courseSemesterFilter = 'All Semesters';
  String courseTypeFilter = 'All Course Types';

  StudentModel? selectedStudentDetail;
  bool sidebarExpanded = false;
  double studentListPanelRatio = 0.55;

  @override
  void initState() {
    super.initState();
    refresh();
    courseService.getCourses().listen((courses) {
      if (!mounted) return;
      setState(() {
        courseList = courses;
        totalCourses = courses.length;
        coursesLoaded = true;
      });
    });
  }

  @override
  void dispose() {
    studentSearchController.dispose();
    facultySearchController.dispose();
    courseSearchController.dispose();
    super.dispose();
  }

  void closeStudentDetail() {
    setState(() => selectedStudentDetail = null);
  }

  void openStudentDetail(StudentModel student) {
    setState(() => selectedStudentDetail = student);
  }

  bool _isSelectedStudent(StudentModel student) {
    final selected = selectedStudentDetail;
    if (selected == null) {
      return false;
    }
    if (student.documentId != null &&
        selected.documentId != null &&
        student.documentId!.isNotEmpty) {
      return student.documentId == selected.documentId;
    }
    return student.studentId == selected.studentId;
  }

  Key _studentDetailKey(StudentModel student) {
    return ValueKey<String>(
      student.documentId?.isNotEmpty == true
          ? student.documentId!
          : student.studentId,
    );
  }

  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final people = await roleService.listFacultyAndStudentsForOrg(widget.orgId);
      final depts = await roleService.loadDepartmentsForOrg(widget.orgId);
      final org = await roleService.authService.getOrganizationById(widget.orgId);
      final faculty = await facultyService.listFacultyForDept(
        orgId: widget.orgId,
        deptId: widget.deptId,
      );
      final students = await studentService.listStudentsForDept(
        orgId: widget.orgId,
        deptId: widget.deptId,
      );

      bool allowed = false;
      if (currentUser != null) {
        // 1. Check if creator of the department
        final currentDept = depts.where((d) => d.deptId == widget.deptId).firstOrNull;
        if (currentDept != null && currentDept.createdBy == currentUser.uid) {
          allowed = true;
        } else {
          // 2. Check if user has DEPT_ADMIN role for this specific department
          final mappings = await roleService.getAllRoleMappingsForUuid(currentUser.uid);
          allowed = mappings.any((m) =>
              m.normalizedRoleId == 'DEPT_ADMIN' &&
              m.orgId.toUpperCase() == widget.orgId.toUpperCase() &&
              m.deptId.toUpperCase() == widget.deptId.toUpperCase()
          );
        }
      }

      if (!mounted) return;
      setState(() {
        canEditOrDelete = allowed;
        facultyAndStudents = people;
        departments = depts;
        facultyList = faculty;
        studentList = students;
        organizationDisplayName =
        (org?.orgName ?? '').trim().isEmpty ? widget.orgId : org!.orgName;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        facultyAndStudents = [];
        loading = false;
      });
    }
  }

  Future<void> onLogout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LandingPage()),
          (route) => false,
    );
  }

  Future<void> openStudentImportDialog() async {
    try {
      FilePickerResult? result =
      await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null) return;

      final bytes = result.files.single.bytes;

      if (bytes == null) return;

      final excelFile = excel.Excel.decodeBytes(bytes);

      int importedCount = 0;

      for (var sheet in excelFile.tables.keys) {
        final rows = excelFile.tables[sheet]!.rows;

        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];

          final student = StudentModel(
            studentId: row[0]?.value.toString() ?? '',
            fullName: row[1]?.value.toString() ?? '',
            gender: row[2]?.value.toString() ?? '',
            dateOfBirth: row[3]?.value.toString() ?? '',
            aadhaarNumber: row[4]?.value.toString() ?? '',
            category: row[5]?.value.toString() ?? '',
            nationality: row[6]?.value.toString() ?? '',
            bloodGroup: row[7]?.value.toString() ?? '',
            mobile: row[8]?.value.toString() ?? '',
            email: row[9]?.value.toString() ?? '',
            permanentAddress: row[10]?.value.toString() ?? '',
            correspondenceAddress: row[11]?.value.toString() ?? '',
            emergencyContactName: row[12]?.value.toString() ?? '',
            emergencyContactRelation: row[13]?.value.toString() ?? '',
            emergencyContactMobile: row[14]?.value.toString() ?? '',
            photographUrl: '',
            orgId: widget.orgId,
            deptId: widget.deptId,
            createdOn: DateTime.now().toIso8601String(),
          );

          await studentService.createStudent(student);

          importedCount++;
        }

        break;
      }

      await refresh();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$importedCount students imported successfully',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
        ),
      );
    }
  }
  Future<void> openCreateCourse() async {
    final formKey = GlobalKey<FormState>();
    const schemeOptions = ['2023', '2024', '2025', '2026', '2027'];
    const semesterOptions = ['I', 'II', 'III', 'IV'];
    const courseTypeOptions = ['IPCC', 'PCC', 'PCCL', 'AEC', 'BSC'];

    String? selectedScheme;
    String? selectedSemester;
    String? selectedCourseType;
    final courseCodeCtrl = TextEditingController();
    final courseTitleCtrl = TextEditingController();
    final creditsCtrl = TextEditingController();
    final lectureHrsCtrl = TextEditingController(text: '0');
    final tutorialHrsCtrl = TextEditingController(text: '0');
    final practicalHrsCtrl = TextEditingController(text: '0');
    final othersHrsCtrl = TextEditingController(text: '0');
    final cieMarksCtrl = TextEditingController(text: '0');
    final seeExamDurationCtrl = TextEditingController();
    final seeTheoryMarksCtrl = TextEditingController(text: '0');
    final seeLabMarksCtrl = TextEditingController(text: '0');
    bool saving = false;
    int currentStep = 0;
    const int totalSteps = 2;

    int parseNumericField(String value) => int.tryParse(value.trim()) ?? 0;

    String? validateHoursField(String? value) {
      if (value == null || value.trim().isEmpty) {
        return 'This field is required';
      }
      final n = int.tryParse(value.trim());
      if (n == null || n < 0) return 'Enter a valid number';
      return null;
    }

    String? validateMarksField(String? value) {
      if (value == null || value.trim().isEmpty) return null;
      final n = int.tryParse(value.trim());
      if (n == null || n < 0) return 'Enter a valid number';
      return null;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final maxHeight = (media.size.height * 0.9).clamp(480.0, 820.0);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 720, maxHeight: maxHeight),
            child: StatefulBuilder(
              builder: (ctx, setModalState) {
                InputDecoration fieldDecor(String label, {String? hint}) =>
                    InputDecoration(
                      labelText: label,
                      hintText: hint,
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        color: ColorConst.textSecondary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ColorConst.borderSoft),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ColorConst.borderSoft),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: ColorConst.primaryBlue,
                          width: 1.2,
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFD),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    );

                Widget sectionHeader(String title, IconData icon) => Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Row(
                        children: [
                          Icon(icon, size: 14, color: ColorConst.primaryBlue),
                          const SizedBox(width: 6),
                          smcText(
                            textToDisplay: title,
                            textSize: 12,
                            textBoldness: 4,
                            colorOfText: ColorConst.primaryBlue,
                          ),
                        ],
                      ),
                    );

                InputDecoration fieldDecorInput() => InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF9FAFD),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ColorConst.borderSoft),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ColorConst.borderSoft),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: ColorConst.primaryBlue,
                          width: 1.2,
                        ),
                      ),
                    );

                Widget labeledField(
                  String label,
                  TextEditingController controller, {
                  int labelMaxLines = 1,
                  TextInputType keyboardType = TextInputType.number,
                  List<TextInputFormatter>? inputFormatters,
                  String? Function(String?)? validator,
                  void Function(String)? onChanged,
                  bool readOnly = false,
                }) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      smcText(
                        textToDisplay: label,
                        textSize: 12,
                        textBoldness: 3,
                        colorOfText: ColorConst.textSecondary,
                        maxLines: labelMaxLines,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: controller,
                        readOnly: readOnly,
                        decoration: fieldDecorInput(),
                        keyboardType: keyboardType,
                        inputFormatters: inputFormatters,
                        validator: validator,
                        onChanged: onChanged,
                      ),
                    ],
                  );
                }

                int computeSeeMarks() {
                  final int theory = parseNumericField(seeTheoryMarksCtrl.text);
                  final int lab = parseNumericField(seeLabMarksCtrl.text);
                  if (theory > 0) return theory;
                  return lab;
                }

                int computeTotalMarks() =>
                    parseNumericField(cieMarksCtrl.text) + computeSeeMarks();

                void _onNext() {
                  if (currentStep >= totalSteps - 1) return;
                  if (!formKey.currentState!.validate()) return;
                  setModalState(() => currentStep += 1);
                }

                void _onBack() {
                  if (currentStep <= 0) return;
                  setModalState(() => currentStep -= 1);
                }

                Widget _buildStepContent() {
                  switch (currentStep) {
                    case 1:
                      final int totalMarks = computeTotalMarks();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          sectionHeader(
                            'Examination Scheme',
                            Icons.fact_check_outlined,
                          ),
                          labeledField(
                            'Continuous Internal Evaluation (CIE) Marks',
                            cieMarksCtrl,
                            labelMaxLines: 2,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: validateMarksField,
                            onChanged: (_) => setModalState(() {}),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCFDFF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE8EDFA)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const smcText(
                                  textToDisplay: 'Semester End Examinations (SEE)',
                                  textSize: 13,
                                  textBoldness: 4,
                                  colorOfText: Color(0xFF1F2F52),
                                ),
                                const SizedBox(height: 12),
                                labeledField(
                                  'Exam Duration (Hrs)',
                                  seeExamDurationCtrl,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: validateHoursField,
                                  onChanged: (_) => setModalState(() {}),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: labeledField(
                                        'Theory Marks',
                                        seeTheoryMarksCtrl,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        validator: validateMarksField,
                                        onChanged: (v) {
                                          if (parseNumericField(v) > 0) {
                                            seeLabMarksCtrl.text = '0';
                                          }
                                          setModalState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: labeledField(
                                        'Lab Marks',
                                        seeLabMarksCtrl,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        validator: validateMarksField,
                                        onChanged: (v) {
                                          if (parseNumericField(v) > 0) {
                                            seeTheoryMarksCtrl.text = '0';
                                          }
                                          setModalState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const smcText(
                                  textToDisplay:
                                      'Enter either Theory or Lab marks for SEE (not both).',
                                  textSize: 11,
                                  colorOfText: Color(0xFF8A96B2),
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF4FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFD6E2FF)),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: smcText(
                                    textToDisplay: 'Total Marks (CIE + SEE)',
                                    textSize: 13,
                                    textBoldness: 4,
                                    colorOfText: Color(0xFF1F2F52),
                                    maxLines: 2,
                                  ),
                                ),
                                smcText(
                                  textToDisplay: '$totalMarks',
                                  textSize: 20,
                                  textBoldness: 5,
                                  colorOfText: ColorConst.primaryBlue,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    default:
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          sectionHeader(
                            'Course Information',
                            Icons.menu_book_outlined,
                          ),
                          DropdownButtonFormField<String>(
                            value: selectedScheme,
                            decoration: fieldDecor('Scheme *'),
                            items: schemeOptions
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(
                                      s,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setModalState(() => selectedScheme = v),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Please select scheme'
                                : null,
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedSemester,
                            decoration: fieldDecor('Semester *'),
                            items: semesterOptions
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(
                                      s,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setModalState(() => selectedSemester = v),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Please select semester'
                                : null,
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedCourseType,
                            decoration: fieldDecor('Course Type *'),
                            items: courseTypeOptions
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(
                                      t,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setModalState(() => selectedCourseType = v),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Please select course type'
                                : null,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: courseCodeCtrl,
                            decoration: fieldDecor(
                              'Course Code *',
                              hint: 'e.g. CS301',
                            ),
                            textCapitalization: TextCapitalization.characters,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Course code is required'
                                : null,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: courseTitleCtrl,
                            decoration: fieldDecor('Course Title *'),
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Course title is required'
                                : null,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: creditsCtrl,
                            decoration: fieldDecor('No. of Credits *'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Number of credits is required';
                              }
                              final n = int.tryParse(v.trim());
                              if (n == null || n < 1) {
                                return 'Enter a valid credit count';
                              }
                              return null;
                            },
                          ),
                          sectionHeader(
                            'Teaching Hours per Week',
                            Icons.schedule_outlined,
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: labeledField(
                                  'Lecture (Hrs)',
                                  lectureHrsCtrl,
                                  validator: validateHoursField,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: labeledField(
                                  'Tutorial (Hrs)',
                                  tutorialHrsCtrl,
                                  validator: validateHoursField,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: labeledField(
                                  'Practical (Hrs)',
                                  practicalHrsCtrl,
                                  validator: validateHoursField,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: labeledField(
                                  'Others (PBL/ABL/SL/Others)',
                                  othersHrsCtrl,
                                  labelMaxLines: 2,
                                  validator: validateHoursField,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                  }
                }

                Future<void> saveCourse() async {
                  if (!formKey.currentState!.validate()) return;

                  final int theoryMarks = parseNumericField(seeTheoryMarksCtrl.text);
                  final int labMarks = parseNumericField(seeLabMarksCtrl.text);
                  if (theoryMarks > 0 && labMarks > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Enter either Theory or Lab marks for SEE, not both.',
                        ),
                      ),
                    );
                    return;
                  }

                  final bool? confirm = await showDialog<bool>(
                    context: ctx,
                    builder: (dialogCtx) => AlertDialog(
                      title: const smcText(
                        textToDisplay: 'Create Course',
                        textSize: 18,
                        textBoldness: 4,
                        colorOfText: ColorConst.textPrimary,
                      ),
                      content: const smcText(
                        textToDisplay:
                            'Are you sure you want to save this course?',
                        textSize: 14,
                        colorOfText: ColorConst.textSecondary,
                        maxLines: 3,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          child: const smcText(
                            textToDisplay: 'Cancel',
                            textSize: 14,
                            textBoldness: 3,
                            colorOfText: ColorConst.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, true),
                          child: const smcText(
                            textToDisplay: 'Save',
                            textSize: 14,
                            textBoldness: 4,
                            colorOfText: ColorConst.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true) return;

                  setModalState(() => saving = true);

                  final course = CourseModel(
                    id: '',
                    batch: selectedScheme ?? '',
                    semester: selectedSemester ?? '',
                    courseTitle: courseTitleCtrl.text.trim(),
                    faculty: '',
                    courseCode: courseCodeCtrl.text.trim().toUpperCase(),
                    credits: creditsCtrl.text.trim(),
                    courseType: selectedCourseType ?? '',
                    syllabus: '',
                    lectureHrs: parseNumericField(lectureHrsCtrl.text),
                    tutorialHrs: parseNumericField(tutorialHrsCtrl.text),
                    practicalHrs: parseNumericField(practicalHrsCtrl.text),
                    othersHrs: parseNumericField(othersHrsCtrl.text),
                    cieMarks: parseNumericField(cieMarksCtrl.text),
                    seeExamDuration: seeExamDurationCtrl.text.trim(),
                    seeTheoryMarks: theoryMarks,
                    seeLabMarks: labMarks,
                    totalMarks: computeTotalMarks(),
                  );

                  try {
                    await courseService.addCourse(course);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.green.shade600,
                        content: const smcText(
                          textToDisplay: 'Course added successfully.',
                          textSize: 14,
                          colorOfText: Colors.white,
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!ctx.mounted) return;
                    setModalState(() => saving = false);
                    final errorMsg = e.toString().replaceFirst('Exception: ', '');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.red.shade600,
                        content: smcText(
                          textToDisplay: 'Error: $errorMsg',
                          textSize: 13,
                          colorOfText: Colors.white,
                          maxLines: 3,
                        ),
                      ),
                    );
                  }
                }

                return Padding(
                  padding: EdgeInsets.only(
                    left: 18,
                    right: 18,
                    top: 14,
                    bottom: media.viewInsets.bottom + 12,
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const smcText(
                                    textToDisplay: 'Create Course',
                                    textSize: 18,
                                    textBoldness: 5,
                                    colorOfText: ColorConst.textPrimary,
                                  ),
                                  smcText(
                                    textToDisplay:
                                        'Step ${currentStep + 1} of $totalSteps',
                                    textSize: 12,
                                    colorOfText: ColorConst.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              color: ColorConst.textSecondary,
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: SingleChildScrollView(
                            child: _buildStepContent(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            TextButton(
                              onPressed: saving
                                  ? null
                                  : (currentStep == 0
                                      ? () => Navigator.pop(ctx)
                                      : _onBack),
                              child: smcText(
                                textToDisplay: currentStep == 0 ? 'Cancel' : 'Back',
                                textSize: 14,
                                textBoldness: 4,
                                colorOfText: ColorConst.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              height: 40,
                              child: ElevatedButton(
                                onPressed: saving
                                    ? null
                                    : (currentStep == totalSteps - 1
                                        ? saveCourse
                                        : _onNext),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ColorConst.primaryBlue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: saving
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : smcText(
                                        textToDisplay: currentStep == totalSteps - 1
                                            ? 'Create'
                                            : 'Next',
                                        textSize: 15,
                                        colorOfText: Colors.white,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> onImportCourses() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Course import will be available soon.')),
    );
  }

  void onSupport() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const smcText(
          textToDisplay: 'Support',
          textSize: 18,
          textBoldness: 4,
          colorOfText: ColorConst.textPrimary,
        ),
        content: const smcText(
          textToDisplay:
          'For faculty or student placement, contact your organisation administrator.',
          textSize: 14,
          colorOfText: ColorConst.textSecondary,
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const smcText(
              textToDisplay: 'Close',
              textSize: 14,
              textBoldness: 3,
              colorOfText: ColorConst.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  // ── Assign Department sheet (existing) ────────────────────────

  Future<void> openAssignDepartmentSheet(OrgUserRoleMappingItem mapping) async {
    if (departments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: smcText(
            textToDisplay: 'No departments found. Please add departments first.',
            textSize: 14,
            colorOfText: Colors.white,
            maxLines: 3,
          ),
        ),
      );
      return;
    }
    String? chosenDeptId = departments.first.deptId;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            DepartmentMasterItem? deptById(String? id) {
              if (id == null) return null;
              for (final d in departments) {
                if (d.deptId == id) return d;
              }
              return null;
            }

            final DepartmentMasterItem? chosen = deptById(chosenDeptId);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.paddingOf(ctx).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  smcText(
                    textToDisplay: mapping.name,
                    textSize: 18,
                    textBoldness: 5,
                    colorOfText: ColorConst.textPrimary,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  smcText(
                    textToDisplay:
                    'Role: ${mapping.roleId}  ·  Current dept: ${mapping.deptId.isEmpty ? '—' : mapping.deptId}',
                    textSize: 13,
                    colorOfText: ColorConst.textSecondary,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: chosenDeptId,
                        isExpanded: true,
                        items: departments
                            .map(
                              (d) => DropdownMenuItem<String>(
                            value: d.deptId,
                            child: Text(
                              d.deptName.isEmpty
                                  ? d.deptId
                                  : '${d.deptName} (${d.deptId})',
                            ),
                          ),
                        )
                            .toList(),
                        onChanged: (id) {
                          setModalState(() => chosenDeptId = id);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: chosen == null
                          ? null
                          : () async {
                        try {
                          await roleService.assignFacultyOrStudentDepartment(
                            mapping: mapping,
                            department: chosen,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: smcText(
                                textToDisplay: 'Department updated.',
                                textSize: 14,
                                colorOfText: Colors.white,
                              ),
                            ),
                          );
                          await refresh();
                        } catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: smcText(
                                textToDisplay: 'Update failed.',
                                textSize: 14,
                                colorOfText: Colors.white,
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorConst.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const smcText(
                        textToDisplay: 'Assign to department',
                        textSize: 15,
                        textBoldness: 4,
                        colorOfText: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Create/Edit Student bottom sheet ──────────────────────────

  Future<void> openCreateStudentSheet({StudentModel? studentToEdit, bool isViewOnly = false}) async {
    final formKey = GlobalKey<FormState>();

    // Basic Profile
    final studentIdCtrl = TextEditingController(text: studentToEdit?.studentId ?? '');
    final fullNameCtrl = TextEditingController(text: studentToEdit?.fullName ?? '');
    String? selectedGender = studentToEdit?.gender;
    const studentBatchOptions = ['2023-25', '2024-26', '2025-27'];
    String? selectedStudentBatch = studentToEdit?.batch;
    if (selectedStudentBatch != null &&
        !studentBatchOptions.contains(selectedStudentBatch)) {
      selectedStudentBatch = null;
    }
    DateTime? selectedDob;
    if (studentToEdit?.dateOfBirth != null && studentToEdit!.dateOfBirth.isNotEmpty) {
      try {
        selectedDob = DateTime.parse(studentToEdit.dateOfBirth);
      } catch (_) {}
    }
    final dobCtrl = TextEditingController(
      text: selectedDob != null
          ? '${selectedDob.day.toString().padLeft(2, '0')}/${selectedDob.month.toString().padLeft(2, '0')}/${selectedDob.year}'
          : '',
    );

    // Identity / Category
    final aadhaarCtrl = TextEditingController(text: studentToEdit?.aadhaarNumber ?? '');
    String? selectedCategory = studentToEdit?.category;
    String? selectedNationality = studentToEdit?.nationality;
    String? selectedBloodGroup = studentToEdit?.bloodGroup;

    // Contact
    final mobileCtrl = TextEditingController(text: studentToEdit?.mobile ?? '');
    final emailCtrl = TextEditingController(text: studentToEdit?.email ?? '');

    // Address
    final permanentAddrCtrl = TextEditingController(text: studentToEdit?.permanentAddress ?? '');
    final correspondenceAddrCtrl = TextEditingController(text: studentToEdit?.correspondenceAddress ?? '');

    // Emergency Contact
    final emergNameCtrl = TextEditingController(text: studentToEdit?.emergencyContactName ?? '');
    final emergRelationCtrl = TextEditingController(text: studentToEdit?.emergencyContactRelation ?? '');
    final emergMobileCtrl = TextEditingController(text: studentToEdit?.emergencyContactMobile ?? '');

    bool saving = false;
    Uint8List? photographBytes;
    String? photographUrl = studentToEdit?.photographUrl;
    String? photographError;
    String? bloodGroupError;
    int currentStep = 0;
    const int totalSteps = 3;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final maxHeight = (media.size.height * 0.9).clamp(520.0, 820.0);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 720, maxHeight: maxHeight),
            child: StatefulBuilder(
              builder: (ctx, setModalState) {
            InputDecoration _fieldDecor(String label, {String? hint}) =>
                InputDecoration(
                  labelText: label,
                  hintText: hint,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    color: ColorConst.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: ColorConst.borderSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: ColorConst.borderSoft),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: ColorConst.primaryBlue,
                      width: 1.2,
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFD),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                );

            Widget _sectionHeader(String title, IconData icon) => Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: ColorConst.primaryBlue),
                  const SizedBox(width: 6),
                  smcText(
                    textToDisplay: title,
                    textSize: 12,
                    textBoldness: 4,
                    colorOfText: ColorConst.primaryBlue,
                  ),
                ],
              ),
            );

            Future<void> _saveStudent() async {
              if (!formKey.currentState!.validate()) return;

              if (studentToEdit == null) {
                final bool? confirm = await showDialog<bool>(
                  context: ctx,
                  builder: (dialogCtx) => AlertDialog(
                    title: const smcText(
                      textToDisplay: 'Create Student',
                      textSize: 18,
                      textBoldness: 4,
                      colorOfText: ColorConst.textPrimary,
                    ),
                    content: const smcText(
                      textToDisplay:
                          'Are you sure you want to save this student record?',
                      textSize: 14,
                      colorOfText: ColorConst.textSecondary,
                      maxLines: 3,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: const smcText(
                          textToDisplay: 'Cancel',
                          textSize: 14,
                          textBoldness: 3,
                          colorOfText: ColorConst.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: const smcText(
                          textToDisplay: 'Save',
                          textSize: 14,
                          textBoldness: 4,
                          colorOfText: ColorConst.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
              }

              setModalState(() => saving = true);

              if (photographBytes != null) {
                final ref = FirebaseStorage.instance
                    .ref()
                    .child('student_photos')
                    .child(
                      '${studentIdCtrl.text.trim().toUpperCase()}_${DateTime.now().millisecondsSinceEpoch}.jpg',
                    );
                await ref.putData(
                  photographBytes!,
                  SettableMetadata(contentType: 'image/jpeg'),
                );
                photographUrl = await ref.getDownloadURL();
              }

              final student = StudentModel(
                documentId: studentToEdit?.documentId,
                studentId: studentIdCtrl.text.trim().toUpperCase(),
                fullName: fullNameCtrl.text.trim(),
                gender: selectedGender ?? '',
                dateOfBirth: selectedDob?.toIso8601String().split('T')[0] ?? '',
                photographUrl: photographUrl ?? '',
                batch: selectedStudentBatch ?? '',
                aadhaarNumber: aadhaarCtrl.text.trim(),
                category: selectedCategory ?? '',
                nationality: selectedNationality ?? '',
                bloodGroup: selectedBloodGroup ?? '',
                mobile: mobileCtrl.text.trim(),
                email: emailCtrl.text.trim().toLowerCase(),
                permanentAddress: permanentAddrCtrl.text.trim(),
                correspondenceAddress: correspondenceAddrCtrl.text.trim(),
                emergencyContactName: emergNameCtrl.text.trim(),
                emergencyContactRelation: emergRelationCtrl.text.trim(),
                emergencyContactMobile: emergMobileCtrl.text.trim(),
                orgId: widget.orgId,
                deptId: widget.deptId,
                createdOn: studentToEdit?.createdOn ??
                    DateTime.now().toIso8601String(),
              );

              try {
                if (studentToEdit != null) {
                  await studentService.updateStudent(
                    documentId: studentToEdit.documentId!,
                    updated: student,
                  );
                } else {
                  await studentService.createStudent(student);
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.green.shade600,
                    content: smcText(
                      textToDisplay:
                          'Student ${studentToEdit == null ? 'added' : 'updated'} successfully.',
                      textSize: 14,
                      colorOfText: Colors.white,
                    ),
                  ),
                );
                await refresh();
              } catch (e) {
                if (!ctx.mounted) return;
                setModalState(() => saving = false);
                final errorMsg = e.toString().replaceFirst('Exception: ', '');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.red.shade600,
                    content: smcText(
                      textToDisplay: 'Error: $errorMsg',
                      textSize: 13,
                      colorOfText: Colors.white,
                      maxLines: 3,
                    ),
                  ),
                );
              }
            }

            void _onNext() {
              if (currentStep >= totalSteps - 1) return;
              if (!formKey.currentState!.validate()) return;
              if (currentStep == 0 &&
                  photographBytes == null &&
                  (photographUrl == null || photographUrl!.trim().isEmpty)) {
                setModalState(() {
                  photographError = 'Photograph is required';
                });
                return;
              }
              if (currentStep == 1 &&
                  (selectedBloodGroup == null ||
                      selectedBloodGroup!.trim().isEmpty)) {
                setModalState(() {
                  bloodGroupError = 'Please select blood group';
                });
                return;
              }
              setModalState(() {
                photographError = null;
                bloodGroupError = null;
                currentStep += 1;
              });
            }

            void _onBack() {
              if (currentStep <= 0) return;
              setModalState(() {
                currentStep -= 1;
              });
            }

            Widget _buildPhotographPreview() {
              if (photographBytes != null) {
                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 280,
                        height: 420,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ColorConst.borderSoft),
                          color: const Color(0xFFF7F9FF),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.memory(
                          photographBytes!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                );
              }

              final String normalizedUrl =
                  _normalizeStudentPhotoUrl(photographUrl ?? '');
              if (normalizedUrl.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: _StudentPhotoAvatar(
                      photoUrl: normalizedUrl,
                      previewWidth: 280,
                      previewHeight: 420,
                    ),
                  ),
                ],
              );
            }

            Widget _buildStepContent() {
              switch (currentStep) {
                case 0:
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(
                        'Basic Profile Information',
                        Icons.person_outline_rounded,
                      ),
                      TextFormField(
                        controller: studentIdCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor(
                          'Student ID (USN) *',
                          hint: 'e.g. 1AB20CS001',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Student ID is required'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: fullNameCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Full Name *'),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Full name is required'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedGender,
                        decoration: _fieldDecor('Gender *'),
                        items: ['Male', 'Female', 'Other']
                            .map(
                              (g) => DropdownMenuItem(
                                value: g,
                                child: Text(
                                  g,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: isViewOnly
                            ? null
                            : (v) =>
                                setModalState(() => selectedGender = v),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please select gender'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: dobCtrl,
                        readOnly: true,
                        decoration: _fieldDecor('Date of Birth *').copyWith(
                          suffixIcon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                          ),
                        ),
                        onTap: isViewOnly
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: DateTime(2005),
                                  firstDate: DateTime(1990),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    selectedDob = picked;
                                    dobCtrl.text =
                                        '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                                  });
                                }
                              },
                        validator: (_) => selectedDob == null
                            ? 'Date of birth is required'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedStudentBatch,
                        decoration: _fieldDecor('Batch *'),
                        items: studentBatchOptions
                            .map(
                              (batch) => DropdownMenuItem(
                                value: batch,
                                child: Text(
                                  batch,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: isViewOnly
                            ? null
                            : (v) => setModalState(
                                  () => selectedStudentBatch = v,
                                ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please select batch'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: isViewOnly
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 70,
                                );
                                if (picked != null) {
                                  final bytes = await picked.readAsBytes();
                                  setModalState(() {
                                    photographBytes = bytes;
                                    photographError = null;
                                  });
                                }
                              },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ColorConst.borderSoft),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.photo_camera_outlined,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isViewOnly ? 'Photograph' : 'Upload Photograph',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (photographError != null) ...[
                        const SizedBox(height: 6),
                        smcText(
                          textToDisplay: photographError!,
                          textSize: 12,
                          colorOfText: const Color(0xFFC62828),
                        ),
                      ],
                      _buildPhotographPreview(),
                    ],
                  );
                case 1:
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(
                        'Identity & Category',
                        Icons.verified_user_outlined,
                      ),
                      TextFormField(
                        controller: aadhaarCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Aadhaar / Govt ID'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: _fieldDecor('Category *'),
                        items: ['Gen', 'OBC', 'SC', 'ST']
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: isViewOnly
                            ? null
                            : (v) => setModalState(() => selectedCategory = v),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please select category'
                            : null,
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedNationality,
                        decoration: _fieldDecor('Nationality *'),
                        items: ['Indian', 'NRI', 'Foreigner']
                            .map(
                              (n) => DropdownMenuItem(
                                value: n,
                                child: Text(
                                  n,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: isViewOnly
                            ? null
                            : (v) =>
                                setModalState(() => selectedNationality = v),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please select nationality'
                            : null,
                      ),
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 4),
                        child: smcText(
                          textToDisplay: 'Blood Group *',
                          textSize: 12,
                          colorOfText: ColorConst.textSecondary,
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        runSpacing: 0,
                        children: [
                          'A+',
                          'A-',
                          'B+',
                          'B-',
                          'O+',
                          'O-',
                          'AB+',
                          'AB-'
                        ].map((bg) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Radio<String>(
                                value: bg,
                                groupValue: selectedBloodGroup,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                activeColor: ColorConst.primaryBlue,
                                onChanged: isViewOnly
                                    ? null
                                    : (v) => setModalState(
                                          () {
                                            selectedBloodGroup = v;
                                            bloodGroupError = null;
                                          },
                                        ),
                              ),
                              smcText(
                                textToDisplay: bg,
                                textSize: 12,
                                colorOfText: ColorConst.textPrimary,
                              ),
                              const SizedBox(width: 4),
                            ],
                          );
                        }).toList(),
                      ),
                      if (bloodGroupError != null) ...[
                        const SizedBox(height: 4),
                        smcText(
                          textToDisplay: bloodGroupError!,
                          textSize: 12,
                          colorOfText: const Color(0xFFC62828),
                        ),
                      ],
                      _sectionHeader(
                        'Contact Details',
                        Icons.contact_phone_outlined,
                      ),
                      TextFormField(
                        controller: mobileCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Mobile Number *'),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Mobile number is required';
                          }
                          if (v.trim().length != 10) {
                            return 'Enter valid 10-digit mobile number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: emailCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Email Address *'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          final emailRegex =
                              RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
                          if (!emailRegex.hasMatch(v.trim())) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      _buildPhotographPreview(),
                    ],
                  );
                default:
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader('Address', Icons.home_outlined),
                      TextFormField(
                        controller: permanentAddrCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Permanent Address'),
                        maxLines: 1,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Permanent address is required'
                            : null,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: correspondenceAddrCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Correspondence Address'),
                        maxLines: 1,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Correspondence address is required'
                            : null,
                      ),
                      _sectionHeader(
                        'Emergency Contact (Parent/Guardian)',
                        Icons.emergency_outlined,
                      ),
                      TextFormField(
                        controller: emergNameCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Contact Person Name'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Contact person name is required'
                            : null,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: emergRelationCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Relation'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Relation is required'
                            : null,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: emergMobileCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Emergency Mobile'),
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Emergency mobile is required'
                            : null,
                      ),
                      _buildPhotographPreview(),
                    ],
                  );
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 14,
                bottom: media.viewInsets.bottom + 12,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              smcText(
                                textToDisplay: isViewOnly
                                    ? 'Student Details'
                                    : (studentToEdit == null
                                        ? 'Create Student'
                                        : 'Edit Student'),
                                textSize: 18,
                                textBoldness: 5,
                                colorOfText: ColorConst.textPrimary,
                              ),
                              smcText(
                                textToDisplay:
                                    'Step ${currentStep + 1} of $totalSteps',
                                textSize: 12,
                                colorOfText: ColorConst.textSecondary,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: ColorConst.textSecondary,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _buildStepContent(),
                      ),
                    ),

                    if (!isViewOnly) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          TextButton(
                            onPressed: currentStep == 0 ? null : _onBack,
                            child: const smcText(
                              textToDisplay: 'Back',
                              textSize: 14,
                              textBoldness: 4,
                              colorOfText: ColorConst.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            height: 40,
                            child: ElevatedButton(
                              onPressed: saving
                                  ? null
                                  : (currentStep == totalSteps - 1
                                      ? _saveStudent
                                      : _onNext),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ColorConst.primaryBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: saving
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : smcText(
                                      textToDisplay:
                                          currentStep == totalSteps - 1
                                              ? (studentToEdit == null
                                                  ? 'Save Student'
                                                  : 'Update Student')
                                              : 'Next',
                                      textSize: 15,
                                      colorOfText: Colors.white,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          TextButton(
                            onPressed: currentStep == 0 ? null : _onBack,
                            child: const smcText(
                              textToDisplay: 'Back',
                              textSize: 14,
                              textBoldness: 4,
                              colorOfText: ColorConst.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed:
                                currentStep == totalSteps - 1 ? null : _onNext,
                            child: const smcText(
                              textToDisplay: 'Next',
                              textSize: 14,
                              textBoldness: 4,
                              colorOfText: ColorConst.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
              },
            ),
          ),
        );
      },
    );
  }

  // ── Create/Edit Faculty bottom sheet ──────────────────────────

  Future<void> openCreateFacultySheet({FacultyModel? facultyToEdit, bool isViewOnly = false}) async {
    final formKey = GlobalKey<FormState>();

    // Controllers — Basic Profile
    final facultyIdCtrl = TextEditingController(text: facultyToEdit?.facultyId ?? '');
    final fullNameCtrl = TextEditingController(text: facultyToEdit?.fullName ?? '');
    String selectedGender = facultyToEdit?.gender ?? 'Male';
    DateTime? selectedDob;
    if (facultyToEdit?.dateOfBirth != null && facultyToEdit!.dateOfBirth.isNotEmpty) {
      try {
        selectedDob = DateTime.parse(facultyToEdit.dateOfBirth);
      } catch (_) {}
    }
    final dobCtrl = TextEditingController(
      text: selectedDob != null
          ? '${selectedDob.day.toString().padLeft(2, '0')}/${selectedDob.month.toString().padLeft(2, '0')}/${selectedDob.year}'
          : '',
    );

    // Compliance
    final aadhaarCtrl = TextEditingController(text: facultyToEdit?.aadhaarNumber ?? '');
    final panCtrl = TextEditingController(text: facultyToEdit?.panNumber ?? '');

    // Contact
    final mobileCtrl = TextEditingController(text: facultyToEdit?.mobile ?? '');
    final emailCtrl = TextEditingController(text: facultyToEdit?.email ?? '');

    // Address
    final permanentAddrCtrl = TextEditingController(text: facultyToEdit?.permanentAddress ?? '');
    final currentAddrCtrl = TextEditingController(text: facultyToEdit?.currentAddress ?? '');

    // Emergency Contact
    final emergNameCtrl = TextEditingController(text: facultyToEdit?.emergencyContactName ?? '');
    final emergRelationCtrl = TextEditingController(text: facultyToEdit?.emergencyContactRelation ?? '');
    final emergMobileCtrl = TextEditingController(text: facultyToEdit?.emergencyContactMobile ?? '');

    bool saving = false;
    Uint8List? photographBytes;
    String? photographUrl = facultyToEdit?.photographUrl;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            // ── helpers ────────────────────────────────────────
            InputDecoration _fieldDecor(String label, {String? hint}) =>
                InputDecoration(
                  labelText: label,
                  hintText: hint,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    color: ColorConst.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: ColorConst.borderSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: ColorConst.borderSoft),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: ColorConst.primaryBlue,
                      width: 1.2,
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFD),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                );

            Widget _sectionHeader(String title, IconData icon) => Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: ColorConst.primaryBlue),
                  const SizedBox(width: 6),
                  smcText(
                    textToDisplay: title,
                    textSize: 12,
                    textBoldness: 4,
                    colorOfText: ColorConst.primaryBlue,
                  ),
                ],
              ),
            );

            // ── sheet body ─────────────────────────────────────
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 4,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 12,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── drag handle ────────────────────────
                      Center(
                        child: Container(
                          width: 32,
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCE2F4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),

                      // ── title row ─────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: smcText(
                              textToDisplay: isViewOnly ? 'Faculty Details' : (facultyToEdit == null ? 'Create Faculty' : 'Edit Faculty'),
                              textSize: 18,
                              textBoldness: 5,
                              colorOfText: ColorConst.textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: ColorConst.textSecondary,
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),

                      // ══════════════════════════════════════
                      // 1. Basic Profile Information
                      // ══════════════════════════════════════
                      _sectionHeader(
                        'Basic Profile Information',
                        Icons.person_outline_rounded,
                      ),

                      // Faculty / Employee ID
                      TextFormField(
                        controller: facultyIdCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor(
                          'Faculty / Employee ID *',
                          hint: 'e.g. FAC-2024-001',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Faculty ID is required'
                            : null,
                      ),
                      const SizedBox(height: 8),

                      // Full Name
                      TextFormField(
                        controller: fullNameCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Full Name *'),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Full name is required'
                            : null,
                      ),
                      const SizedBox(height: 8),

                      // Gender dropdown
                      DropdownButtonFormField<String>(
                        value: selectedGender,
                        decoration: _fieldDecor('Gender *'),
                        borderRadius: BorderRadius.circular(10),
                        items: const [
                          'Male',
                          'Female',
                          'Other',
                          'Prefer not to say',
                        ]
                            .map(
                              (g) => DropdownMenuItem(
                            value: g,
                            child: Text(g, style: const TextStyle(fontSize: 13)),
                          ),
                        )
                            .toList(),
                        onChanged: isViewOnly ? null : (v) {
                          if (v != null) {
                            setModalState(() => selectedGender = v);
                          }
                        },
                      ),
                      const SizedBox(height: 8),

                      // Date of Birth — tap-to-pick
                      TextFormField(
                        controller: dobCtrl,
                        readOnly: true,
                        decoration: _fieldDecor('Date of Birth *').copyWith(
                          suffixIcon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: ColorConst.textSecondary,
                          ),
                        ),
                        onTap: isViewOnly ? null : () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime(1990),
                            firstDate: DateTime(1940),
                            lastDate: DateTime.now()
                                .subtract(const Duration(days: 365 * 18)),
                            helpText: 'Select Date of Birth',
                          );
                          if (picked != null) {
                            setModalState(() {
                              selectedDob = picked;
                              dobCtrl.text =
                              '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                            });
                          }
                        },
                        validator: (_) =>
                        selectedDob == null ? 'Date of birth is required' : null,
                      ),
                      const SizedBox(height: 8),

                      // Photograph upload
                      GestureDetector(
                        onTap: isViewOnly ? null : () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 70,
                            maxWidth: 600,
                          );
                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            setModalState(() {
                              photographBytes = bytes;
                            });
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ColorConst.borderSoft),
                          ),
                          child: photographBytes != null
                              ? Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  photographBytes!,
                                  height: 80,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if (!isViewOnly)
                              GestureDetector(
                                onTap: () => setModalState(() => photographBytes = null),
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          )
                              : Row(
                            children: [
                              const Icon(Icons.photo_camera_outlined, size: 16, color: ColorConst.primaryBlue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: smcText(
                                  textToDisplay: isViewOnly ? 'Photograph' : 'Tap to upload photograph (optional)',
                                  textSize: 12,
                                  colorOfText: ColorConst.textSecondary,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ══════════════════════════════════════
                      // 2. India-Specific Compliance
                      // ══════════════════════════════════════
                      _sectionHeader(
                        'Compliance (Aadhaar / PAN)',
                        Icons.verified_user_outlined,
                      ),

                      TextFormField(
                        controller: aadhaarCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Aadhaar Number'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (v.trim().length != 12) {
                            return 'Aadhaar must be 12 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: panCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('PAN Number'),
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
                          if (!panRegex.hasMatch(v.trim().toUpperCase())) {
                            return 'Invalid PAN (e.g. ABCDE1234F)';
                          }
                          return null;
                        },
                      ),

                      // ══════════════════════════════════════
                      // 3. Contact Details
                      // ══════════════════════════════════════
                      _sectionHeader(
                        'Contact Details',
                        Icons.contact_phone_outlined,
                      ),

                      TextFormField(
                        controller: mobileCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Mobile Number *'),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Mobile number is required';
                          }
                          if (v.trim().length != 10) {
                            return 'Enter valid 10-digit mobile number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: emailCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Email Address *'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          final emailRegex =
                          RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
                          if (!emailRegex.hasMatch(v.trim())) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),

                      // ══════════════════════════════════════
                      // 4. Address
                      // ══════════════════════════════════════
                      _sectionHeader(
                        'Address',
                        Icons.home_outlined,
                      ),

                      TextFormField(
                        controller: permanentAddrCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Permanent Address'),
                        maxLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: currentAddrCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Current Address'),
                        maxLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                      ),

                      // ══════════════════════════════════════
                      // 5. Emergency Contact
                      // ══════════════════════════════════════
                      _sectionHeader(
                        'Emergency Contact',
                        Icons.emergency_outlined,
                      ),

                      TextFormField(
                        controller: emergNameCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Contact Person Name'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: emergRelationCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor(
                          'Relation',
                          hint: 'e.g. Spouse, Parent, Sibling',
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: emergMobileCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Emergency Mobile'),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (v.trim().length != 10) {
                            return 'Enter valid 10-digit number';
                          }
                          return null;
                        },
                      ),

                      // ── Save button ────────────────────────
                      const SizedBox(height: 16),
                      if (!isViewOnly)
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: saving
                              ? null
                              : () async {
                            if (!formKey.currentState!.validate()) return;
                            setModalState(() => saving = true);

                            // Upload photo if selected
                            if (photographBytes != null) {
                              final ref = FirebaseStorage.instance
                                  .ref()
                                  .child('faculty_photos')
                                  .child('${facultyIdCtrl.text.trim().toUpperCase()}_${DateTime.now().millisecondsSinceEpoch}.jpg');
                              await ref.putData(
                                photographBytes!,
                                SettableMetadata(contentType: 'image/jpeg'),
                              );
                              photographUrl = await ref.getDownloadURL();
                            }

                            final faculty = FacultyModel(
                              documentId: facultyToEdit?.documentId,
                              facultyId: facultyIdCtrl.text.trim().toUpperCase(),
                              fullName: fullNameCtrl.text.trim(),
                              gender: selectedGender,
                              dateOfBirth: selectedDob != null
                                  ? '${selectedDob!.year}-'
                                  '${selectedDob!.month.toString().padLeft(2, '0')}-'
                                  '${selectedDob!.day.toString().padLeft(2, '0')}'
                                  : '',
                              aadhaarNumber: aadhaarCtrl.text.trim(),
                              panNumber: panCtrl.text.trim().toUpperCase(),
                              mobile: mobileCtrl.text.trim(),
                              email: emailCtrl.text.trim().toLowerCase(),
                              permanentAddress: permanentAddrCtrl.text.trim(),
                              currentAddress: currentAddrCtrl.text.trim(),
                              emergencyContactName: emergNameCtrl.text.trim(),
                              emergencyContactRelation:
                              emergRelationCtrl.text.trim(),
                              emergencyContactMobile:
                              emergMobileCtrl.text.trim(),
                              orgId: widget.orgId,
                              deptId: widget.deptId,
                              photographUrl: photographUrl ?? '',
                              createdAt: facultyToEdit?.createdAt ?? DateTime.now().toIso8601String(),
                            );

                            try {
                              if (facultyToEdit != null) {
                                await facultyService.updateFaculty(
                                  documentId: facultyToEdit.documentId!,
                                  updated: faculty,
                                );
                              } else {
                                await facultyService.createFaculty(faculty);
                              }
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.green.shade600,
                                  content: smcText(
                                    textToDisplay:
                                    '${faculty.fullName} ${facultyToEdit == null ? 'added' : 'updated'} successfully.',
                                    textSize: 14,
                                    colorOfText: Colors.white,
                                  ),
                                ),
                              );
                              await refresh();
                            } catch (e) {
                              if (!ctx.mounted) return;
                              setModalState(() => saving = false);
                              final errorMsg = e.toString().replaceFirst('Exception: ', '');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.red.shade600,
                                  content: smcText(
                                    textToDisplay: 'Error: $errorMsg',
                                    textSize: 13,
                                    colorOfText: Colors.white,
                                    maxLines: 3,
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorConst.primaryBlue,
                            disabledBackgroundColor: ColorConst.primaryBlue.withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: saving
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                              : smcText(
                            textToDisplay: facultyToEdit == null ? 'Save Faculty' : 'Update Faculty',
                            textSize: 15,
                            textBoldness: 4,
                            colorOfText: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Row(
          children: [
            // ── Side nav ────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: sidebarExpanded ? 240 : 84,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Color(0xFFE3EAF8))),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment:
                      sidebarExpanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: [
                    if (sidebarExpanded)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Row(
                          children: [
                            const Expanded(
                              child: smcText(
                                textToDisplay: 'Department Admin',
                                textSize: 18,
                                textBoldness: 5,
                                colorOfText: ColorConst.textPrimary,
                                maxLines: 1,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded),
                              tooltip: 'Collapse menu',
                              color: ColorConst.textSecondary,
                              onPressed: () => setState(() => sidebarExpanded = false),
                            ),
                          ],
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        tooltip: 'Expand menu',
                        color: ColorConst.primaryBlue,
                        onPressed: () => setState(() => sidebarExpanded = true),
                      ),
                    const SizedBox(height: 8),
                    _menuTile(
                      title: 'Dashboard',
                      icon: Icons.dashboard_outlined,
                      isSelected: selectedMenuIndex == 0,
                      sidebarExpanded: sidebarExpanded,
                      onTap: () => setState(() {
                        selectedMenuIndex = 0;
                        selectedStudentDetail = null;
                      }),
                    ),
                    const SizedBox(height: 8),
                    _menuTile(
                      title: 'Students',
                      icon: Icons.school_outlined,
                      isSelected: selectedMenuIndex == 1,
                      sidebarExpanded: sidebarExpanded,
                      onTap: () => setState(() => selectedMenuIndex = 1),
                    ),
                    const SizedBox(height: 8),
                    _menuTile(
                      title: 'Faculties',
                      icon: Icons.people_alt_outlined,
                      isSelected: selectedMenuIndex == 2,
                      sidebarExpanded: sidebarExpanded,
                      onTap: () => setState(() {
                        selectedMenuIndex = 2;
                        selectedStudentDetail = null;
                      }),
                    ),
                    const SizedBox(height: 8),
                    _menuTile(
                      title: 'Courses',
                      icon: Icons.people_alt_outlined,
                      isSelected: selectedMenuIndex == 3,
                      sidebarExpanded: sidebarExpanded,
                      onTap: () => setState(() {
                        selectedMenuIndex = 3;
                        selectedStudentDetail = null;
                      }),
                    ),
                    const SizedBox(height: 8),
                    _menuTile(
                      title: 'Support',
                      icon: Icons.support_agent_rounded,
                      isSelected: false,
                      sidebarExpanded: sidebarExpanded,
                      onTap: onSupport,
                    ),
                    const Spacer(),
                    _menuTile(
                      title: 'Logout',
                      icon: Icons.logout_rounded,
                      isSelected: false,
                      sidebarExpanded: sidebarExpanded,
                      onTap: onLogout,
                    ),
                  ],
                ),
              ),
            ),

            // ── Main content ─────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildSelectedView(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedView() {
    switch (selectedMenuIndex) {
      case 1:
        return _buildStudentsView();
      case 2:
        return _buildFacultiesView();
      case 3:
        return _buildCoursesView();

      default:
        return _buildDashboardView();
    }
  }

  Widget _buildDashboardView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const smcText(
          textToDisplay: 'Department Overview',
          textSize: 16,
          textBoldness: 5,
          colorOfText: ColorConst.textPrimary,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard(
              title: 'Total Students',
              count: studentList.length.toString(),
              icon: Icons.school_rounded,
              color: Colors.blue,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              title: 'Total Faculty',
              count: facultyList.length.toString(),
              icon: Icons.people_alt_rounded,
              color: Colors.green,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              title: 'Total Courses',
              count: totalCourses.toString(),
              icon: Icons.menu_book_rounded,
              color: Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({required String title, required String count, required IconData icon, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3EAF8)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                smcText(
                  textToDisplay: title,
                  textSize: 13,
                  colorOfText: ColorConst.textSecondary,
                ),
                smcText(
                  textToDisplay: count,
                  textSize: 20,
                  textBoldness: 5,
                  colorOfText: ColorConst.textPrimary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsView() {
    if (selectedStudentDetail == null) {
      return buildStudentTable();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const double dividerWidth = 10;
        const double minListWidth = 360;
        const double minDetailWidth = 320;
        final double availableWidth =
            (constraints.maxWidth - dividerWidth).clamp(0, double.infinity);

        if (availableWidth <= minListWidth + minDetailWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: buildStudentTable()),
              _buildStudentPanelDivider(constraints.maxWidth),
              Expanded(
                flex: 4,
                child: PersonDetailPage(
                  key: _studentDetailKey(selectedStudentDetail!),
                  person: selectedStudentDetail!,
                  isStudent: true,
                  embedded: true,
                  onClose: closeStudentDetail,
                  onEditStudent: () => openCreateStudentSheet(
                    studentToEdit: selectedStudentDetail!,
                  ),
                ),
              ),
            ],
          );
        }

        final double listWidth = (availableWidth * studentListPanelRatio)
            .clamp(minListWidth, availableWidth - minDetailWidth);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: listWidth, child: buildStudentTable()),
            _buildStudentPanelDivider(constraints.maxWidth),
            Expanded(
              child: PersonDetailPage(
                key: _studentDetailKey(selectedStudentDetail!),
                person: selectedStudentDetail!,
                isStudent: true,
                embedded: true,
                onClose: closeStudentDetail,
                onEditStudent: () => openCreateStudentSheet(
                  studentToEdit: selectedStudentDetail!,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStudentPanelDivider(double totalWidth) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          setState(() {
            studentListPanelRatio += details.delta.dx / totalWidth;
            studentListPanelRatio = studentListPanelRatio.clamp(0.3, 0.7);
          });
        },
        child: Container(
          width: 10,
          child: Center(
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD8E2F4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFacultiesView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: smcText(
                textToDisplay: 'Faculty in your department',
                textSize: 14,
                textBoldness: 3,
                colorOfText: ColorConst.textSecondary,
              ),
            ),
            ElevatedButton.icon(
              onPressed: openCreateFacultySheet,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Colors.white),
              label: const smcText(
                textToDisplay: 'Create Faculty',
                textSize: 14,
                textBoldness: 4,
                colorOfText: Colors.white,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorConst.primaryBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(child: buildFacultyTable()),
      ],
    );
  }

  Widget _buildCoursesView() {
    if (!coursesLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return buildCourseTable();
  }

  // ── Student Table ───────────────────────────────────────────

  String _normalizeStudentPhotoUrl(String rawUrl) {
    final value = rawUrl.trim();
    if (value.isEmpty) {
      return '';
    }
    if (value.startsWith('gs://')) {
      return value;
    }
    if (value.startsWith('//')) {
      return 'https:$value';
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '';
  }

  Widget _buildStudentAvatar(StudentModel student, {double radius = 18}) {
    final String initial = student.fullName.trim().isEmpty
        ? '?'
        : student.fullName.trim().substring(0, 1).toUpperCase();
    final String rawUrl = student.photographUrl;
    final String normalizedUrl = _normalizeStudentPhotoUrl(rawUrl);

    return _StudentPhotoAvatar(
      photoUrl: normalizedUrl,
      fallbackInitial: initial,
      radius: radius,
    );
  }

  Widget buildStudentTable() {
    final String searchTerm = studentSearchController.text.trim().toLowerCase();
    final List<StudentModel> batchFiltered = studentBatchFilter == 'All Batches'
        ? studentList
        : studentList.where((s) => s.batch == studentBatchFilter).toList();
    final List<StudentModel> genderFiltered = studentGenderFilter == 'All Gender'
        ? batchFiltered
        : batchFiltered.where((s) => s.gender == studentGenderFilter).toList();
    final List<StudentModel> searched = genderFiltered.where((s) {
      if (searchTerm.isEmpty) return true;
      return '${s.studentId} ${s.fullName} ${s.email} ${s.mobile} ${s.batch} ${s.gender}'
          .toLowerCase()
          .contains(searchTerm);
    }).toList()
      ..sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );

    final int totalRows = searched.length;
    final int totalPages = totalRows == 0 ? 1 : ((totalRows - 1) ~/ studentRowsPerPage) + 1;
    final int safePage = studentCurrentPage.clamp(1, totalPages);
    final int startIndex = (safePage - 1) * studentRowsPerPage;
    final int endIndex = (startIndex + studentRowsPerPage).clamp(0, totalRows);
    final List<StudentModel> pageRows =
        totalRows == 0 ? <StudentModel>[] : searched.sublist(startIndex, endIndex);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4EBFB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.school_outlined, color: ColorConst.primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: smcText(
                            textToDisplay: 'Student List',
                            textSize: 16,
                            textBoldness: 5,
                            colorOfText: Color(0xFF1F2F52),
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF4FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: smcText(
                            textToDisplay: '${studentList.length}',
                            textSize: 12,
                            textBoldness: 4,
                            colorOfText: ColorConst.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const smcText(
                      textToDisplay: 'View and manage all students in your department.',
                      textSize: 12,
                      colorOfText: Color(0xFF7D87A3),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: openCreateStudentSheet,
                    icon: const Icon(Icons.school_rounded, size: 18, color: Colors.white),
                    label: const smcText(
                      textToDisplay: 'Create',
                      textSize: 14,
                      textBoldness: 4,
                      colorOfText: Colors.white,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorConst.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  OutlinedButton.icon(
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (_) => StudentImportDialog(
                          orgId: widget.orgId,
                          deptId: widget.deptId,
                        ),
                      );

                      await refresh();
                    },

                    icon: const Icon(
                      Icons.upload_file_rounded,
                    ),

                    label: const Text(
                      'Import Students',
                    ),

                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColorConst.primaryBlue,
                      side: const BorderSide(
                        color: ColorConst.primaryBlue,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search and Filters
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFCFDFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8EDFA)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool stackFilters = constraints.maxWidth < 560;
                final Widget searchField = SizedBox(
                  height: 44,
                  child: TextField(
                    controller: studentSearchController,
                    onChanged: (_) => setState(() => studentCurrentPage = 1),
                    decoration: InputDecoration(
                      hintText: 'Search students...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF8A96B2)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ColorConst.primaryBlue),
                      ),
                    ),
                  ),
                );
                final Widget batchDropdown = SizedBox(
                  height: 44,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: studentBatchFilter,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ColorConst.primaryBlue),
                      ),
                    ),
                    items: ['All Batches', '2023-25', '2024-26', '2025-27']
                        .map(
                          (batch) => DropdownMenuItem(
                            value: batch,
                            child: Text(
                              batch,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          studentBatchFilter = v;
                          studentCurrentPage = 1;
                        });
                      }
                    },
                  ),
                );
                final Widget genderDropdown = SizedBox(
                  height: 44,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: studentGenderFilter,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ColorConst.primaryBlue),
                      ),
                    ),
                    items: ['All Gender', 'Male', 'Female', 'Other']
                        .map(
                          (g) => DropdownMenuItem(
                            value: g,
                            child: Text(
                              g,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          studentGenderFilter = v;
                          studentCurrentPage = 1;
                        });
                      }
                    },
                  ),
                );
                final Widget resetButton = SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        studentSearchController.clear();
                        studentBatchFilter = 'All Batches';
                        studentGenderFilter = 'All Gender';
                        studentCurrentPage = 1;
                      });
                    },
                    child: const smcText(
                      textToDisplay: 'Reset',
                      textSize: 12,
                      textBoldness: 3,
                      colorOfText: Color(0xFF4F5E7D),
                    ),
                  ),
                );

                if (stackFilters) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: batchDropdown),
                          const SizedBox(width: 12),
                          Expanded(child: genderDropdown),
                          const SizedBox(width: 12),
                          resetButton,
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 3, child: searchField),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: batchDropdown),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: genderDropdown),
                    const SizedBox(width: 12),
                    resetButton,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE3EAF8)),
              ),
              child: totalRows == 0
                  ? const Center(
                      child: smcText(
                        textToDisplay: 'No students found.',
                        textSize: 13,
                        colorOfText: Color(0xFF8A96B2),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double tableWidth = constraints.maxWidth;
                              return SingleChildScrollView(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minWidth: tableWidth),
                                    child: DataTable(
                                    showCheckboxColumn: false,
                                    headingRowHeight: 50,
                                    dataRowMinHeight: 52,
                                    dataRowMaxHeight: 58,
                                    horizontalMargin: 0,
                                    columnSpacing: 0,
                                    dividerThickness: 1,
                                    border: TableBorder.all(color: const Color(0xFFE3EAF8), width: 1),
                                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF4F7FF)),
                                    columns: const [
                                      DataColumn(label: SizedBox(width: 50, child: Center(child: smcText(textToDisplay: 'S.No', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 100, child: Padding(padding: EdgeInsets.only(left: 8), child: Align(alignment: Alignment.centerLeft, child: smcText(textToDisplay: 'USN / ID', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B)))))),
                                      DataColumn(label: SizedBox(width: 200, child: Center(child: smcText(textToDisplay: 'Name', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 180, child: Center(child: smcText(textToDisplay: 'Email', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 110, child: Center(child: smcText(textToDisplay: 'Mobile #', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 90, child: Center(child: smcText(textToDisplay: 'Batch', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 90, child: Center(child: smcText(textToDisplay: 'Gender', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 80, child: Center(child: smcText(textToDisplay: 'Actions', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                    ],
                                    rows: pageRows.asMap().entries.map((entry) {
                                      final int index = entry.key;
                                      final StudentModel s = entry.value;
                                      final int serialNo = startIndex + index + 1;
                                      final bool isSelected = _isSelectedStudent(s);
                                      return DataRow(
                                        selected: isSelected,
                                        onSelectChanged: (_) => openStudentDetail(s),
                                        color: isSelected
                                            ? WidgetStateProperty.all(const Color(0xFFE8F0FE))
                                            : null,
                                        cells: [
                                          DataCell(
                                            Center(
                                              child: smcText(
                                                textToDisplay: '$serialNo',
                                                textSize: 12,
                                                colorOfText: const Color(0xFF2E3954),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Padding(
                                              padding: const EdgeInsets.only(left: 8),
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: smcText(
                                                  textToDisplay: s.studentId,
                                                  textSize: 12,
                                                  textBoldness: 4,
                                                  colorOfText: const Color(0xFF2E3954),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              child: Row(
                                                children: [
                                                  _buildStudentAvatar(s),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: smcText(
                                                      textToDisplay: s.fullName,
                                                      textSize: 12,
                                                      colorOfText: const Color(0xFF2E3954),
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Center(
                                              child: smcText(
                                                textToDisplay: s.email,
                                                textSize: 12,
                                                colorOfText: const Color(0xFF2E3954),
                                                maxLines: 1,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Center(
                                              child: smcText(
                                                textToDisplay: s.mobile,
                                                textSize: 12,
                                                colorOfText: const Color(0xFF2E3954),
                                                maxLines: 1,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Center(
                                              child: smcText(
                                                textToDisplay: s.batch.isEmpty ? '—' : s.batch,
                                                textSize: 12,
                                                colorOfText: const Color(0xFF2E3954),
                                                maxLines: 1,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Center(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(color: const Color(0xFFEFF4FF), borderRadius: BorderRadius.circular(999)),
                                                child: smcText(textToDisplay: s.gender, textSize: 11, textBoldness: 3, colorOfText: const Color(0xFF3558DA)),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Center(
                                              child: PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF8A96B2)),
                                                onSelected: (val) {
                                                  if (val == 'edit') openCreateStudentSheet(studentToEdit: s);
                                                  else if (val == 'delete') _deleteStudentWithConfirmation(s);
                                                },
                                                itemBuilder: (context) => [
                                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                                                ],
                                              ),
                                            ),
                                            onTap: () {},
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Pagination
                        Container(
                          height: 58,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: Color(0xFFE3EAF8))),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      smcText(
                                        textToDisplay: totalRows == 0
                                            ? 'Showing 0 entries'
                                            : 'Showing ${startIndex + 1} to $endIndex of $totalRows entries',
                                        textSize: 12,
                                        colorOfText: const Color(0xFF7D87A3),
                                      ),
                                      const SizedBox(width: 16),
                                      const smcText(textToDisplay: 'Rows per page:', textSize: 12, colorOfText: Color(0xFF7D87A3)),
                                      const SizedBox(width: 8),
                                      DropdownButton<int>(
                                        value: studentRowsPerPage,
                                        items: const [
                                          DropdownMenuItem(value: 10, child: Text('10')),
                                          DropdownMenuItem(value: 25, child: Text('25')),
                                          DropdownMenuItem(value: 50, child: Text('50')),
                                          DropdownMenuItem(value: 100, child: Text('100')),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              studentRowsPerPage = value;
                                              studentCurrentPage = 1;
                                            });
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        onPressed: safePage > 1 ? () => setState(() => studentCurrentPage = 1) : null,
                                        icon: const Icon(Icons.first_page_rounded),
                                      ),
                                      IconButton(
                                        onPressed: safePage > 1 ? () => setState(() => studentCurrentPage = safePage - 1) : null,
                                        icon: const Icon(Icons.chevron_left_rounded),
                                      ),
                                      Container(
                                        width: 34,
                                        height: 34,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(color: const Color(0xFFEAF0FF), borderRadius: BorderRadius.circular(8)),
                                        child: smcText(textToDisplay: '$safePage', textSize: 12, textBoldness: 4, colorOfText: ColorConst.primaryBlue),
                                      ),
                                      IconButton(
                                        onPressed: safePage < totalPages ? () => setState(() => studentCurrentPage = safePage + 1) : null,
                                        icon: const Icon(Icons.chevron_right_rounded),
                                      ),
                                      IconButton(
                                        onPressed: safePage < totalPages ? () => setState(() => studentCurrentPage = totalPages) : null,
                                        icon: const Icon(Icons.last_page_rounded),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCourseTable() {
    final String searchTerm = courseSearchController.text.trim().toLowerCase();
    final List<CourseModel> schemeFiltered = courseSchemeFilter == 'All Schemes'
        ? courseList
        : courseList.where((c) => c.batch == courseSchemeFilter).toList();
    final List<CourseModel> semesterFiltered = courseSemesterFilter == 'All Semesters'
        ? schemeFiltered
        : schemeFiltered.where((c) => c.semester == courseSemesterFilter).toList();
    final List<CourseModel> typeFiltered = courseTypeFilter == 'All Course Types'
        ? semesterFiltered
        : semesterFiltered.where((c) => c.courseType == courseTypeFilter).toList();
    final List<CourseModel> searched = typeFiltered.where((c) {
      if (searchTerm.isEmpty) return true;
      return '${c.courseCode} ${c.courseTitle} ${c.batch} ${c.semester} ${c.faculty} ${c.courseType}'
          .toLowerCase()
          .contains(searchTerm);
    }).toList()
      ..sort(
        (a, b) => a.courseTitle.toLowerCase().compareTo(b.courseTitle.toLowerCase()),
      );

    final int totalRows = searched.length;
    final int totalPages = totalRows == 0 ? 1 : ((totalRows - 1) ~/ courseRowsPerPage) + 1;
    final int safePage = courseCurrentPage.clamp(1, totalPages);
    final int startIndex = (safePage - 1) * courseRowsPerPage;
    final int endIndex = (startIndex + courseRowsPerPage).clamp(0, totalRows);
    final List<CourseModel> pageRows =
        totalRows == 0 ? <CourseModel>[] : searched.sublist(startIndex, endIndex);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4EBFB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.menu_book_rounded, color: ColorConst.primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: smcText(
                            textToDisplay: 'Courses',
                            textSize: 16,
                            textBoldness: 5,
                            colorOfText: Color(0xFF1F2F52),
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF4FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: smcText(
                            textToDisplay: '${courseList.length}',
                            textSize: 12,
                            textBoldness: 4,
                            colorOfText: ColorConst.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const smcText(
                      textToDisplay: 'View and manage all courses in your department.',
                      textSize: 12,
                      colorOfText: Color(0xFF7D87A3),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: openCreateCourse,
                    icon: const Icon(Icons.menu_book_rounded, size: 18, color: Colors.white),
                    label: const smcText(
                      textToDisplay: 'Create',
                      textSize: 14,
                      textBoldness: 4,
                      colorOfText: Colors.white,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorConst.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: onImportCourses,
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const smcText(
                      textToDisplay: 'Import',
                      textSize: 14,
                      textBoldness: 4,
                      colorOfText: ColorConst.primaryBlue,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColorConst.primaryBlue,
                      side: const BorderSide(color: ColorConst.primaryBlue),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFCFDFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8EDFA)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool stackFilters = constraints.maxWidth < 720;
                final Widget searchField = SizedBox(
                  height: 44,
                  child: TextField(
                    controller: courseSearchController,
                    onChanged: (_) => setState(() => courseCurrentPage = 1),
                    decoration: InputDecoration(
                      hintText: 'Search courses...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF8A96B2)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ColorConst.primaryBlue),
                      ),
                    ),
                  ),
                );
                final Widget schemeDropdown = SizedBox(
                  height: 44,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: courseSchemeFilter,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ColorConst.primaryBlue),
                      ),
                    ),
                    items: ['All Schemes', '2023', '2024', '2025', '2026', '2027']
                        .map(
                          (scheme) => DropdownMenuItem(
                            value: scheme,
                            child: Text(
                              scheme,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          courseSchemeFilter = v;
                          courseCurrentPage = 1;
                        });
                      }
                    },
                  ),
                );
                final Widget semesterDropdown = SizedBox(
                  height: 44,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: courseSemesterFilter,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ColorConst.primaryBlue),
                      ),
                    ),
                    items: ['All Semesters', 'I', 'II', 'III', 'IV']
                        .map(
                          (semester) => DropdownMenuItem(
                            value: semester,
                            child: Text(
                              semester,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          courseSemesterFilter = v;
                          courseCurrentPage = 1;
                        });
                      }
                    },
                  ),
                );
                final Widget courseTypeDropdown = SizedBox(
                  height: 44,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: courseTypeFilter,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ColorConst.primaryBlue),
                      ),
                    ),
                    items: [
                      'All Course Types',
                      'IPCC',
                      'PCC',
                      'PCCL',
                      'AEC',
                      'BSC',
                    ]
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(
                              type,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          courseTypeFilter = v;
                          courseCurrentPage = 1;
                        });
                      }
                    },
                  ),
                );
                final Widget resetButton = SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        courseSearchController.clear();
                        courseSchemeFilter = 'All Schemes';
                        courseSemesterFilter = 'All Semesters';
                        courseTypeFilter = 'All Course Types';
                        courseCurrentPage = 1;
                      });
                    },
                    child: const smcText(
                      textToDisplay: 'Reset',
                      textSize: 12,
                      textBoldness: 3,
                      colorOfText: Color(0xFF4F5E7D),
                    ),
                  ),
                );

                if (stackFilters) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: schemeDropdown),
                          const SizedBox(width: 12),
                          Expanded(child: semesterDropdown),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: courseTypeDropdown),
                          const SizedBox(width: 12),
                          resetButton,
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 3, child: searchField),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: schemeDropdown),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: semesterDropdown),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: courseTypeDropdown),
                    const SizedBox(width: 12),
                    resetButton,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE3EAF8)),
              ),
              child: totalRows == 0
                  ? const Center(
                      child: smcText(
                        textToDisplay: 'No courses found.',
                        textSize: 13,
                        colorOfText: Color(0xFF8A96B2),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double tableWidth = constraints.maxWidth;
                              const double minTableWidth = 720;

                              List<double> courseColumnWidths(double totalWidth) {
                                const flex = <double>[
                                  5,
                                  8,
                                  7,
                                  10,
                                  11,
                                  26,
                                  8,
                                  9,
                                  9,
                                  9,
                                  9,
                                ];
                                final double sum =
                                    flex.fold(0, (a, b) => a + b);
                                final List<double> widths = flex
                                    .map((f) => totalWidth * f / sum)
                                    .toList();
                                final double widthSum =
                                    widths.fold(0.0, (a, b) => a + b);
                                widths[widths.length - 1] +=
                                    totalWidth - widthSum;
                                return widths;
                              }

                              Widget buildCourseTable(double width) {
                                final List<double> colWidths =
                                    courseColumnWidths(width);
                                const Color borderColor = Color(0xFFE3EAF8);
                                const Color headerColor = Color(0xFFF4F7FF);
                                const double groupHeaderHeight = 30;
                                const double columnHeaderHeight = 44;
                                const double dataRowHeight = 52;

                                final double prefixColumnsWidth = colWidths
                                    .sublist(0, 7)
                                    .fold(0.0, (a, b) => a + b);
                                final double teachingHoursWidth = colWidths
                                    .sublist(7)
                                    .fold(0.0, (a, b) => a + b);

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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
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
                                }) {
                                  return Container(
                                    height: dataRowHeight,
                                    alignment: alignment,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 8,
                                    ),
                                    color: Colors.white,
                                    child: child,
                                  );
                                }

                                Widget teachingHoursDataCell(int hours) {
                                  return dataCell(
                                    smcText(
                                      textToDisplay: '$hours',
                                      textSize: 12,
                                      textBoldness: hours == 0 ? 1 : 5,
                                      colorOfText: const Color(0xFF2E3954),
                                      maxLines: 1,
                                    ),
                                  );
                                }

                                final List<TableRow> tableRows = [
                                  TableRow(
                                    decoration: const BoxDecoration(
                                      color: headerColor,
                                    ),
                                    children: List.generate(
                                      colWidths.length,
                                      (_) => const SizedBox(
                                        height: groupHeaderHeight,
                                      ),
                                    ),
                                  ),
                                  TableRow(
                                    decoration: const BoxDecoration(
                                      color: headerColor,
                                    ),
                                    children: [
                                      headerLabel('S.No'),
                                      headerLabel('Scheme'),
                                      headerLabel('Semester'),
                                      headerLabel('Course Type'),
                                      headerLabel(
                                        'Course Code',
                                        alignment: Alignment.centerLeft,
                                      ),
                                      headerLabel(
                                        'Course Title',
                                        alignment: Alignment.centerLeft,
                                      ),
                                      headerLabel('Credits'),
                                      headerLabel('Lecture'),
                                      headerLabel('Tutorial'),
                                      headerLabel('Practical'),
                                      headerLabel('Others'),
                                    ],
                                  ),
                                  ...pageRows.asMap().entries.map((entry) {
                                    final int index = entry.key;
                                    final CourseModel c = entry.value;
                                    final int serialNo = startIndex + index + 1;

                                    return TableRow(
                                      children: [
                                        dataCell(
                                          smcText(
                                            textToDisplay: '$serialNo',
                                            textSize: 12,
                                            colorOfText: const Color(0xFF2E3954),
                                          ),
                                        ),
                                        dataCell(
                                          smcText(
                                            textToDisplay: cellText(c.batch),
                                            textSize: 12,
                                            colorOfText: const Color(0xFF2E3954),
                                            maxLines: 1,
                                          ),
                                        ),
                                        dataCell(
                                          smcText(
                                            textToDisplay: cellText(c.semester),
                                            textSize: 12,
                                            colorOfText: const Color(0xFF2E3954),
                                            maxLines: 1,
                                          ),
                                        ),
                                        dataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF4FF),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: smcText(
                                              textToDisplay:
                                                  cellText(c.courseType),
                                              textSize: 11,
                                              textBoldness: 3,
                                              colorOfText: const Color(0xFF3558DA),
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                        dataCell(
                                          smcText(
                                            textToDisplay: cellText(c.courseCode),
                                            textSize: 12,
                                            textBoldness: 4,
                                            colorOfText: const Color(0xFF2E3954),
                                            maxLines: 1,
                                          ),
                                          alignment: Alignment.centerLeft,
                                        ),
                                        dataCell(
                                          smcText(
                                            textToDisplay: cellText(c.courseTitle),
                                            textSize: 12,
                                            colorOfText: const Color(0xFF2E3954),
                                            maxLines: 2,
                                          ),
                                          alignment: Alignment.centerLeft,
                                        ),
                                        dataCell(
                                          smcText(
                                            textToDisplay: cellText(c.credits),
                                            textSize: 12,
                                            colorOfText: const Color(0xFF2E3954),
                                            maxLines: 1,
                                          ),
                                        ),
                                        teachingHoursDataCell(c.lectureHrs),
                                        teachingHoursDataCell(c.tutorialHrs),
                                        teachingHoursDataCell(c.practicalHrs),
                                        teachingHoursDataCell(c.othersHrs),
                                      ],
                                    );
                                  }),
                                ];

                                return SizedBox(
                                  width: width,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Table(
                                        columnWidths: columnWidthsMap,
                                        border: TableBorder.all(
                                          color: borderColor,
                                          width: 1,
                                        ),
                                        defaultVerticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        children: tableRows,
                                      ),
                                      Positioned(
                                        left: prefixColumnsWidth,
                                        top: 0,
                                        width: teachingHoursWidth,
                                        height: groupHeaderHeight,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: headerColor,
                                            border: Border(
                                              left: BorderSide(
                                                color: borderColor,
                                              ),
                                              top: BorderSide(
                                                color: borderColor,
                                              ),
                                              right: BorderSide(
                                                color: borderColor,
                                              ),
                                              bottom: BorderSide(
                                                color: borderColor,
                                              ),
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: const smcText(
                                            textToDisplay:
                                                'Teaching Hours / Week',
                                            textSize: 12,
                                            textBoldness: 4,
                                            colorOfText: Color(0xFF5C6B8B),
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              if (tableWidth < minTableWidth) {
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: buildCourseTable(minTableWidth),
                                );
                              }

                              return SingleChildScrollView(
                                child: buildCourseTable(tableWidth),
                              );
                            },
                          ),
                        ),
                        Container(
                          height: 58,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: Color(0xFFE3EAF8))),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              smcText(
                                textToDisplay: totalRows == 0
                                    ? 'Showing 0 entries'
                                    : 'Showing ${startIndex + 1} to $endIndex of $totalRows entries',
                                        textSize: 12,
                                        colorOfText: const Color(0xFF7D87A3),
                                      ),
                                      const SizedBox(width: 16),
                                      const smcText(
                                        textToDisplay: 'Rows per page:',
                                        textSize: 12,
                                        colorOfText: Color(0xFF7D87A3),
                                      ),
                                      const SizedBox(width: 8),
                                      DropdownButton<int>(
                                        value: courseRowsPerPage,
                                        items: const [
                                          DropdownMenuItem(value: 10, child: Text('10')),
                                          DropdownMenuItem(value: 25, child: Text('25')),
                                          DropdownMenuItem(value: 50, child: Text('50')),
                                          DropdownMenuItem(value: 100, child: Text('100')),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              courseRowsPerPage = value;
                                              courseCurrentPage = 1;
                                            });
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        onPressed: safePage > 1
                                            ? () => setState(() => courseCurrentPage = 1)
                                            : null,
                                        icon: const Icon(Icons.first_page_rounded),
                                      ),
                                      IconButton(
                                        onPressed: safePage > 1
                                            ? () => setState(() => courseCurrentPage = safePage - 1)
                                            : null,
                                        icon: const Icon(Icons.chevron_left_rounded),
                                      ),
                                      Container(
                                        width: 34,
                                        height: 34,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEAF0FF),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: smcText(
                                          textToDisplay: '$safePage',
                                          textSize: 12,
                                          textBoldness: 4,
                                          colorOfText: ColorConst.primaryBlue,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: safePage < totalPages
                                            ? () => setState(() => courseCurrentPage = safePage + 1)
                                            : null,
                                        icon: const Icon(Icons.chevron_right_rounded),
                                      ),
                                      IconButton(
                                        onPressed: safePage < totalPages
                                            ? () => setState(() => courseCurrentPage = totalPages)
                                            : null,
                                        icon: const Icon(Icons.last_page_rounded),
                                      ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStudentWithConfirmation(StudentModel student) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Are you sure you want to delete ${student.fullName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true && student.documentId != null) {
      try {
        await studentService.deleteStudent(student.documentId!);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student deleted successfully')));
        refresh();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Faculty Table ───────────────────────────────────────────

  Widget buildFacultyTable() {
    final String searchTerm = facultySearchController.text.trim().toLowerCase();
    final List<FacultyModel> genderFiltered = facultyGenderFilter == 'All'
        ? facultyList
        : facultyList.where((f) => f.gender == facultyGenderFilter).toList();
    final List<FacultyModel> searched = genderFiltered.where((f) {
      if (searchTerm.isEmpty) return true;
      return '${f.facultyId} ${f.fullName} ${f.gender} ${f.email}'
          .toLowerCase()
          .contains(searchTerm);
    }).toList();

    final int totalRows = searched.length;
    final int totalPages = totalRows == 0 ? 1 : ((totalRows - 1) ~/ facultyRowsPerPage) + 1;
    final int safePage = facultyCurrentPage.clamp(1, totalPages);
    final int startIndex = (safePage - 1) * facultyRowsPerPage;
    final int endIndex = (startIndex + facultyRowsPerPage).clamp(0, totalRows);
    final List<FacultyModel> pageRows =
        totalRows == 0 ? <FacultyModel>[] : searched.sublist(startIndex, endIndex);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4EBFB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.people_alt_outlined, color: ColorConst.primaryBlue),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const smcText(
                        textToDisplay: 'Faculty List',
                        textSize: 16,
                        textBoldness: 5,
                        colorOfText: Color(0xFF1F2F52),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF4FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: smcText(
                          textToDisplay: '${facultyList.length}',
                          textSize: 12,
                          textBoldness: 4,
                          colorOfText: ColorConst.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const smcText(
                    textToDisplay: 'View and manage all faculty in your department.',
                    textSize: 12,
                    colorOfText: Color(0xFF7D87A3),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search and Filters
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFCFDFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8EDFA)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: facultySearchController,
                      onChanged: (_) => setState(() => facultyCurrentPage = 1),
                      decoration: InputDecoration(
                        hintText: 'Search faculty...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF8A96B2)),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: ColorConst.primaryBlue),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 44,
                    child: DropdownButtonFormField<String>(
                      value: facultyGenderFilter,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: ColorConst.primaryBlue),
                        ),
                      ),
                      items: ['All', 'Male', 'Female', 'Other', 'Prefer not to say']
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            facultyGenderFilter = v;
                            facultyCurrentPage = 1;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        facultySearchController.clear();
                        facultyGenderFilter = 'All';
                        facultyCurrentPage = 1;
                      });
                    },
                    child: const smcText(
                      textToDisplay: 'Reset',
                      textSize: 12,
                      textBoldness: 3,
                      colorOfText: Color(0xFF4F5E7D),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE3EAF8)),
              ),
              child: totalRows == 0
                  ? const Center(
                      child: smcText(
                        textToDisplay: 'No faculty found.',
                        textSize: 13,
                        colorOfText: Color(0xFF8A96B2),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double tableWidth = constraints.maxWidth;
                              return SingleChildScrollView(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minWidth: tableWidth),
                                    child: DataTable(
                                    showCheckboxColumn: false,
                                    headingRowHeight: 50,
                                    dataRowMinHeight: 52,
                                    dataRowMaxHeight: 58,
                                    horizontalMargin: 8,
                                    columnSpacing: 0,
                                    dividerThickness: 1,
                                    border: TableBorder.all(color: const Color(0xFFE3EAF8), width: 1),
                                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF4F7FF)),
                                    columns: const [
                                      DataColumn(label: SizedBox(width: 120, child: Center(child: smcText(textToDisplay: 'Faculty ID', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 180, child: Center(child: smcText(textToDisplay: 'Name', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 100, child: Center(child: smcText(textToDisplay: 'Gender', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 200, child: Center(child: smcText(textToDisplay: 'Email', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 100, child: Center(child: smcText(textToDisplay: 'Photo', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 80, child: Center(child: smcText(textToDisplay: 'Actions', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                    ],
                                    rows: pageRows.map((f) {
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Center(
                                              child: InkWell(
                                                onTap: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => PersonDetailPage(person: f, isStudent: false),
                                                  ),
                                                ),
                                                child: smcText(
                                                  textToDisplay: f.facultyId,
                                                  textSize: 12,
                                                  textBoldness: 4,
                                                  colorOfText: Colors.blue,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(Center(child: smcText(textToDisplay: f.fullName, textSize: 12, colorOfText: const Color(0xFF2E3954), maxLines: 1))),
                                          DataCell(
                                            Center(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(color: const Color(0xFFEFF4FF), borderRadius: BorderRadius.circular(999)),
                                                child: smcText(textToDisplay: f.gender, textSize: 11, textBoldness: 3, colorOfText: const Color(0xFF3558DA)),
                                              ),
                                            ),
                                          ),
                                          DataCell(Center(child: smcText(textToDisplay: f.email, textSize: 12, colorOfText: const Color(0xFF718096), maxLines: 1))),
                                          DataCell(
                                            Center(
                                              child: f.photographUrl.isNotEmpty
                                                  ? InkWell(
                                                      onTap: () async {
                                                        final uri = Uri.parse(f.photographUrl);
                                                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                                                      },
                                                      child: const Icon(Icons.image_outlined, size: 18, color: ColorConst.primaryBlue),
                                                    )
                                                  : const Icon(Icons.image_not_supported_outlined, size: 18, color: Colors.grey),
                                            ),
                                          ),
                                          DataCell(
                                            Center(
                                              child: PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF8A96B2)),
                                                onSelected: (val) {
                                                  if (val == 'edit') openCreateFacultySheet(facultyToEdit: f);
                                                  else if (val == 'delete') _deleteFacultyWithConfirmation(f);
                                                },
                                                itemBuilder: (context) => [
                                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Pagination
                        Container(
                          height: 58,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: Color(0xFFE3EAF8))),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      smcText(
                                        textToDisplay: totalRows == 0
                                            ? 'Showing 0 entries'
                                            : 'Showing ${startIndex + 1} to $endIndex of $totalRows entries',
                                        textSize: 12,
                                        colorOfText: const Color(0xFF7D87A3),
                                      ),
                                      const SizedBox(width: 16),
                                      const smcText(textToDisplay: 'Rows per page:', textSize: 12, colorOfText: Color(0xFF7D87A3)),
                                      const SizedBox(width: 8),
                                      DropdownButton<int>(
                                        value: facultyRowsPerPage,
                                        items: const [
                                          DropdownMenuItem(value: 10, child: Text('10')),
                                          DropdownMenuItem(value: 25, child: Text('25')),
                                          DropdownMenuItem(value: 50, child: Text('50')),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              facultyRowsPerPage = value;
                                              facultyCurrentPage = 1;
                                            });
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        onPressed: safePage > 1 ? () => setState(() => facultyCurrentPage = 1) : null,
                                        icon: const Icon(Icons.first_page_rounded),
                                      ),
                                      IconButton(
                                        onPressed: safePage > 1 ? () => setState(() => facultyCurrentPage = safePage - 1) : null,
                                        icon: const Icon(Icons.chevron_left_rounded),
                                      ),
                                      Container(
                                        width: 34,
                                        height: 34,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(color: const Color(0xFFEAF0FF), borderRadius: BorderRadius.circular(8)),
                                        child: smcText(textToDisplay: '$safePage', textSize: 12, textBoldness: 4, colorOfText: ColorConst.primaryBlue),
                                      ),
                                      IconButton(
                                        onPressed: safePage < totalPages ? () => setState(() => facultyCurrentPage = safePage + 1) : null,
                                        icon: const Icon(Icons.chevron_right_rounded),
                                      ),
                                      IconButton(
                                        onPressed: safePage < totalPages ? () => setState(() => facultyCurrentPage = totalPages) : null,
                                        icon: const Icon(Icons.last_page_rounded),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFacultyWithConfirmation(FacultyModel faculty) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Faculty'),
        content: Text('Are you sure you want to delete ${faculty.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && faculty.documentId != null) {
      try {
        await facultyService.deleteFaculty(faculty.documentId!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Faculty deleted successfully')),
        );
        refresh();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting faculty: $e')),
        );
      }
    }
  }

  Widget _menuTile({
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool sidebarExpanded,
    required VoidCallback onTap,
  }) {
    final Color iconColor =
        isSelected ? ColorConst.primaryBlue : ColorConst.textSecondary;
    final Color textColor =
        isSelected ? ColorConst.primaryBlue : ColorConst.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: sidebarExpanded ? 42 : 58,
        width: sidebarExpanded ? double.infinity : double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: sidebarExpanded ? 12 : 4,
          vertical: sidebarExpanded ? 0 : 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF0FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: sidebarExpanded
            ? Row(
                children: [
                  Icon(icon, size: 18, color: iconColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: smcText(
                      textToDisplay: title,
                      textSize: 14,
                      textBoldness: isSelected ? 4 : 3,
                      colorOfText: textColor,
                      maxLines: 1,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: iconColor),
                  const SizedBox(height: 4),
                  smcText(
                    textToDisplay: title,
                    textSize: 9,
                    textBoldness: isSelected ? 4 : 3,
                    colorOfText: textColor,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ],
              ),
      ),
    );
  }
}

class _StudentPhotoAvatar extends StatefulWidget {
  const _StudentPhotoAvatar({
    required this.photoUrl,
    this.fallbackInitial = '?',
    this.radius = 18,
    this.previewWidth,
    this.previewHeight,
  });

  final String photoUrl;
  final String fallbackInitial;
  final double radius;
  final double? previewWidth;
  final double? previewHeight;

  bool get isPreview => previewWidth != null && previewHeight != null;

  static final Map<String, Uint8List> _memoryCache = <String, Uint8List>{};

  static bool _isFirebaseStorageUrl(String url) {
    return url.startsWith('gs://') ||
        url.contains('firebasestorage.googleapis.com');
  }

  @override
  State<_StudentPhotoAvatar> createState() => _StudentPhotoAvatarState();
}

class _StudentPhotoAvatarState extends State<_StudentPhotoAvatar> {
  Uint8List? _photoBytes;
  bool _loading = true;
  bool _useCachedNetworkImage = false;
  bool _useNetworkImage = false;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant _StudentPhotoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _photoBytes = null;
      _loading = true;
      _useCachedNetworkImage = false;
      _useNetworkImage = false;
      _loadPhoto();
    }
  }

  Future<void> _loadPhoto() async {
    final String url = widget.photoUrl;

    if (url.isEmpty) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    final cached = _StudentPhotoAvatar._memoryCache[url];
    if (cached != null) {
      if (mounted) {
        setState(() {
          _photoBytes = cached;
          _loading = false;
        });
      }
      return;
    }

    // Flutter web fetch (getData / CachedNetworkImage) requires Storage CORS.
    // HTML <img> via Image.network does not.
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _loading = false;
          _useNetworkImage = true;
        });
      }
      return;
    }

    if (_StudentPhotoAvatar._isFirebaseStorageUrl(url)) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        final data = await ref.getData(3 * 1024 * 1024);
        if (!mounted) {
          return;
        }
        if (data != null && data.isNotEmpty) {
          _StudentPhotoAvatar._memoryCache[url] = data;
          setState(() {
            _photoBytes = data;
            _loading = false;
          });
          return;
        }
      } catch (_) {
        // Fall through to CachedNetworkImage.
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _useCachedNetworkImage = true;
    });
  }

  Widget _buildInitialAvatar() {
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: const Color(0xFFEAF0FF),
      child: Text(
        widget.fallbackInitial,
        style: const TextStyle(
          color: ColorConst.primaryBlue,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _previewFrame({required Widget child}) {
    return Container(
      width: widget.previewWidth,
      height: widget.previewHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorConst.borderSoft),
        color: const Color(0xFFF7F9FF),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildErrorPreview() {
    return _previewFrame(
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: ColorConst.textSecondary,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator({double? size}) {
    return SizedBox(
      width: size,
      height: size,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildMemoryImage() {
    if (widget.isPreview) {
      return _previewFrame(
        child: Image.memory(
          _photoBytes!,
          fit: BoxFit.cover,
        ),
      );
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: const Color(0xFFEAF0FF),
      backgroundImage: MemoryImage(_photoBytes!),
    );
  }

  Widget _buildNetworkImage() {
    Widget buildImage({double? width, double? height}) {
      return Image.network(
        widget.photoUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return _buildLoadingIndicator(size: width ?? height);
        },
        errorBuilder: (context, error, stackTrace) {
          if (widget.isPreview) {
            return const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: ColorConst.textSecondary,
              ),
            );
          }
          return _buildInitialAvatar();
        },
      );
    }

    if (widget.isPreview) {
      return _previewFrame(child: buildImage());
    }

    final double size = widget.radius * 2;
    return ClipOval(
      child: buildImage(width: size, height: size),
    );
  }

  Widget _buildCachedNetworkImage() {
    if (widget.isPreview) {
      return _previewFrame(
        child: CachedNetworkImage(
          imageUrl: widget.photoUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildLoadingIndicator(),
          errorWidget: (context, url, error) {
            return const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: ColorConst.textSecondary,
              ),
            );
          },
        ),
      );
    }

    final double size = widget.radius * 2;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: widget.photoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildLoadingIndicator(size: size),
        errorWidget: (context, url, error) => _buildInitialAvatar(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photoUrl.isEmpty) {
      return widget.isPreview ? _buildErrorPreview() : _buildInitialAvatar();
    }

    if (_photoBytes != null) {
      return _buildMemoryImage();
    }

    if (_loading) {
      return widget.isPreview
          ? _previewFrame(child: _buildLoadingIndicator())
          : _buildLoadingIndicator(size: widget.radius * 2);
    }

    if (_useNetworkImage) {
      return _buildNetworkImage();
    }

    if (_useCachedNetworkImage) {
      return _buildCachedNetworkImage();
    }

    return widget.isPreview ? _buildErrorPreview() : _buildInitialAvatar();
  }
}
