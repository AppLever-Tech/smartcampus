import '../data/student_model.dart';

class StudentImportRow {
  final StudentModel student;

  final List<String> errors;

  bool selected;

  bool overwrite;

  bool existsInSystem;

  StudentImportRow({
    required this.student,
    required this.errors,
    this.selected = true,
    this.overwrite = false,
    this.existsInSystem = false,
  });

  bool get hasError => errors.isNotEmpty;
}