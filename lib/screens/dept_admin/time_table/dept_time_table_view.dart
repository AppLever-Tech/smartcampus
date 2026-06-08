import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_settings_page.dart';
import 'package:smartcampus/screens/dept_admin/time_table/view_time_tables_page.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class DeptTimeTableView extends StatefulWidget {
  final String orgId;
  final String deptId;

  const DeptTimeTableView({
    super.key,
    required this.orgId,
    required this.deptId,
  });

  @override
  State<DeptTimeTableView> createState() => _DeptTimeTableViewState();
}

class _DeptTimeTableViewState extends State<DeptTimeTableView> {
  int selectedFilter = 0; // 0: View Time Tables, 1: Time Table Settings

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4EBFB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.calendar_month_outlined,
                  color: ColorConst.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    smcText(
                      textToDisplay: 'Time Table Management',
                      textSize: 16,
                      textBoldness: 5,
                      colorOfText: Color(0xFF1F2F52),
                      maxLines: 1,
                    ),
                    SizedBox(height: 2),
                    smcText(
                      textToDisplay:
                          'Create and manage class schedules for your department.',
                      textSize: 12,
                      colorOfText: Color(0xFF7D87A3),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildFilterChip('View Time Tables', 0),
              const SizedBox(width: 8),
              _buildFilterChip('Time Table Settings', 1),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildSelectedPage(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final bool isSelected = selectedFilter == index;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = index),
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

  Widget _buildSelectedPage() {
    switch (selectedFilter) {
      case 1:
        return TimeTableSettingsPage(
          orgId: widget.orgId,
          deptId: widget.deptId,
        );
      default:
        return ViewTimeTablesPage(
          orgId: widget.orgId,
        );
    }
  }
}
