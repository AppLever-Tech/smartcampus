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

    if(student.mobile.length != 10){
      errors.add("Invalid Mobile");
    }

    if(!student.email.contains('@')){
      errors.add("Invalid Email");
    }

    return errors;
  }
}