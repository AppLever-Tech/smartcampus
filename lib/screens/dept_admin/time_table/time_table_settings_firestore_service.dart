import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartcampus/data/org_field.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_day.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_section.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_time_slot.dart';

class TimeTableSettingsFirestoreService {
  static const String collection = 'smcSystemSettings';
  static const String settingsForValue = 'time_table';
  static const String daysKey = 'days';
  static const String timeSlotsKey = 'time_slots';
  static const String sectionsKey = 'sections';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<Map<String, dynamic>?> watchSettings({
    required String orgId,
  }) {
    final orgNorm = OrgField.normalize(orgId);
    if (orgNorm.isEmpty) {
      return Stream.value(null);
    }

    return _firestore
        .collection(collection)
        .where('settings_for', isEqualTo: settingsForValue)
        .where(OrgField.orgIdKey, isEqualTo: orgNorm)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }
      return snapshot.docs.first.data();
    });
  }

  Future<DocumentReference<Map<String, dynamic>>> _getOrCreateDocRef({
    required String orgId,
  }) async {
    final orgNorm = OrgField.normalize(orgId);

    final snapshot = await _firestore
        .collection(collection)
        .where('settings_for', isEqualTo: settingsForValue)
        .where(OrgField.orgIdKey, isEqualTo: orgNorm)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.reference;
    }

    final docRef = _firestore.collection(collection).doc();
    await docRef.set({
      'settings_for': settingsForValue,
      OrgField.orgIdKey: orgNorm,
      daysKey: <Map<String, dynamic>>[],
      timeSlotsKey: <Map<String, dynamic>>[],
      sectionsKey: <Map<String, dynamic>>[],
    });
    return docRef;
  }

  Future<void> addDay({
    required String orgId,
    required TimeTableDay day,
  }) async {
    final docRef = await _getOrCreateDocRef(orgId: orgId);
    await docRef.update({
      daysKey: FieldValue.arrayUnion([day.toMap()]),
    });
  }

  Future<void> addTimeSlot({
    required String orgId,
    required TimeTableTimeSlot timeSlot,
  }) async {
    final docRef = await _getOrCreateDocRef(orgId: orgId);
    await docRef.update({
      timeSlotsKey: FieldValue.arrayUnion([timeSlot.toMap()]),
    });
  }

  Future<void> addSection({
    required String orgId,
    required TimeTableSection section,
  }) async {
    final docRef = await _getOrCreateDocRef(orgId: orgId);
    await docRef.update({
      sectionsKey: FieldValue.arrayUnion([section.toMap()]),
    });
  }

  Future<void> updateDay({
    required String orgId,
    required TimeTableDay day,
  }) async {
    final docRef = await _getOrCreateDocRef(orgId: orgId);
    final snapshot = await docRef.get();
    final days = parseDays(snapshot.data());
    final updated = days
        .map((entry) => entry.dayUid == day.dayUid ? day : entry)
        .map((entry) => entry.toMap())
        .toList();
    await docRef.update({daysKey: updated});
  }

  Future<void> deleteDay({
    required String orgId,
    required String dayUid,
  }) async {
    final docRef = await _getOrCreateDocRef(orgId: orgId);
    final snapshot = await docRef.get();
    final updated = parseDays(snapshot.data())
        .where((entry) => entry.dayUid != dayUid)
        .map((entry) => entry.toMap())
        .toList();
    await docRef.update({daysKey: updated});
  }

  Future<void> updateTimeSlot({
    required String orgId,
    required TimeTableTimeSlot timeSlot,
  }) async {
    final docRef = await _getOrCreateDocRef(orgId: orgId);
    final snapshot = await docRef.get();
    final slots = parseTimeSlots(snapshot.data());
    final updated = slots
        .map(
          (entry) =>
              entry.timeslotUid == timeSlot.timeslotUid ? timeSlot : entry,
        )
        .map((entry) => entry.toMap())
        .toList();
    await docRef.update({timeSlotsKey: updated});
  }

  Future<void> deleteTimeSlot({
    required String orgId,
    required String timeslotUid,
  }) async {
    final docRef = await _getOrCreateDocRef(orgId: orgId);
    final snapshot = await docRef.get();
    final updated = parseTimeSlots(snapshot.data())
        .where((entry) => entry.timeslotUid != timeslotUid)
        .map((entry) => entry.toMap())
        .toList();
    await docRef.update({timeSlotsKey: updated});
  }

  Future<void> updateSection({
    required String orgId,
    required TimeTableSection section,
  }) async {
    final docRef = await _getOrCreateDocRef(orgId: orgId);
    final snapshot = await docRef.get();
    final sections = parseSections(snapshot.data());
    final updated = sections
        .map(
          (entry) =>
              entry.sectionUid == section.sectionUid ? section : entry,
        )
        .map((entry) => entry.toMap())
        .toList();
    await docRef.update({sectionsKey: updated});
  }

  Future<void> deleteSection({
    required String orgId,
    required String sectionUid,
  }) async {
    final docRef = await _getOrCreateDocRef(orgId: orgId);
    final snapshot = await docRef.get();
    final updated = parseSections(snapshot.data())
        .where((entry) => entry.sectionUid != sectionUid)
        .map((entry) => entry.toMap())
        .toList();
    await docRef.update({sectionsKey: updated});
  }

  List<TimeTableDay> parseDays(Map<String, dynamic>? data) {
    if (data == null) {
      return const <TimeTableDay>[];
    }
    final raw = data[daysKey];
    if (raw is! List) {
      return const <TimeTableDay>[];
    }
    final days = raw
        .whereType<Map>()
        .map((entry) => TimeTableDay.fromMap(Map<String, dynamic>.from(entry)))
        .toList();
    days.sort((a, b) => a.dayOrder.compareTo(b.dayOrder));
    return days;
  }

  List<TimeTableTimeSlot> parseTimeSlots(Map<String, dynamic>? data) {
    if (data == null) {
      return const <TimeTableTimeSlot>[];
    }
    final raw = data[timeSlotsKey];
    if (raw is! List) {
      return const <TimeTableTimeSlot>[];
    }
    final slots = raw
        .whereType<Map>()
        .map(
          (entry) =>
              TimeTableTimeSlot.fromMap(Map<String, dynamic>.from(entry)),
        )
        .toList();
    slots.sort((a, b) => a.timeslotOrder.compareTo(b.timeslotOrder));
    return slots;
  }

  List<TimeTableSection> parseSections(Map<String, dynamic>? data) {
    if (data == null) {
      return const <TimeTableSection>[];
    }
    final raw = data[sectionsKey];
    if (raw is! List) {
      return const <TimeTableSection>[];
    }
    return raw
        .whereType<Map>()
        .map(
          (entry) =>
              TimeTableSection.fromMap(Map<String, dynamic>.from(entry)),
        )
        .toList()
      ..sort((a, b) => a.sectionName.compareTo(b.sectionName));
  }
}
