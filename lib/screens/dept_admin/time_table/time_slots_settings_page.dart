import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_settings_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class TimeSlotsSettingsPage extends StatelessWidget {
  final String orgId;
  final TimeTableSettingsFirestoreService settingsService;

  const TimeSlotsSettingsPage({
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

        final timeSlots = settingsService.parseTimeSlots(snapshot.data);
        if (timeSlots.isEmpty) {
          return const Center(
            child: smcText(
              textToDisplay: 'No time slots configured yet.',
              textSize: 13,
              colorOfText: ColorConst.textSecondary,
            ),
          );
        }

        return ListView.separated(
          itemCount: timeSlots.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final slot = timeSlots[index];
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
                      textToDisplay: '${slot.timeslotOrder}',
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
                          textToDisplay: slot.timeslotName,
                          textSize: 14,
                          textBoldness: 4,
                          colorOfText: ColorConst.textPrimary,
                        ),
                        const SizedBox(height: 2),
                        smcText(
                          textToDisplay:
                              '${slot.timeslotStartTime} - ${slot.timeslotEndTime}',
                          textSize: 12,
                          colorOfText: ColorConst.textSecondary,
                        ),
                        if (slot.timeslotUid.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          smcText(
                            textToDisplay: slot.timeslotUid,
                            textSize: 12,
                            colorOfText: ColorConst.textSecondary,
                          ),
                        ],
                      ],
                    ),
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
