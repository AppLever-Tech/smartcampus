import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/screens/dept_admin/time_table/create_day_dialog.dart';
import 'package:smartcampus/screens/dept_admin/time_table/create_section_dialog.dart';
import 'package:smartcampus/screens/dept_admin/time_table/create_time_slot_dialog.dart';
import 'package:smartcampus/screens/dept_admin/time_table/days_settings_page.dart';
import 'package:smartcampus/screens/dept_admin/time_table/sections_settings_page.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_slots_settings_page.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_settings_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class TimeTableSettingsPage extends StatefulWidget {
  final String orgId;
  final String deptId;

  const TimeTableSettingsPage({
    super.key,
    required this.orgId,
    required this.deptId,
  });

  @override
  State<TimeTableSettingsPage> createState() => _TimeTableSettingsPageState();
}

class _TimeTableSettingsPageState extends State<TimeTableSettingsPage> {
  final TimeTableSettingsFirestoreService settingsService =
      TimeTableSettingsFirestoreService();

  int selectedSubFilter = 0; // 0: Days, 1: Time Slots, 2: Sections

  void _openCreateDialog(int index) {
    switch (index) {
      case 0:
        CreateDayDialog.show(
          context: context,
          orgId: widget.orgId,
          service: settingsService,
        );
      case 1:
        CreateTimeSlotDialog.show(
          context: context,
          orgId: widget.orgId,
          service: settingsService,
        );
      case 2:
        CreateSectionDialog.show(
          context: context,
          orgId: widget.orgId,
          service: settingsService,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSubFilterChip('Days', 0),
            _buildSubFilterChip('Time Slots', 1),
            _buildSubFilterChip('Sections', 2),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _buildSelectedSubPage(),
        ),
      ],
    );
  }

  Widget _buildSubFilterChip(String label, int index) {
    final bool isSelected = selectedSubFilter == index;
    return GestureDetector(
      onTap: () => setState(() => selectedSubFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? ColorConst.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? ColorConst.primaryBlue : const Color(0xFFE3EAF8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            smcText(
              textToDisplay: label,
              textSize: 14,
              textBoldness: isSelected ? 5 : 4,
              colorOfText: isSelected ? Colors.white : ColorConst.textSecondary,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _openCreateDialog(index),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.add,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedSubPage() {
    switch (selectedSubFilter) {
      case 1:
        return TimeSlotsSettingsPage(
          orgId: widget.orgId,
          settingsService: settingsService,
        );
      case 2:
        return SectionsSettingsPage(
          orgId: widget.orgId,
          settingsService: settingsService,
        );
      default:
        return DaysSettingsPage(
          orgId: widget.orgId,
          settingsService: settingsService,
        );
    }
  }
}
