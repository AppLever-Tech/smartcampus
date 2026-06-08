import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_day.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_settings_firestore_service.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_uid.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class CreateDayDialog {
  static Future<void> show({
    required BuildContext context,
    required String orgId,
    required TimeTableSettingsFirestoreService service,
    TimeTableDay? dayToEdit,
  }) async {
    final formKey = GlobalKey<FormState>();
    final isEditing = dayToEdit != null;
    final orderController = TextEditingController(
      text: isEditing ? '${dayToEdit.dayOrder}' : '',
    );
    final nameController = TextEditingController(
      text: isEditing ? dayToEdit.dayName : '',
    );
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }

              setDialogState(() => saving = true);
              try {
                final day = TimeTableDay(
                  dayOrder: int.parse(orderController.text.trim()),
                  dayName: nameController.text.trim(),
                  dayUid: isEditing ? dayToEdit.dayUid : generateTimeTableUid(),
                );
                if (isEditing) {
                  await service.updateDay(orgId: orgId, day: day);
                } else {
                  await service.addDay(orgId: orgId, day: day);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: smcText(
                        textToDisplay: isEditing ? 'Day updated.' : 'Day created.',
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
                        textToDisplay:
                            isEditing ? 'Failed to update day.' : 'Failed to create day.',
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
                textToDisplay: isEditing ? 'Edit Day' : 'Create Day',
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
                        labelText: 'Day Order',
                        hintText: 'e.g. 1',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Day order is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Day Name',
                        hintText: 'e.g. Monday',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Day name is required';
                        }
                        return null;
                      },
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
