import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/screens/dept_admin/time_table/create_time_table_dialog.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_record.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_detail_page.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_firestore_service.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_settings_firestore_service.dart';
import 'package:smartcampus/services/settings_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class ViewTimeTablesPage extends StatefulWidget {
  final String orgId;

  const ViewTimeTablesPage({
    super.key,
    required this.orgId,
  });

  @override
  State<ViewTimeTablesPage> createState() => _ViewTimeTablesPageState();
}

class _ViewTimeTablesPageState extends State<ViewTimeTablesPage> {
  final TimeTableFirestoreService timeTableService = TimeTableFirestoreService();
  final TimeTableSettingsFirestoreService settingsService =
      TimeTableSettingsFirestoreService();
  final SettingsFirestoreService masterSettingsService =
      SettingsFirestoreService();

  String schemeFilter = 'All Schemes';
  String batchFilter = 'All Batches';
  String semesterFilter = 'All Semesters';

  void _openTimeTable(TimeTableRecord timeTable) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TimeTableDetailPage(timeTable: timeTable),
      ),
    );
  }

  void _openCreateDialog() {
    CreateTimeTableDialog.show(
      context: context,
      orgId: widget.orgId,
      timeTableService: timeTableService,
      settingsService: settingsService,
      masterSettingsService: masterSettingsService,
    );
  }

  List<String> _uniqueSortedValues(
    List<TimeTableRecord> timeTables,
    String Function(TimeTableRecord) readValue,
  ) {
    return timeTables
        .map(readValue)
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<TimeTableRecord> _filterTimeTables(List<TimeTableRecord> timeTables) {
    return timeTables.where((timeTable) {
      if (schemeFilter != 'All Schemes' && timeTable.scheme != schemeFilter) {
        return false;
      }
      if (batchFilter != 'All Batches' && timeTable.batch != batchFilter) {
        return false;
      }
      if (semesterFilter != 'All Semesters' &&
          timeTable.semester != semesterFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    final safeValue = options.contains(value) ? value : options.first;

    return SizedBox(
      height: 44,
      width: 160,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: safeValue,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColorConst.primaryBlue),
          ),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTimeTableList(List<TimeTableRecord> filteredTimeTables) {
    return ListView.separated(
      itemCount: filteredTimeTables.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final timeTable = filteredTimeTables[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openTimeTable(timeTable),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFCFDFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8EDFA)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF0FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.table_chart_outlined,
                      size: 16,
                      color: ColorConst.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        smcText(
                          textToDisplay: timeTable.displayLabel,
                          textSize: 14,
                          textBoldness: 4,
                          colorOfText: ColorConst.textPrimary,
                          maxLines: 2,
                        ),
                        if (timeTable.timeTableUid.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          smcText(
                            textToDisplay: timeTable.timeTableUid,
                            textSize: 12,
                            colorOfText: ColorConst.textSecondary,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: ColorConst.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TimeTableRecord>>(
      stream: timeTableService.watchTimeTables(orgId: widget.orgId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final timeTables = snapshot.data ?? const [];
        final schemeOptions = [
          'All Schemes',
          ..._uniqueSortedValues(timeTables, (table) => table.scheme),
        ];
        final batchOptions = [
          'All Batches',
          ..._uniqueSortedValues(timeTables, (table) => table.batch),
        ];
        final semesterOptions = [
          'All Semesters',
          ..._uniqueSortedValues(timeTables, (table) => table.semester),
        ];
        final filteredTimeTables = _filterTimeTables(timeTables);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const smcText(
                  textToDisplay: 'Time Tables',
                  textSize: 15,
                  textBoldness: 5,
                  colorOfText: ColorConst.textPrimary,
                ),
                const SizedBox(width: 12),
                _buildFilterDropdown(
                  label: 'Scheme',
                  value: schemeFilter,
                  options: schemeOptions,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => schemeFilter = value);
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterDropdown(
                  label: 'Batch',
                  value: batchFilter,
                  options: batchOptions,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => batchFilter = value);
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterDropdown(
                  label: 'Semester',
                  value: semesterFilter,
                  options: semesterOptions,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => semesterFilter = value);
                  },
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _openCreateDialog,
                  icon: const Icon(Icons.add, size: 18, color: Colors.white),
                  label: const smcText(
                    textToDisplay: 'Create',
                    textSize: 14,
                    textBoldness: 4,
                    colorOfText: Colors.white,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorConst.primaryBlue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: timeTables.isEmpty
                  ? const Center(
                      child: smcText(
                        textToDisplay: 'No time tables created yet.',
                        textSize: 13,
                        colorOfText: ColorConst.textSecondary,
                      ),
                    )
                  : filteredTimeTables.isEmpty
                      ? const Center(
                          child: smcText(
                            textToDisplay:
                                'No time tables match the selected filters.',
                            textSize: 13,
                            colorOfText: ColorConst.textSecondary,
                          ),
                        )
                      : _buildTimeTableList(filteredTimeTables),
            ),
          ],
        );
      },
    );
  }
}
