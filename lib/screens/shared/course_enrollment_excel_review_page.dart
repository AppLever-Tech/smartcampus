import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/services/course_firestore_service.dart';
import 'package:smartcampus/widgets/course_enroll_search_dialog.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class CourseEnrollmentExcelReviewPage extends StatefulWidget {
  final CourseModel course;
  final List<StudentModel> students;
  final StudentAvatarBuilder? studentAvatarBuilder;

  const CourseEnrollmentExcelReviewPage({
    super.key,
    required this.course,
    required this.students,
    this.studentAvatarBuilder,
  });

  @override
  State<CourseEnrollmentExcelReviewPage> createState() =>
      _CourseEnrollmentExcelReviewPageState();
}

class _CourseEnrollmentExcelReviewPageState
    extends State<CourseEnrollmentExcelReviewPage> {
  final Set<String> _selectedKeys = {};
  bool _loading = false;
  final TextEditingController _searchController =
  TextEditingController();

  late List<StudentModel> _filteredStudents;

  String _studentKey(StudentModel student) {
    return student.documentId?.isNotEmpty == true
        ? student.documentId!
        : student.studentId;
  }

  @override
  void initState() {
    super.initState();
    _filteredStudents = List.from(widget.students);
    for (final student in widget.students) {
      _selectedKeys.add(_studentKey(student));
    }
  }

  void _filterStudents(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredStudents = List.from(widget.students);
        return;
      }

      final search = query.toLowerCase();

      _filteredStudents = widget.students.where((student) {
        return student.fullName
            .toLowerCase()
            .contains(search) ||
            student.studentId
                .toLowerCase()
                .contains(search) ||
            student.batch
                .toLowerCase()
                .contains(search);
      }).toList();
    });
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectedKeys.clear();

      if (value == true) {
        for (final student in widget.students) {
          _selectedKeys.add(_studentKey(student));
        }
      }
    });
  }

  Widget _buildAvatar(StudentModel student) {
    if (widget.studentAvatarBuilder != null) {
      return widget.studentAvatarBuilder!(
        student,
        radius: 18,
      );
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFFEAF0FF),
      child: Text(
        student.fullName.isEmpty
            ? '?'
            : student.fullName[0].toUpperCase(),
        style: const TextStyle(
          color: ColorConst.primaryBlue,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _enrollSelectedStudents() async {
    if (_selectedKeys.isEmpty) return;

    setState(() {
      _loading = true;
    });

    try {
      await CourseFirestoreService().enrollStudents(
        widget.course.id,
        _selectedKeys.toList(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_selectedKeys.length} students enrolled successfully',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to enroll students: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool allSelected =
        _selectedKeys.length == widget.students.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(
          color: Color(0xFF1F2A44),
        ),
        title: const Text(
          'Review Enrollment',
          style: TextStyle(
            color: Color(0xFF1F2A44),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [

            /// COURSE CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE3EAF8),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [

                  Text(
                    widget.course.courseTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Course: ${widget.course.courseCode}',
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// SEARCH
            TextField(
              controller: _searchController,
              onChanged: _filterStudents,
              decoration: InputDecoration(
                hintText: 'Search students...',
                prefixIcon:
                const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,

                border: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(14),
                  borderSide:
                  const BorderSide(
                    color: Color(0xFFE3EAF8),
                  ),
                ),

                enabledBorder:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(14),
                  borderSide:
                  const BorderSide(
                    color: Color(0xFFE3EAF8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            /// HEADER
            Row(
              children: [

                Text(
            '${_selectedKeys.length} selected • ${_filteredStudents.length} students',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const Spacer(),

                Checkbox(
                  value: allSelected,
                  onChanged:
                  _toggleSelectAll,
                ),

                const Text('Select All'),
              ],
            ),

            const SizedBox(height: 12),

            /// STUDENT LIST
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.circular(16),
                  border: Border.all(
                    color:
                    const Color(0xFFE3EAF8),
                  ),
                ),

                child: ListView.separated(

                  itemCount: _filteredStudents.length,

                  separatorBuilder:
                      (_, __) =>
                  const Divider(
                    height: 1,
                  ),

                  itemBuilder:
                      (context, index) {
                        final student = _filteredStudents[index];

                    final key =
                    _studentKey(student);

                    return CheckboxListTile(
                      value:
                      _selectedKeys.contains(
                          key),

                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedKeys
                                .add(key);
                          } else {
                            _selectedKeys
                                .remove(key);
                          }
                        });
                      },

                      controlAffinity:
                      ListTileControlAffinity
                          .leading,

                      // secondary:
                      // _buildAvatar(
                      //   student,
                      // ),

                      title: Row(
                        children: [
                          _buildAvatar(student),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [

                                Text(
                                  student.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                Text(
                                  'USN: ${student.studentId} • Batch: ${student.batch}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                      },
                ),
              ),
            ),


            const SizedBox(height: 16),

            /// FOOTER BUTTONS
            Row(
              mainAxisAlignment:
              MainAxisAlignment.end,
              children: [

                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );
                  },
                  style:
                  OutlinedButton.styleFrom(
                    minimumSize:
                    const Size(
                      120,
                      50,
                    ),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius
                          .circular(
                        30,
                      ),
                    ),
                  ),
                  child:
                  const Text('Cancel'),
                ),

                const SizedBox(width: 12),

                // ElevatedButton(
                //   onPressed: _loading
                //       ? null
                //       : _enrollSelectedStudents,
                //
                //   style:
                //   ElevatedButton.styleFrom(
                //     backgroundColor:
                //     const Color(
                //         0xFFEDEEFF),
                //     foregroundColor:
                //     const Color(
                //         0xFF5065C8),
                //     elevation: 0,
                //     minimumSize:
                //     const Size(
                //       160,
                //       50,
                //     ),
                //     shape:
                //     RoundedRectangleBorder(
                //       borderRadius:
                //       BorderRadius
                //           .circular(
                //         30,
                //       ),
                //     ),
                //   ),
                //
                //   child: _loading
                //       ? const SizedBox(
                //     width: 20,
                //     height: 20,
                //     child:
                //     CircularProgressIndicator(
                //       strokeWidth:
                //       2,
                //     ),
                //   )
                //       : const Text(
                //     'Enroll students',
                //
                //   ),
                // ),
                OutlinedButton(
                  onPressed: _loading
                      ? null
                      : _enrollSelectedStudents,

                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(
                      160,
                      50,
                    ),

                    side: const BorderSide(
                      color: ColorConst.primaryBlue,
                      width: 1.5,
                    ),

                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(30),
                    ),
                  ),

                  child: _loading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Enroll Students',
                    style: TextStyle(
                      color: ColorConst.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              ],
            ),
          ],

        ),
      ),
    );
  }
}