import 'package:flutter/material.dart';

/// ===================== MODEL =====================
class Course {
  String courseCode;
  String title;
  String type;
  String department;
  String program;
  String curriculum;

  Course({
    required this.courseCode,
    required this.title,
    required this.type,
    required this.department,
    required this.program,
    required this.curriculum,
  });
}

/// ===================== SERVICE =====================
class CourseService {
  final List<Course> _courses = [];

  List<Course> get courses => _courses;

  void addCourse(Course course) => _courses.add(course);

  void updateCourse(int index, Course course) =>
      _courses[index] = course;

  void deleteCourse(int index) => _courses.removeAt(index);
}

/// ===================== UI =====================
class CourseAdminPage extends StatefulWidget {
  const CourseAdminPage({super.key});

  @override
  State<CourseAdminPage> createState() => _CourseAdminPageState();
}

class _CourseAdminPageState extends State<CourseAdminPage> {
  final CourseService service = CourseService();

  /// ===================== ADD / EDIT =====================
  Future<void> openCourseDialog({Course? course, int? index}) async {
    final codeController =
    TextEditingController(text: course?.courseCode ?? '');
    final titleController =
    TextEditingController(text: course?.title ?? '');
    final deptController =
    TextEditingController(text: course?.department ?? '');

    String type = course?.type ?? 'Core';
    String program = course?.program ?? 'B.E';
    String curriculum =
        course?.curriculum ?? '2024-2026 Curriculum for MCA';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(course == null ? 'Add Course' : 'Edit Course'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    _textField(codeController, 'Course Code'),
                    _textField(titleController, 'Course Title'),
                    _textField(deptController, 'Department'),

                    _dropdown(
                      label: 'Course Type',
                      value: type,
                      items: ['Core', 'Elective', 'Open Elective'],
                      onChanged: (val) =>
                          setModalState(() => type = val!),
                    ),

                    _dropdown(
                      label: 'Program',
                      value: program,
                      items: ['B.E', 'MCA', 'MBA'],
                      onChanged: (val) =>
                          setModalState(() => program = val!),
                    ),

                    _dropdown(
                      label: 'Curriculum',
                      value: curriculum,
                      items: ['2024-2026 Curriculum for MCA'],
                      onChanged: (val) =>
                          setModalState(() => curriculum = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (codeController.text.isEmpty ||
                        titleController.text.isEmpty) {
                      return;
                    }

                    final newCourse = Course(
                      courseCode: codeController.text,
                      title: titleController.text,
                      type: type,
                      department: deptController.text,
                      program: program,
                      curriculum: curriculum,
                    );

                    setState(() {
                      if (course == null) {
                        service.addCourse(newCourse);
                      } else {
                        service.updateCourse(index!, newCourse);
                      }
                    });

                    Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// ===================== DELETE =====================
  void deleteCourse(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Course'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                service.deleteCourse(index);
              });
              Navigator.pop(context);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  /// ===================== VIEW =====================
  void viewCourse(Course c) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.title, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text('Code: ${c.courseCode}'),
            Text('Type: ${c.type}'),
            Text('Department: ${c.department}'),
            Text('Program: ${c.program}'),
            Text('Curriculum: ${c.curriculum}'),
          ],
        ),
      ),
    );
  }

  /// ===================== UI =====================
  @override
  Widget build(BuildContext context) {
    final courses = service.courses;

    return Scaffold(
      appBar: AppBar(title: const Text('Course Management')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// ADD BUTTON
            ElevatedButton.icon(
              onPressed: () => openCourseDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Course'),
            ),

            const SizedBox(height: 16),

            /// TABLE
            Expanded(
              child: courses.isEmpty
                  ? const Center(child: Text('No Courses Available'))
                  : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Code')),
                    DataColumn(label: Text('Title')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Department')),
                    DataColumn(label: Text('Program')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: courses.asMap().entries.map((entry) {
                    int i = entry.key;
                    Course c = entry.value;

                    return DataRow(
                      onSelectChanged: (_) => viewCourse(c),
                      cells: [
                        DataCell(Text(c.courseCode)),
                        DataCell(Text(c.title)),
                        DataCell(Text(c.type)),
                        DataCell(Text(c.department)),
                        DataCell(Text(c.program)),
                        DataCell(Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => openCourseDialog(
                                  course: c, index: i),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => deleteCourse(i),
                            ),
                          ],
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ===================== REUSABLE =====================
  Widget _textField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}