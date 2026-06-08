import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_section.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_settings_firestore_service.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_uid.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class CreateSectionDialog {
  static Future<void> show({
    required BuildContext context,
    required String orgId,
    required TimeTableSettingsFirestoreService service,
    TimeTableSection? sectionToEdit,
  }) async {
    final formKey = GlobalKey<FormState>();
    final isEditing = sectionToEdit != null;
    final nameController = TextEditingController(
      text: isEditing ? sectionToEdit.sectionName : '',
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
                final section = TimeTableSection(
                  sectionName: nameController.text.trim(),
                  sectionUid: isEditing
                      ? sectionToEdit.sectionUid
                      : generateTimeTableUid(),
                );
                if (isEditing) {
                  await service.updateSection(orgId: orgId, section: section);
                } else {
                  await service.addSection(orgId: orgId, section: section);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: smcText(
                        textToDisplay:
                            isEditing ? 'Section updated.' : 'Section created.',
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
                            ? 'Failed to update section.'
                            : 'Failed to create section.',
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
                textToDisplay: isEditing ? 'Edit Section' : 'Create Section',
                textSize: 18,
                textBoldness: 5,
              ),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Section Name',
                    hintText: 'e.g. Section A',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Section name is required';
                    }
                    return null;
                  },
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

    nameController.dispose();
  }
}
