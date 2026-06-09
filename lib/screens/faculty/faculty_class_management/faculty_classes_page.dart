import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_block_record.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_day.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_record.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_time_slot.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_block_firestore_service.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_firestore_service.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_settings_firestore_service.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/class_attendance_firestore_service.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_active_tab.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_class_resolver.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_completed_tab.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_timetable_tab.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/faculty_upcoming_tab.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/completed_class_record.dart';
import 'package:smartcampus/screens/faculty/faculty_class_management/models/faculty_assigned_class.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class FacultyClassesPage extends StatefulWidget {
  final String orgId;
  final FacultyModel faculty;
  final List<CourseModel> assignedCourses;

  const FacultyClassesPage({
    super.key,
    required this.orgId,
    required this.faculty,
    required this.assignedCourses,
  });

  @override
  State<FacultyClassesPage> createState() => _FacultyClassesPageState();
}

class _FacultyClassesPageState extends State<FacultyClassesPage> {
  final TimeBlockFirestoreService _timeBlockService = TimeBlockFirestoreService();
  final TimeTableFirestoreService _timeTableService = TimeTableFirestoreService();
  final TimeTableSettingsFirestoreService _settingsService =
      TimeTableSettingsFirestoreService();
  final ClassAttendanceFirestoreService _classService =
      ClassAttendanceFirestoreService();

  StreamSubscription<List<TimeBlockRecord>>? _timeBlockSubscription;
  StreamSubscription<List<TimeTableRecord>>? _timeTableSubscription;
  StreamSubscription<Map<String, dynamic>?>? _settingsSubscription;
  StreamSubscription<List<CompletedClassRecord>>? _classSubscription;

  List<TimeBlockRecord> _timeBlocks = const [];
  List<TimeTableRecord> _timeTables = const [];
  List<TimeTableDay> _timetableDays = const [];
  List<TimeTableTimeSlot> _timeSlots = const [];
  List<CompletedClassRecord> _classRecords = const [];
  bool _initialLoading = true;
  int _selectedFilter = 0;

  @override
  void initState() {
    super.initState();
    _bindListeners();
  }

  @override
  void dispose() {
    _timeBlockSubscription?.cancel();
    _timeTableSubscription?.cancel();
    _settingsSubscription?.cancel();
    _classSubscription?.cancel();
    super.dispose();
  }

  void _bindListeners() {
    _timeBlockSubscription?.cancel();
    _timeTableSubscription?.cancel();
    _settingsSubscription?.cancel();
    _classSubscription?.cancel();

    var pendingStreams = 4;
    void markStreamReady() {
      pendingStreams--;
      if (pendingStreams <= 0 && mounted) {
        setState(() => _initialLoading = false);
      }
    }

    _timeBlockSubscription = _timeBlockService
        .watchTimeBlocksForOrg(orgId: widget.orgId)
        .listen((blocks) {
      if (!mounted) {
        return;
      }
      setState(() => _timeBlocks = blocks);
      markStreamReady();
    });

    _timeTableSubscription = _timeTableService
        .watchTimeTables(orgId: widget.orgId)
        .listen((tables) {
      if (!mounted) {
        return;
      }
      setState(() => _timeTables = tables);
      markStreamReady();
    });

    _settingsSubscription = _settingsService
        .watchSettings(orgId: widget.orgId)
        .listen((settings) {
      if (!mounted) {
        return;
      }
      setState(() {
        _timetableDays = _settingsService.parseDays(settings);
        _timeSlots = _settingsService.parseTimeSlots(settings);
      });
      markStreamReady();
    });

    _classSubscription = _classService
        .watchClassesForOrg(orgId: widget.orgId)
        .listen((records) {
      if (!mounted) {
        return;
      }
      setState(() => _classRecords = records);
      markStreamReady();
    });
  }

  List<FacultyAssignedClass> get _assignedClasses {
    return FacultyClassResolver.resolveAssignedClasses(
      timeBlocks: _timeBlocks,
      timeTables: _timeTables,
      faculty: widget.faculty,
      assignedCourses: widget.assignedCourses,
      timetableDays: _timetableDays,
      timeSlots: _timeSlots,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const smcText(
          textToDisplay: 'My Classes',
          textSize: 20,
          textBoldness: 5,
          colorOfText: ColorConst.textPrimary,
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('Upcoming', 0),
              const SizedBox(width: 8),
              _buildFilterChip('Active', 1),
              const SizedBox(width: 8),
              _buildFilterChip('Completed', 2),
              const SizedBox(width: 8),
              _buildFilterChip('Time Table', 3),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildSelectedTab()),
      ],
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? ColorConst.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? ColorConst.primaryBlue : const Color(0xFFE3EAF8),
          ),
        ),
        child: smcText(
          textToDisplay: label,
          textSize: 14,
          textBoldness: isSelected ? 5 : 4,
          colorOfText: isSelected ? Colors.white : ColorConst.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedFilter) {
      case 1:
        return FacultyActiveTab(
          orgId: widget.orgId,
          faculty: widget.faculty,
          assignedCourses: widget.assignedCourses,
          classRecords: _classRecords,
          timeSlots: _timeSlots,
        );
      case 2:
        return FacultyCompletedTab(
          orgId: widget.orgId,
          faculty: widget.faculty,
          assignedCourses: widget.assignedCourses,
          classRecords: _classRecords,
          timeSlots: _timeSlots,
        );
      case 3:
        return FacultyTimetableTab(
          assignedClasses: _assignedClasses,
          faculty: widget.faculty,
          assignedCourses: widget.assignedCourses,
        );
      default:
        return FacultyUpcomingTab(
          orgId: widget.orgId,
          faculty: widget.faculty,
          assignedClasses: _assignedClasses,
          assignedCourses: widget.assignedCourses,
          timetableDays: _timetableDays,
          timeSlots: _timeSlots,
          classRecords: _classRecords,
        );
    }
  }
}
