import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/screens/dept_admin/time_table/create_day_dialog.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_delete_confirm_dialog.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_settings_firestore_service.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_settings_list_actions.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class DaysSettingsPage extends StatelessWidget {
  final String orgId;
  final TimeTableSettingsFirestoreService settingsService;

  const DaysSettingsPage({
    super.key,
    required this.orgId,
    required this.settingsService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: settingsService.watchSettings(orgId: orgId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final days = settingsService.parseDays(snapshot.data);
        if (days.isEmpty) {
          return const Center(
            child: smcText(
              textToDisplay: 'No days configured yet.',
              textSize: 13,
              colorOfText: ColorConst.textSecondary,
            ),
          );
        }

        return ListView.separated(
          itemCount: days.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final day = days[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    child: smcText(
                      textToDisplay: '${day.dayOrder}',
                      textSize: 13,
                      textBoldness: 5,
                      colorOfText: ColorConst.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        smcText(
                          textToDisplay: day.dayName,
                          textSize: 14,
                          textBoldness: 4,
                          colorOfText: ColorConst.textPrimary,
                        ),
                        if (day.dayUid.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          smcText(
                            textToDisplay: day.dayUid,
                            textSize: 12,
                            colorOfText: ColorConst.textSecondary,
                          ),
                        ],
                      ],
                    ),
                  ),
                  TimeTableSettingsListActions(
                    onEdit: () {
                      CreateDayDialog.show(
                        context: context,
                        orgId: orgId,
                        service: settingsService,
                        dayToEdit: day,
                      );
                    },
                    onDelete: () async {
                      final confirmed = await TimeTableDeleteConfirmDialog.show(
                        context: context,
                        title: 'Delete Day',
                        message:
                            'Are you sure you want to delete "${day.dayName}"?',
                      );
                      if (!confirmed || !context.mounted) {
                        return;
                      }
                      try {
                        await settingsService.deleteDay(
                          orgId: orgId,
                          dayUid: day.dayUid,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: smcText(
                                textToDisplay: 'Day deleted.',
                                textSize: 14,
                                colorOfText: Colors.white,
                              ),
                            ),
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: smcText(
                                textToDisplay: 'Failed to delete day.',
                                textSize: 14,
                                colorOfText: Colors.white,
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
