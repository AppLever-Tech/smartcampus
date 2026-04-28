import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/mock_master_data.dart';
import 'package:smartcampus/screens/landing_page.dart';
import 'package:smartcampus/services/org_role_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class DeptAdminDashboardPage extends StatefulWidget {
  final String orgId;
  final String adminName;

  const DeptAdminDashboardPage({
    super.key,
    required this.orgId,
    required this.adminName,
  });

  @override
  State<DeptAdminDashboardPage> createState() => DeptAdminDashboardPageState();
}

class DeptAdminDashboardPageState extends State<DeptAdminDashboardPage> {
  final OrgRoleFirestoreService roleService = OrgRoleFirestoreService();
  bool loading = true;
  List<OrgUserRoleMappingItem> facultyAndStudents = <OrgUserRoleMappingItem>[];
  List<DepartmentMasterItem> departments = <DepartmentMasterItem>[];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
    });
    try {
      final people =
          await roleService.listFacultyAndStudentsForOrg(widget.orgId);
      final depts = await roleService.loadDepartmentsForOrg(widget.orgId);
      if (!mounted) {
        return;
      }
      setState(() {
        facultyAndStudents = people;
        departments = depts;
        loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        facultyAndStudents = <OrgUserRoleMappingItem>[];
        loading = false;
      });
    }
  }

  Future<void> onLogout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LandingPage()),
      (route) => false,
    );
  }

  void onSupport() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const smcText(
            textToDisplay: 'Support',
            textSize: 18,
            textBoldness: 4,
            colorOfText: ColorConst.textPrimary,
          ),
          content: const smcText(
            textToDisplay:
                'For faculty or student placement, contact your organisation administrator.',
            textSize: 14,
            colorOfText: ColorConst.textSecondary,
            maxLines: 5,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const smcText(
                textToDisplay: 'Close',
                textSize: 14,
                textBoldness: 3,
                colorOfText: ColorConst.primaryBlue,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> openAssignDepartmentSheet(OrgUserRoleMappingItem mapping) async {
    if (departments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: smcText(
            textToDisplay:
                'No departments found. Add rows to smcDepartmentMaster.',
            textSize: 14,
            colorOfText: Colors.white,
            maxLines: 3,
          ),
        ),
      );
      return;
    }
    String? chosenDeptId = departments.first.deptId;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            DepartmentMasterItem? deptById(String? id) {
              if (id == null) {
                return null;
              }
              for (final d in departments) {
                if (d.deptId == id) {
                  return d;
                }
              }
              return null;
            }

            final DepartmentMasterItem? chosen = deptById(chosenDeptId);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.paddingOf(ctx).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  smcText(
                    textToDisplay: mapping.name,
                    textSize: 18,
                    textBoldness: 5,
                    colorOfText: ColorConst.textPrimary,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  smcText(
                    textToDisplay:
                        'Role: ${mapping.roleId}  ·  Current dept: ${mapping.deptId.isEmpty ? '—' : mapping.deptId}',
                    textSize: 13,
                    colorOfText: ColorConst.textSecondary,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: chosenDeptId,
                        isExpanded: true,
                        items: departments
                            .map(
                              (d) => DropdownMenuItem<String>(
                                value: d.deptId,
                                child: Text(
                                  d.deptName.isEmpty
                                      ? d.deptId
                                      : '${d.deptName} (${d.deptId})',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (id) {
                          setModalState(() {
                            chosenDeptId = id;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: chosen == null
                          ? null
                          : () async {
                              try {
                                await roleService
                                    .assignFacultyOrStudentDepartment(
                                  mapping: mapping,
                                  department: chosen,
                                );
                                if (!context.mounted) {
                                  return;
                                }
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: smcText(
                                      textToDisplay: 'Department updated.',
                                      textSize: 14,
                                      colorOfText: Colors.white,
                                    ),
                                  ),
                                );
                                await refresh();
                              } catch (_) {
                                if (!context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: smcText(
                                      textToDisplay: 'Update failed.',
                                      textSize: 14,
                                      colorOfText: Colors.white,
                                    ),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorConst.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const smcText(
                        textToDisplay: 'Assign to department',
                        textSize: 15,
                        textBoldness: 4,
                        colorOfText: Colors.white,
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 240,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Color(0xFFE3EAF8))),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const smcText(
                      textToDisplay: 'Department admin',
                      textSize: 20,
                      textBoldness: 5,
                      colorOfText: ColorConst.textPrimary,
                    ),
                    const SizedBox(height: 20),
                    _menuTile(
                      title: 'Dashboard',
                      icon: Icons.dashboard_outlined,
                      isSelected: true,
                      onTap: () {},
                    ),
                    const SizedBox(height: 8),
                    _menuTile(
                      title: 'Support',
                      icon: Icons.support_agent_rounded,
                      isSelected: false,
                      onTap: onSupport,
                    ),
                    const Spacer(),
                    _menuTile(
                      title: 'Logout',
                      icon: Icons.logout_rounded,
                      isSelected: false,
                      onTap: onLogout,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    smcText(
                      textToDisplay:
                          'Welcome back, ${widget.adminName.isEmpty ? 'Admin' : widget.adminName}',
                      textSize: 18,
                      textBoldness: 5,
                      colorOfText: ColorConst.textPrimary,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    smcText(
                      textToDisplay: 'Organisation: ${widget.orgId}',
                      textSize: 13,
                      colorOfText: ColorConst.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    const smcText(
                      textToDisplay:
                          'Faculty and student role mappings in your organisation. Tap a row to assign a department.',
                      textSize: 14,
                      colorOfText: ColorConst.textSecondary,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : facultyAndStudents.isEmpty
                              ? const Center(
                                  child: smcText(
                                    textToDisplay:
                                        'No faculty or student mappings for this organisation.',
                                    textSize: 14,
                                    colorOfText: ColorConst.textSecondary,
                                    maxLines: 4,
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: facultyAndStudents.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final row = facultyAndStudents[index];
                                    return Material(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () => openAssignDepartmentSheet(row),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    smcText(
                                                      textToDisplay: row.name,
                                                      textSize: 16,
                                                      textBoldness: 4,
                                                      colorOfText:
                                                          ColorConst.textPrimary,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    smcText(
                                                      textToDisplay:
                                                          '${row.roleId}  ·  Dept: ${row.deptId.isEmpty ? '—' : row.deptId}',
                                                      textSize: 13,
                                                      colorOfText: ColorConst
                                                          .textSecondary,
                                                      maxLines: 2,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Icon(Icons.edit_outlined),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF0FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? ColorConst.primaryBlue : ColorConst.textSecondary,
            ),
            const SizedBox(width: 10),
            smcText(
              textToDisplay: title,
              textSize: 14,
              textBoldness: isSelected ? 4 : 3,
              colorOfText:
                  isSelected ? ColorConst.primaryBlue : ColorConst.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
