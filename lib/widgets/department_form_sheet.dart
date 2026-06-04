import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/mock_master_data.dart';
import 'package:smartcampus/services/org_role_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';

/// Opens create or edit department form. Returns `true` when saved successfully.
Future<bool> showDepartmentFormSheet({
  required BuildContext context,
  required OrgRoleFirestoreService roleService,
  required String orgId,
  DepartmentMasterItem? department,
  bool lockDeptId = false,
}) async {
  final bool isEdit = department != null;
  final deptIdController = TextEditingController(text: department?.deptId ?? '');
  final deptNameController = TextEditingController(text: department?.deptName ?? '');
  final deptAccessCodeController = TextEditingController(
    text: department?.deptAccessCode ?? '',
  );
  final establishedYearController = TextEditingController(
    text: department?.establishedYear ?? '',
  );
  final affiliationController = TextEditingController(
    text: department?.affiliation ?? '',
  );

  String selectedDeptType = department?.deptType.isNotEmpty == true
      ? department!.deptType
      : 'Engineering';
  String selectedAccreditation = department?.accreditationStatus.isNotEmpty == true
      ? department!.accreditationStatus
      : 'None';
  final Set<String> selectedPrograms = {
    ...?department?.programsOffered,
  };

  const deptTypes = ['Engineering', 'Management', 'Science', 'Arts', 'Other'];
  const accreditationOptions = ['None', 'NBA', 'NAAC', 'NBA & NAAC'];
  const programOptions = [
    'B.E',
    'B.Tech',
    'M.Tech',
    'MCA',
    'MBA',
    'M.Sc',
    'B.Sc',
    'BCA',
    'Ph.D',
  ];

  bool saving = false;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      smcText(
                        textToDisplay:
                            isEdit ? 'Edit Department' : 'Create Department',
                        textSize: 18,
                        textBoldness: 5,
                        colorOfText: ColorConst.textPrimary,
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        icon: const Icon(Icons.close_rounded),
                        color: ColorConst.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: deptIdController,
                    enabled: !lockDeptId && !isEdit,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Department ID *',
                      hintText: 'e.g. CSE, ECE, MCA',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: deptNameController,
                    decoration: InputDecoration(
                      labelText: 'Department Name *',
                      hintText: 'e.g. Computer Science & Engineering',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: deptAccessCodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Department Access Code *',
                      hintText: '4-digit code for user registration',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: establishedYearController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: 'Established Year',
                      hintText: 'e.g. 2005',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Department Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedDeptType,
                        isExpanded: true,
                        isDense: true,
                        items: deptTypes
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setModalState(() => selectedDeptType = v);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const smcText(
                    textToDisplay: 'Program(s) Offered',
                    textSize: 13,
                    colorOfText: ColorConst.textSecondary,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 0,
                    children: programOptions.map((prog) {
                      final isSelected = selectedPrograms.contains(prog);
                      return FilterChip(
                        label: Text(prog),
                        selected: isSelected,
                        selectedColor:
                            ColorConst.primaryBlue.withValues(alpha: 0.15),
                        checkmarkColor: ColorConst.primaryBlue,
                        onSelected: (val) {
                          setModalState(() {
                            if (val) {
                              selectedPrograms.add(prog);
                            } else {
                              selectedPrograms.remove(prog);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: affiliationController,
                    decoration: InputDecoration(
                      labelText: 'Affiliation / University',
                      hintText: 'e.g. Visvesvaraya Technological University',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Accreditation Status',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedAccreditation,
                        isExpanded: true,
                        isDense: true,
                        items: accreditationOptions
                            .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setModalState(() => selectedAccreditation = v);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final deptId =
                                  deptIdController.text.trim().toUpperCase();
                              final deptName = deptNameController.text.trim();
                              final accessCode =
                                  deptAccessCodeController.text.trim();
                              if (deptId.isEmpty ||
                                  deptName.isEmpty ||
                                  accessCode.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: smcText(
                                      textToDisplay:
                                          'Department ID, name, and access code are required.',
                                      textSize: 14,
                                      colorOfText: Colors.white,
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (OrgRoleFirestoreService.normalizeDeptAccessCode(
                                    accessCode,
                                  ).length !=
                                  4) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: smcText(
                                      textToDisplay:
                                          'Enter a valid 4-digit department access code.',
                                      textSize: 14,
                                      colorOfText: Colors.white,
                                    ),
                                  ),
                                );
                                return;
                              }
                              setModalState(() => saving = true);
                              try {
                                await roleService.createOrUpdateDepartment(
                                  orgId: orgId,
                                  deptId: deptId,
                                  deptName: deptName,
                                  deptAccessCode: accessCode,
                                  establishedYear:
                                      establishedYearController.text.trim(),
                                  deptType: selectedDeptType,
                                  programsOffered: selectedPrograms.toList(),
                                  affiliation: affiliationController.text.trim(),
                                  accreditationStatus: selectedAccreditation,
                                  createdBy:
                                      department?.createdBy.isNotEmpty == true
                                          ? department!.createdBy
                                          : FirebaseAuth.instance.currentUser
                                                  ?.uid ??
                                              '',
                                );
                                if (!context.mounted) {
                                  return;
                                }
                                Navigator.pop(ctx, true);
                              } on StateError catch (e) {
                                if (!context.mounted) {
                                  return;
                                }
                                setModalState(() => saving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: smcText(
                                      textToDisplay: e.message,
                                      textSize: 14,
                                      colorOfText: Colors.white,
                                      maxLines: 3,
                                    ),
                                  ),
                                );
                              } catch (_) {
                                if (!context.mounted) {
                                  return;
                                }
                                setModalState(() => saving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: smcText(
                                      textToDisplay: 'Failed to save department.',
                                      textSize: 14,
                                      colorOfText: Colors.white,
                                    ),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorConst.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: smcText(
                        textToDisplay: saving ? 'Saving...' : 'Save Department',
                        textSize: 15,
                        textBoldness: 4,
                        colorOfText: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  deptIdController.dispose();
  deptNameController.dispose();
  deptAccessCodeController.dispose();
  establishedYearController.dispose();
  affiliationController.dispose();

  return result ?? false;
}
