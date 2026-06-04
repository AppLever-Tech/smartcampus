import '../data/student_model.dart';

class StudentImportValidator {

  static List<String> validate(
      StudentModel student) {

    List<String> errors = [];

    if(student.studentId.isEmpty){
      errors.add("Student ID Missing");
    }

    if(student.fullName.isEmpty){
      errors.add("Name Missing");
    }

    if (student.mobile.trim().isEmpty) {
      errors.add('Mobile Missing');
    } else {
      final digits = student.mobile.replaceAll(RegExp(r'\D'), '');
      final bool validMobile = digits.length == 10 ||
          (digits.length == 12 && digits.startsWith('91'));
      if (!validMobile) {
        errors.add('Invalid Mobile');
      }
    }

    if (student.resolvedUuid.isEmpty) {
      errors.add('Invalid login UUID (check mobile number)');
    }

    if(!student.email.contains('@')){
      errors.add("Invalid Email");
    }

    return errors;
  }
}