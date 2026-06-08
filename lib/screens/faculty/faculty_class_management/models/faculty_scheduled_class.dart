import 'package:smartcampus/screens/faculty/faculty_class_management/models/faculty_assigned_class.dart';

class FacultyScheduledClass {
  final FacultyAssignedClass assignedClass;
  final DateTime scheduledDate;

  const FacultyScheduledClass({
    required this.assignedClass,
    required this.scheduledDate,
  });

  String get courseId => assignedClass.courseId;

  String get courseName => assignedClass.courseName;

  String get dayName => assignedClass.dayName;

  String get timeSlotName => assignedClass.timeSlotName;

  String get subtitle => assignedClass.subtitle;

  String get timeTableLabel => assignedClass.timeTableLabel;
}
