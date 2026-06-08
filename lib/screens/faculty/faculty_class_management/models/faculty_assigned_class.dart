import 'package:smartcampus/screens/dept_admin/time_table/models/time_block_record.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_record.dart';

class FacultyAssignedClass {
  final TimeBlockRecord block;
  final TimeTableRecord timeTable;

  const FacultyAssignedClass({
    required this.block,
    required this.timeTable,
  });

  String get semester => timeTable.semester.trim();

  String get scheme => timeTable.scheme.trim();

  String get batch => timeTable.batch.trim();

  String get section => timeTable.section.trim();

  String get courseId => block.courseId.trim();

  String get courseName => block.courseName.trim();

  String get dayName => block.dayName.trim();

  String get dayUid => block.dayUid.trim();

  String get timeSlotName => block.timeSlotName.trim();

  String get timeSlotUid => block.timeSlotUid.trim();

  String get timeTableLabel => timeTable.displayLabel;

  String get subtitle {
    final parts = <String>[
      if (dayName.isNotEmpty) dayName,
      if (timeSlotName.isNotEmpty) timeSlotName,
      if (batch.isNotEmpty) 'Batch $batch',
      if (section.isNotEmpty) 'Sec $section',
    ];
    return parts.join(' · ');
  }
}
