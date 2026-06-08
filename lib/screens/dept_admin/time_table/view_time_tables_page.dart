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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: smcText(
                textToDisplay: 'Time Tables',
                textSize: 15,
                textBoldness: 5,
                colorOfText: ColorConst.textPrimary,
              ),
            ),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder(
            stream: timeTableService.watchTimeTables(
              orgId: widget.orgId,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final timeTables = snapshot.data ?? const [];
              if (timeTables.isEmpty) {
                return const Center(
                  child: smcText(
                    textToDisplay: 'No time tables created yet.',
                    textSize: 13,
                    colorOfText: ColorConst.textSecondary,
                  ),
                );
              }

              return ListView.separated(
                itemCount: timeTables.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final timeTable = timeTables[index];
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
                                    textToDisplay:
                                        '${timeTable.section} • ${timeTable.batch} • ${timeTable.scheme}',
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
            },
          ),
        ),
      ],
    );
  }
}
