import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_time_slot.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_settings_firestore_service.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_uid.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class CreateTimeSlotDialog {
  static String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static TimeOfDay? _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  static Future<void> show({
    required BuildContext context,
    required String orgId,
    required TimeTableSettingsFirestoreService service,
    TimeTableTimeSlot? timeSlotToEdit,
  }) async {
    final formKey = GlobalKey<FormState>();
    final isEditing = timeSlotToEdit != null;
    final orderController = TextEditingController(
      text: isEditing ? '${timeSlotToEdit.timeslotOrder}' : '',
    );
    final nameController = TextEditingController(
      text: isEditing ? timeSlotToEdit.timeslotName : '',
    );
    TimeOfDay? startTime =
        isEditing ? _parseTime(timeSlotToEdit.timeslotStartTime) : null;
    TimeOfDay? endTime =
        isEditing ? _parseTime(timeSlotToEdit.timeslotEndTime) : null;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickStartTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: startTime ?? const TimeOfDay(hour: 9, minute: 0),
              );
              if (picked != null) {
                setDialogState(() => startTime = picked);
              }
            }

            Future<void> pickEndTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: endTime ?? const TimeOfDay(hour: 10, minute: 0),
              );
              if (picked != null) {
                setDialogState(() => endTime = picked);
              }
            }

            Future<void> save() async {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }
              if (startTime == null || endTime == null) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: smcText(
                      textToDisplay: 'Start and end times are required.',
                      textSize: 14,
                      colorOfText: Colors.white,
                    ),
                  ),
                );
                return;
              }

              setDialogState(() => saving = true);
              try {
                final timeSlot = TimeTableTimeSlot(
                  timeslotOrder: int.parse(orderController.text.trim()),
                  timeslotName: nameController.text.trim(),
                  timeslotStartTime: _formatTime(startTime!),
                  timeslotEndTime: _formatTime(endTime!),
                  timeslotUid: isEditing
                      ? timeSlotToEdit.timeslotUid
                      : generateTimeTableUid(),
                );
                if (isEditing) {
                  await service.updateTimeSlot(
                    orgId: orgId,
                    timeSlot: timeSlot,
                  );
                } else {
                  await service.addTimeSlot(
                    orgId: orgId,
                    timeSlot: timeSlot,
                  );
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: smcText(
                        textToDisplay: isEditing
                            ? 'Time slot updated.'
                            : 'Time slot created.',
                        textSize: 14,
                        colorOfText: Colors.white,
                      ),
                    ),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  setDialogState(() => saving = false);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: smcText(
                        textToDisplay: isEditing
                            ? 'Failed to update time slot.'
                            : 'Failed to create time slot.',
                        textSize: 14,
                        colorOfText: Colors.white,
                      ),
                    ),
                  );
                }
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: smcText(
                textToDisplay: isEditing ? 'Edit Time Slot' : 'Create Time Slot',
                textSize: 18,
                textBoldness: 5,
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: orderController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Time Slot Order',
                        hintText: 'e.g. 1',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Time slot order is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Time Slot Name',
                        hintText: 'e.g. Period 1',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Time slot name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const smcText(
                        textToDisplay: 'Start Time',
                        textSize: 13,
                        colorOfText: ColorConst.textSecondary,
                      ),
                      subtitle: smcText(
                        textToDisplay:
                            startTime == null ? 'Select start time' : _formatTime(startTime!),
                        textSize: 14,
                        textBoldness: 4,
                        colorOfText: ColorConst.textPrimary,
                      ),
                      trailing: const Icon(Icons.access_time_rounded),
                      onTap: saving ? null : pickStartTime,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const smcText(
                        textToDisplay: 'End Time',
                        textSize: 13,
                        colorOfText: ColorConst.textSecondary,
                      ),
                      subtitle: smcText(
                        textToDisplay:
                            endTime == null ? 'Select end time' : _formatTime(endTime!),
                        textSize: 14,
                        textBoldness: 4,
                        colorOfText: ColorConst.textPrimary,
                      ),
                      trailing: const Icon(Icons.access_time_rounded),
                      onTap: saving ? null : pickEndTime,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorConst.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const smcText(
                          textToDisplay: 'Save',
                          textSize: 14,
                          textBoldness: 4,
                          colorOfText: Colors.white,
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    orderController.dispose();
    nameController.dispose();
  }
}
