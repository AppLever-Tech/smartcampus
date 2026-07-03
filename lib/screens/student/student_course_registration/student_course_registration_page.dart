import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/services/course_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class StudentCourseRegistrationPage extends StatefulWidget {
  final StudentModel student;
  final String orgId;
  final String? initialSemester;

  const StudentCourseRegistrationPage({
    super.key,
    required this.student,
    required this.orgId,
    this.initialSemester,
  });

  @override
  State<StudentCourseRegistrationPage> createState() => _StudentCourseRegistrationPageState();
}

class _StudentCourseRegistrationPageState extends State<StudentCourseRegistrationPage> {
  final CourseFirestoreService _courseService = CourseFirestoreService();

  List<CourseModel> _allCourses = [];
  List<CourseModel> _filteredCourses = [];
  List<String> _schemeOptions = [];
  
  String? _selectedScheme;
  String? _selectedSemester;
  
  // Track selected course IDs
  final Set<String> _selectedCourseIds = {};
  
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedSemester = widget.initialSemester ?? widget.student.currentSemester;
    _selectedScheme = widget.student.batch.isNotEmpty ? widget.student.batch : 'UGNEP2021';
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _loading = true);
    try {
      final coursesStream = _courseService.getCoursesForOrg(orgId: widget.orgId);
      final courses = await coursesStream.first;

      // Extract unique schemes (batches) from courses to populate scheme dropdown
      final schemes = courses.map((c) => c.batch.trim()).where((b) => b.isNotEmpty).toSet().toList();
      if (!schemes.contains(widget.student.batch) && widget.student.batch.isNotEmpty) {
        schemes.add(widget.student.batch);
      }
      schemes.sort();

      if (mounted) {
        setState(() {
          _allCourses = courses;
          _schemeOptions = schemes;
          // If selected scheme is not in list, pick student batch or first option
          if (!_schemeOptions.contains(_selectedScheme)) {
            _selectedScheme = widget.student.batch.isNotEmpty 
                ? widget.student.batch 
                : (_schemeOptions.isNotEmpty ? _schemeOptions.first : 'UGNEP2021');
          }
          _loading = false;
        });
        _filterCoursesAndInitializeSelection();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _filterCoursesAndInitializeSelection() {
    final studentKey = CourseFirestoreService.studentEnrollmentKey(widget.student);
    
    // Filter courses created by department admin for this particular scheme, semester and department
    final filtered = _allCourses.where((course) {
      // Check if scheme matches (handle cases like "2024" vs "2024-26")
      final courseScheme = course.batch.trim();
      final selectedScheme = _selectedScheme?.trim() ?? '';
      
      bool matchesScheme = false;
      if (courseScheme.isEmpty || selectedScheme.isEmpty) {
        matchesScheme = true;
      } else if (courseScheme == selectedScheme) {
        matchesScheme = true;
      } else if (selectedScheme.contains('-')) {
        // If selected scheme is like "2024-26", check if course scheme is the starting year like "2024"
        final schemeStart = selectedScheme.split('-')[0];
        if (courseScheme == schemeStart) {
          matchesScheme = true;
        }
      } else if (courseScheme.contains('-')) {
        // If course scheme is like "2024-26", check if selected scheme is the starting year like "2024"
        final courseStart = courseScheme.split('-')[0];
        if (courseStart == selectedScheme) {
          matchesScheme = true;
        }
      }
      
      // Check semester
      final matchesSemester = course.semester.trim().toUpperCase() == _selectedSemester?.trim().toUpperCase() || course.semester.isEmpty;
      
      // Check department
      final matchesDept = course.deptId.trim().toUpperCase() == widget.student.deptId.trim().toUpperCase() || course.deptId.isEmpty;
      
      return matchesScheme && matchesSemester;
    }).toList();

    // Reset and seed selections based on current enrollment in Firestore
    _selectedCourseIds.clear();
    for (final course in filtered) {
      if (course.enrolledStudentIds.contains(studentKey)) {
        _selectedCourseIds.add(course.id);
      }
    }

    setState(() {
      _filteredCourses = filtered;
    });
  }

  Future<void> _submitRegistration() async {
    setState(() => _submitting = true);
    try {
      final studentKey = CourseFirestoreService.studentEnrollmentKey(widget.student);

      // Iterate through the filtered courses to register/unregister the student
      for (final course in _filteredCourses) {
        final isSelected = _selectedCourseIds.contains(course.id);
        final list = List<String>.from(course.enrolledStudentIds);
        
        if (isSelected) {
          if (!list.contains(studentKey)) {
            list.add(studentKey);
            await _courseService.updateCourseFields(course.id, {
              'enrolled_student_ids': list,
            });
          }
        } else {
          if (list.contains(studentKey)) {
            list.remove(studentKey);
            await _courseService.updateCourseFields(course.id, {
              'enrolled_student_ids': list,
            });
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Course registration submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Pop with success result
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit course registration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildFieldLabel(String label) {
    return smcText(
      textToDisplay: label,
      textSize: 12,
      textBoldness: 3,
      colorOfText: ColorConst.textSecondary,
    );
  }

  Widget _buildPreFilledCard(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorConst.borderSoft),
      ),
      child: smcText(
        textToDisplay: value,
        textSize: 13,
        textBoldness: 2,
        colorOfText: ColorConst.textPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    final programName = student.deptId.toUpperCase() == 'MCA'
        ? 'Master of Computer Applications'
        : 'Master of Computer Applications (${student.deptId})';


    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const smcText(
          textToDisplay: 'Course Registration Portal',
          textSize: 18,
          textBoldness: 4,
          colorOfText: ColorConst.textPrimary,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: ColorConst.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFE3EAF8),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Registration Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Student Registration No'),
                                  const SizedBox(height: 6),
                                  _buildPreFilledCard(student.studentId),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Student Name'),
                                  const SizedBox(height: 6),
                                  _buildPreFilledCard(student.fullName),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Program Name'),
                                  const SizedBox(height: 6),
                                  _buildPreFilledCard(programName),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Scheme'),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _selectedScheme,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFFF9FAFD),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: ColorConst.borderSoft),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: ColorConst.borderSoft),
                                      ),
                                    ),
                                    items: _schemeOptions.map((scheme) {
                                      return DropdownMenuItem<String>(
                                        value: scheme,
                                        child: Text(scheme, style: const TextStyle(fontSize: 13, fontFamily: 'Poppins')),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedScheme = val;
                                      });
                                      _filterCoursesAndInitializeSelection();
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Term / Semester'),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _selectedSemester,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFFF9FAFD),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: ColorConst.borderSoft),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: ColorConst.borderSoft),
                                      ),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'I', child: Text('I Semester', style: TextStyle(fontSize: 13, fontFamily: 'Poppins'))),
                                      DropdownMenuItem(value: 'II', child: Text('II Semester', style: TextStyle(fontSize: 13, fontFamily: 'Poppins'))),
                                      DropdownMenuItem(value: 'III', child: Text('III Semester', style: TextStyle(fontSize: 13, fontFamily: 'Poppins'))),
                                      DropdownMenuItem(value: 'IV', child: Text('IV Semester', style: TextStyle(fontSize: 13, fontFamily: 'Poppins'))),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedSemester = val;
                                      });
                                      _filterCoursesAndInitializeSelection();
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Spacer(), // Balance row layout
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Courses List Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      smcText(
                        textToDisplay: 'Courses Available in Semester $_selectedSemester',
                        textSize: 16,
                        textBoldness: 4,
                        colorOfText: ColorConst.textPrimary,
                      ),
                      smcText(
                        textToDisplay: 'Selected: ${_selectedCourseIds.length} course(s)',
                        textSize: 13,
                        colorOfText: ColorConst.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Courses Table / List
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
                        child: _filteredCourses.isEmpty
                            ? const Center(
                                child: smcText(
                                  textToDisplay: 'No courses created by department admin for this scheme and semester.',
                                  textSize: 14,
                                  colorOfText: ColorConst.textSecondary,
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                ),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF4F7FF)),
                                    dividerThickness: 1,
                                    border: const TableBorder(
                                      horizontalInside: BorderSide(color: Color(0xFFE3EAF8)),
                                      verticalInside: BorderSide(color: Color(0xFFE3EAF8)),
                                    ),
                                    columns: const [
                                      DataColumn(label: SizedBox(width: 50, child: Center(child: smcText(textToDisplay: 'Select', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)))),
                                      DataColumn(label: smcText(textToDisplay: 'Course Code', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                                      DataColumn(label: smcText(textToDisplay: 'Course Title', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                                      DataColumn(label: smcText(textToDisplay: 'Course Type', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                                      DataColumn(label: smcText(textToDisplay: 'Credits', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                                      DataColumn(label: smcText(textToDisplay: 'CIE Marks', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                                      DataColumn(label: smcText(textToDisplay: 'SEE Marks', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                                      DataColumn(label: smcText(textToDisplay: 'Total Marks', textSize: 12, textBoldness: 3, colorOfText: ColorConst.textPrimary)),
                                    ],
                                    rows: _filteredCourses.map((course) {
                                      final isSelected = _selectedCourseIds.contains(course.id);
                                      return DataRow(
                                        selected: isSelected,
                                        cells: [
                                          DataCell(
                                            Center(
                                              child: Checkbox(
                                                value: isSelected,
                                                activeColor: ColorConst.primaryBlue,
                                                onChanged: (val) {
                                                  setState(() {
                                                    if (val == true) {
                                                      _selectedCourseIds.add(course.id);
                                                    } else {
                                                      _selectedCourseIds.remove(course.id);
                                                    }
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                          DataCell(smcText(textToDisplay: course.courseCode, textSize: 12, textBoldness: 2)),
                                          DataCell(smcText(textToDisplay: course.courseTitle, textSize: 12)),
                                          DataCell(smcText(textToDisplay: course.courseType, textSize: 12)),
                                          DataCell(Center(child: smcText(textToDisplay: course.credits, textSize: 12))),
                                          DataCell(Center(child: smcText(textToDisplay: '${course.cieMarks}', textSize: 12))),
                                          DataCell(Center(child: smcText(textToDisplay: '${course.seeMarks}', textSize: 12))),
                                          DataCell(Center(child: smcText(textToDisplay: '${course.totalMarks}', textSize: 12))),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Submit Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: _submitting ? null : () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: ColorConst.textPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: (_submitting || _filteredCourses.isEmpty) ? null : _submitRegistration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorConst.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Submit Registration', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
