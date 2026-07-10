import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/services/course_firestore_service.dart';
import 'package:smartcampus/services/proctor_assignment_firestore_service.dart';
import 'package:smartcampus/services/student_firestore_service.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/class_attendance_firestore_service.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/completed_class_record.dart';
import 'package:smartcampus/screens/student/student_class_management/student_class_firestore_service.dart';
import 'package:smartcampus/widgets/profile_photo_avatar.dart';
import 'package:smartcampus/widgets/smc_text.dart';
import 'package:smartcampus/screens/shared/person_detail_page.dart';
import 'package:smartcampus/screens/faculty/proctor_meetings_tab.dart';

class FacultyProctoringPage extends StatefulWidget {
  final String orgId;
  final String deptId;
  final FacultyModel faculty;

  const FacultyProctoringPage({
    super.key,
    required this.orgId,
    required this.deptId,
    required this.faculty,
  });

  @override
  State<FacultyProctoringPage> createState() => _FacultyProctoringPageState();
}

class _FacultyProctoringPageState extends State<FacultyProctoringPage> {
  final ProctorAssignmentFirestoreService _proctorService =
      ProctorAssignmentFirestoreService();
  final StudentFirestoreService _studentService = StudentFirestoreService();
  final ClassAttendanceFirestoreService _classAttendanceService = ClassAttendanceFirestoreService();
  final CourseFirestoreService _courseService = CourseFirestoreService();
  final TextEditingController _searchController = TextEditingController();

  List<StudentModel> _assignedStudents = [];
  List<StudentModel> _filteredStudents = [];
  List<CourseModel> _allCourses = [];
  List<CompletedClassRecord> _allCompletedClasses = [];
  bool _loading = true;
  int _selectedTab = 0; // 0: Assigned Students, 1: Leaves and Requests
  int _rowsPerPage = 10;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterStudents);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredStudents = _assignedStudents;
        _currentPage = 1;
      });
    } else {
      setState(() {
        _filteredStudents = _assignedStudents.where((student) {
          return '${student.studentId} ${student.fullName} ${student.email} ${student.mobile} ${student.batch} ${student.gender}'
              .toLowerCase()
              .contains(query);
        }).toList();
        _currentPage = 1;
      });
    }
  }

  double _calculateAttendance(StudentModel student) {
    final studentClasses = StudentClassFirestoreService.filterCompletedForStudent(
      records: _allCompletedClasses,
      student: student,
      enrolledCourses: _allCourses,
    );

    int totalClasses = 0;
    int presentClasses = 0;
    for (final cls in studentClasses) {
      final status = StudentClassFirestoreService.attendanceStatusForStudent(
        record: cls,
        student: student,
      );
      if (status != null) {
        totalClasses++;
        if (status == 'Present') {
          presentClasses++;
        }
      }
    }

    return totalClasses == 0 ? 0.0 : (presentClasses / totalClasses) * 100;
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Load all students for the org and dept
      final allStudents = await _studentService.listStudentsForDept(
        orgId: widget.orgId,
        deptId: widget.deptId,
      );

      // Load proctor assignments
      final assignments = await _proctorService.listAssignmentsForDept(
        orgId: widget.orgId,
        deptId: widget.deptId,
      );

      final facultyId = ProctorAssignmentFirestoreService.normalizeFacultyId(
        widget.faculty.facultyId,
      );

      // Find assigned students
      final assignedDocIds = assignments[facultyId] ?? [];

      final studentsByDocId = <String, StudentModel>{};
      for (final student in allStudents) {
        final docId = student.documentId ?? '';
        if (docId.isNotEmpty) {
          studentsByDocId[docId] = student;
        }
      }

      final assignedStudents = assignedDocIds
          .map((docId) => studentsByDocId[docId])
          .whereType<StudentModel>()
          .toList();

      // Sort by name
      assignedStudents.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

      if (mounted) {
        setState(() {
          _assignedStudents = assignedStudents;
          _filteredStudents = assignedStudents;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ColorConst.primaryBlue,
                              ColorConst.primaryBlue.withOpacity(0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.supervisor_account_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const smcText(
                              textToDisplay: 'Proctoring',
                              textSize: 24,
                              textBoldness: 6,
                              colorOfText: ColorConst.textPrimary,
                            ),
                            const SizedBox(height: 2),
                            smcText(
                              textToDisplay: 'Manage your assigned students',
                              textSize: 14,
                              colorOfText: ColorConst.textSecondary,
                            ),
                          ],
                        ),
                      ),
                      // Refresh Button
                      IconButton(
                        onPressed: _loadData,
                        icon: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE4EBFB)),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: ColorConst.textSecondary,
                          size: 22,
                        ),
                      ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildTab(0, 'Assigned Students'),
                  const SizedBox(width: 12),
                  _buildTab(1, 'Meetings'),
                  const SizedBox(width: 12),
                  _buildTab(2, 'Leaves'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Tab Content
            Expanded(
              child: _buildTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? ColorConst.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? ColorConst.primaryBlue : const Color(0xFFE3EAF8),
          ),
        ),
        child: smcText(
          textToDisplay: label,
          textSize: 14,
          textBoldness: isSelected ? 5 : 4,
          colorOfText: isSelected ? Colors.white : ColorConst.textPrimary,
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildAssignedStudentsTab();
      case 1:
        return ProctorMeetingsTab(assignedStudents: _assignedStudents);
      case 2:
        return _buildLeavesTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAssignedStudentsTab() {
    return StreamBuilder<List<CourseModel>>(
      stream: _courseService.getCoursesForOrg(orgId: widget.orgId),
      builder: (context, coursesSnapshot) {
        if (coursesSnapshot.connectionState == ConnectionState.waiting && !coursesSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final courses = coursesSnapshot.data ?? [];
        return StreamBuilder<List<CompletedClassRecord>>(
          stream: _classAttendanceService.watchClassesForOrg(orgId: widget.orgId),
          builder: (context, classesSnapshot) {
            if (classesSnapshot.connectionState == ConnectionState.waiting && !classesSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final classes = classesSnapshot.data ?? [];

            if (!listEquals(_allCourses, courses) || !listEquals(_allCompletedClasses, classes)) {
              Future.microtask(() {
                if (mounted) {
                  setState(() {
                    _allCourses = courses;
                    _allCompletedClasses = classes;
                  });
                }
              });
            }

            if (_loading) {
              return const Center(child: CircularProgressIndicator());
            }

            final int totalRows = _filteredStudents.length;
            final int totalPages = totalRows == 0 ? 1 : ((totalRows - 1) ~/ _rowsPerPage) + 1;
            final int safePage = _currentPage.clamp(1, totalPages);
            final int startIndex = (safePage - 1) * _rowsPerPage;
            final int endIndex = (startIndex + _rowsPerPage).clamp(0, totalRows);
            final List<StudentModel> pageRows = totalRows == 0 ? <StudentModel>[] : _filteredStudents.sublist(startIndex, endIndex);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
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
                  child: const Icon(Icons.supervisor_account_outlined, color: ColorConst.primaryBlue),
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
                              textToDisplay: 'Assigned Students',
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
                              textToDisplay: '${_assignedStudents.length}',
                              textSize: 12,
                              textBoldness: 4,
                              colorOfText: ColorConst.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const smcText(
                        textToDisplay: 'View your assigned students.',
                        textSize: 12,
                        colorOfText: Color(0xFF7D87A3),
                        maxLines: 2,
                      ),
                    ],
                  ),
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
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => _filterStudents(),
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
                                          DataColumn(label: SizedBox(width: 100, child: Center(child: smcText(textToDisplay: 'Attendance', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
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
                                          final double attendance = _calculateAttendance(s);
                                          return DataRow(
                                            onSelectChanged: (_) => _openStudentDetail(s),
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
                                                      ProfilePhotoAvatar(
                                                        photoUrl: s.photographUrl,
                                                        fallbackInitial: s.fullName.trim().isEmpty ? 'S' : s.fullName.trim().substring(0, 1).toUpperCase(),
                                                        radius: 18,
                                                      ),
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
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                    decoration: BoxDecoration(
                                                      color: attendance >= 75
                                                          ? const Color(0xFFE8F5E9)
                                                          : attendance >= 60
                                                              ? const Color(0xFFFFF8E1)
                                                              : const Color(0xFFFFEBEE),
                                                      borderRadius: BorderRadius.circular(999),
                                                    ),
                                                    child: smcText(
                                                      textToDisplay: '${attendance.toStringAsFixed(1)}%',
                                                      textSize: 11,
                                                      textBoldness: 4,
                                                      colorOfText: attendance >= 75
                                                          ? const Color(0xFF2E7D32)
                                                          : attendance >= 60
                                                              ? const Color(0xFFF57C00)
                                                              : const Color(0xFFC62828),
                                                    ),
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
                                                  child: IconButton(
                                                    icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF8A96B2)),
                                                    onPressed: () => _openStudentDetail(s),
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
                                          value: _rowsPerPage,
                                          items: const [
                                            DropdownMenuItem(value: 10, child: Text('10')),
                                            DropdownMenuItem(value: 25, child: Text('25')),
                                            DropdownMenuItem(value: 50, child: Text('50')),
                                            DropdownMenuItem(value: 100, child: Text('100')),
                                          ],
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(() {
                                                _rowsPerPage = value;
                                                _currentPage = 1;
                                              });
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        IconButton(
                                          onPressed: safePage > 1 ? () => setState(() => _currentPage = 1) : null,
                                          icon: const Icon(Icons.first_page_rounded),
                                        ),
                                        IconButton(
                                          onPressed: safePage > 1 ? () => setState(() => _currentPage = safePage - 1) : null,
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
                                          onPressed: safePage < totalPages ? () => setState(() => _currentPage = safePage + 1) : null,
                                          icon: const Icon(Icons.chevron_right_rounded),
                                        ),
                                        IconButton(
                                          onPressed: safePage < totalPages ? () => setState(() => _currentPage = totalPages) : null,
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
      ),
          );
          }
        );
      }
    );
  }



  void _openStudentDetail(StudentModel student) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PersonDetailPage(
          key: ValueKey<String>(student.documentId ?? student.studentId),
          person: student,
          isStudent: true,
          embedded: false,
          embeddedMaximized: false,
          showLeadingAction: true,
          showEmbeddedHeader: false,
          customTabLabels: const [
            'Basic Details',
            'Academic Performance',
            'Attendance',
            'Co & Extra Activities',
          ],
        ),
      ),
    );
  }

  Widget _buildLeavesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leaves Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFFA726).withOpacity(0.15),
                            const Color(0xFFFFA726).withOpacity(0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.event_note_outlined,
                        color: Color(0xFFFFA726),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const smcText(
                      textToDisplay: 'Leaves',
                      textSize: 18,
                      textBoldness: 6,
                      colorOfText: ColorConst.textPrimary,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_note_outlined,
                          size: 56,
                          color: ColorConst.textSecondary.withOpacity(0.4),
                        ),
                        const SizedBox(height: 16),
                        smcText(
                          textToDisplay: 'No leave applications yet',
                          textSize: 14,
                          colorOfText: ColorConst.textSecondary,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
