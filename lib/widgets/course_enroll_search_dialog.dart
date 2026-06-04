import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/widgets/smc_text.dart';

typedef StudentAvatarBuilder = Widget Function(
  StudentModel student, {
  double radius,
});

class CourseEnrollSearchDialog extends StatefulWidget {
  const CourseEnrollSearchDialog({
    super.key,
    required this.students,
    this.studentAvatarBuilder,
  });

  final List<StudentModel> students;
  final StudentAvatarBuilder? studentAvatarBuilder;

  @override
  State<CourseEnrollSearchDialog> createState() =>
      _CourseEnrollSearchDialogState();
}

class _CourseEnrollSearchDialogState extends State<CourseEnrollSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedKeys = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _studentKey(StudentModel student) {
    return student.documentId?.isNotEmpty == true
        ? student.documentId!
        : student.studentId;
  }

  Widget _buildAvatar(StudentModel student) {
    if (widget.studentAvatarBuilder != null) {
      return widget.studentAvatarBuilder!(student, radius: 18);
    }
    final String initial = student.fullName.trim().isEmpty
        ? '?'
        : student.fullName.trim().substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFFEAF0FF),
      child: Text(
        initial,
        style: const TextStyle(
          color: ColorConst.primaryBlue,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String searchTerm = _searchController.text.trim().toLowerCase();
    final List<StudentModel> filtered = widget.students.where((student) {
      if (searchTerm.isEmpty) {
        return true;
      }
      return '${student.studentId} ${student.fullName} ${student.email} ${student.mobile} ${student.batch}'
          .toLowerCase()
          .contains(searchTerm);
    }).toList()
      ..sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: smcText(
                      textToDisplay: 'Search & Enroll Students',
                      textSize: 18,
                      textBoldness: 5,
                      colorOfText: ColorConst.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search students...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
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
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: smcText(
                textToDisplay:
                    '${_selectedKeys.length} selected · ${filtered.length} shown',
                textSize: 12,
                colorOfText: ColorConst.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: smcText(
                        textToDisplay: 'No students available to enroll.',
                        textSize: 13,
                        colorOfText: ColorConst.textSecondary,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final StudentModel student = filtered[index];
                        final String key = _studentKey(student);
                        final bool isSelected = _selectedKeys.contains(key);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedKeys.add(key);
                              } else {
                                _selectedKeys.remove(key);
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Row(
                            children: [
                              _buildAvatar(student),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    smcText(
                                      textToDisplay: student.fullName,
                                      textSize: 13,
                                      textBoldness: 4,
                                      colorOfText: ColorConst.textPrimary,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 2),
                                    smcText(
                                      textToDisplay:
                                          'USN: ${student.studentId} · ${student.batch.isEmpty ? '—' : student.batch}',
                                      textSize: 12,
                                      colorOfText: ColorConst.textSecondary,
                                      maxLines: 1,
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE3EAF8))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedKeys.isEmpty
                        ? null
                        : () {
                            final List<StudentModel> selected = widget.students
                                .where(
                                  (student) =>
                                      _selectedKeys.contains(_studentKey(student)),
                                )
                                .toList();
                            Navigator.pop(context, selected);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorConst.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: smcText(
                      textToDisplay:
                          'Enroll (${_selectedKeys.length})',
                      textSize: 14,
                      textBoldness: 4,
                      colorOfText: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
