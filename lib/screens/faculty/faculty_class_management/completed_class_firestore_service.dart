import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_date_utils.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_resolver.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/completed_class_record.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/faculty_scheduled_class.dart';

class CompletedClassFirestoreService {
  static List<CompletedClassRecord> filterForFaculty({
    required List<CompletedClassRecord> records,
    required FacultyModel faculty,
  }) {
    final facultyKeys = FacultyClassResolver.facultyKeysFor(faculty);

    return records.where((record) {
      return facultyKeys.contains(record.facultyUid.trim());
    }).toList();
  }

  static List<CompletedClassRecord> filterActiveForFaculty({
    required List<CompletedClassRecord> records,
    required FacultyModel faculty,
    DateTime? referenceDate,
  }) {
    final today = FacultyClassDateUtils.dateOnly(referenceDate ?? DateTime.now());

    return filterForFaculty(records: records, faculty: faculty).where((record) {
      return record.isActive &&
          FacultyClassDateUtils.isSameDay(record.classDate, today);
    }).toList();
  }

  static List<CompletedClassRecord> filterCompletedForFaculty({
    required List<CompletedClassRecord> records,
    required FacultyModel faculty,
  }) {
    return filterForFaculty(records: records, faculty: faculty)
        .where((record) => record.isCompleted)
        .toList();
  }

  static Set<String> activeSessionKeysForFaculty({
    required List<CompletedClassRecord> records,
    required FacultyModel faculty,
    DateTime? referenceDate,
  }) {
    return filterActiveForFaculty(
      records: records,
      faculty: faculty,
      referenceDate: referenceDate,
    )
        .map((record) => record.sessionKeyValue)
        .toSet();
  }

  static bool isScheduledClassActive({
    required CompletedClassRecord record,
    required FacultyScheduledClass scheduledClass,
  }) {
    final sessionKey = CompletedClassRecord.sessionKey(
      classDate: scheduledClass.scheduledDate,
      timeBlockUid: scheduledClass.assignedClass.block.id,
      timeTableUid: scheduledClass.assignedClass.block.timeTableUid,
      courseId: scheduledClass.courseId,
      batch: scheduledClass.assignedClass.batch,
      section: scheduledClass.assignedClass.section,
      semester: scheduledClass.assignedClass.semester,
      dayUid: scheduledClass.assignedClass.dayUid,
      dayName: scheduledClass.dayName,
      timeSlotUid: scheduledClass.assignedClass.timeSlotUid,
      timeSlotName: scheduledClass.timeSlotName,
    );
    return record.sessionKeyValue == sessionKey;
  }
}
