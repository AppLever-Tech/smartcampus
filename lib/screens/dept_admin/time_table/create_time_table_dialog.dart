import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/screens/dept_admin/time_table/models/time_table_section.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_firestore_service.dart';
import 'package:smartcampus/screens/dept_admin/time_table/time_table_settings_firestore_service.dart';
import 'package:smartcampus/services/settings_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class CreateTimeTableDialog {
  static Future<void> show({
    required BuildContext context,
    required String orgId,
    required TimeTableFirestoreService timeTableService,
    required TimeTableSettingsFirestoreService settingsService,
    required SettingsFirestoreService masterSettingsService,
  }) async {
    TimeTableSection? selectedSection;
    String? selectedBatch;
    String? selectedScheme;
    String? selectedSemester;
    bool saving = false;
    final formKey = GlobalKey<FormState>();
    const semesterOptions = ['I', 'II', 'III', 'IV'];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildDropdown({
              required String label,
              required String? value,
              required List<String> options,
              required ValueChanged<String?> onChanged,
            }) {
              return DropdownButtonFormField<String>(
                value: options.contains(value) ? value : null,
                decoration: InputDecoration(
                  labelText: label,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: options
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      ),
                    )
                    .toList(),
                onChanged: saving ? null : onChanged,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '$label is required';
                  }
                  return null;
                },
              );
            }

            Future<void> create() async {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }
              if (selectedSection == null) {
                return;
              }

              final confirm = await showDialog<bool>(
                context: context,
                builder: (confirmContext) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const smcText(
                    textToDisplay: 'Create Time Table',
                    textSize: 18,
                    textBoldness: 5,
                  ),
                  content: smcText(
                    textToDisplay:
                        'Are you sure you want to create a time table for '
                        'Scheme $selectedScheme, Batch $selectedBatch, '
                        'Semester $selectedSemester, '
                        'Section ${selectedSection!.sectionName}?',
                    textSize: 14,
                    colorOfText: ColorConst.textSecondary,
                    maxLines: 5,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmContext, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(confirmContext, true),
                      child: const smcText(
                        textToDisplay: 'Create',
                        textSize: 14,
                        textBoldness: 4,
                        colorOfText: ColorConst.primaryBlue,
                      ),
                    ),
                  ],
                ),
              );
              if (confirm != true) {
                return;
              }

              setDialogState(() => saving = true);
              try {
                await timeTableService.createTimeTable(
                  orgId: orgId,
                  section: selectedSection!.sectionName,
                  sectionUid: selectedSection!.sectionUid,
                  batch: selectedBatch!,
                  scheme: selectedScheme!,
                  semester: selectedSemester!,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: smcText(
                        textToDisplay: 'Time table created.',
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
                        textToDisplay: 'Failed to create time table.',
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
              title: const smcText(
                textToDisplay: 'Create Time Table For:',
                textSize: 18,
                textBoldness: 5,
              ),
              content: StreamBuilder<Map<String, dynamic>?>(
                stream: settingsService.watchSettings(orgId: orgId),
                builder: (context, settingsSnapshot) {
                  return StreamBuilder<List<SettingsItem>>(
                    stream: masterSettingsService.getItems('smcbatchmaster'),
                    builder: (context, batchSnapshot) {
                      return StreamBuilder<List<SettingsItem>>(
                        stream: masterSettingsService.getItems('smcschememaster'),
                        builder: (context, schemeSnapshot) {
                          final waiting = settingsSnapshot.connectionState ==
                                  ConnectionState.waiting ||
                              batchSnapshot.connectionState ==
                                  ConnectionState.waiting ||
                              schemeSnapshot.connectionState ==
                                  ConnectionState.waiting;

                          if (waiting) {
                            return const SizedBox(
                              height: 120,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final sections =
                              settingsService.parseSections(settingsSnapshot.data);
                          final sectionNames = sections
                              .map((section) => section.sectionName)
                              .toList();
                          final batchNames = (batchSnapshot.data ?? const [])
                              .map((item) => item.name)
                              .where((name) => name.trim().isNotEmpty)
                              .toList();
                          final schemeNames = (schemeSnapshot.data ?? const [])
                              .map((item) => item.name)
                              .where((name) => name.trim().isNotEmpty)
                              .toList();

                          if (sectionNames.isEmpty ||
                              batchNames.isEmpty ||
                              schemeNames.isEmpty) {
                            return smcText(
                              textToDisplay: sectionNames.isEmpty
                                  ? 'Configure sections in Time Table Settings first.'
                                  : batchNames.isEmpty
                                      ? 'Configure batches in Settings first.'
                                      : 'Configure schemes in Settings first.',
                              textSize: 13,
                              colorOfText: ColorConst.textSecondary,
                              maxLines: 4,
                            );
                          }

                          return Form(
                            key: formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                buildDropdown(
                                  label: 'Scheme',
                                  value: selectedScheme,
                                  options: schemeNames,
                                  onChanged: (value) {
                                    setDialogState(() => selectedScheme = value);
                                  },
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: buildDropdown(
                                        label: 'Batch',
                                        value: selectedBatch,
                                        options: batchNames,
                                        onChanged: (value) {
                                          setDialogState(
                                            () => selectedBatch = value,
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: buildDropdown(
                                        label: 'Semester',
                                        value: selectedSemester,
                                        options: semesterOptions,
                                        onChanged: (value) {
                                          setDialogState(
                                            () => selectedSemester = value,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                buildDropdown(
                                  label: 'Section',
                                  value: selectedSection?.sectionName,
                                  options: sectionNames,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedSection = sections.firstWhere(
                                        (section) => section.sectionName == value,
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : create,
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
                          textToDisplay: 'Create',
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
  }
}
