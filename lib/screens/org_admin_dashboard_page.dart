import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/mock_master_data.dart';
import 'package:smartcampus/screens/landing_page.dart';
import 'package:smartcampus/services/org_role_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class OrgAdminDashboardPage extends StatefulWidget {
  final String orgId;
  final String adminName;

  const OrgAdminDashboardPage({
    super.key,
    required this.orgId,
    required this.adminName,
  });

  @override
  State<OrgAdminDashboardPage> createState() => OrgAdminDashboardPageState();
}

class OrgAdminDashboardPageState extends State<OrgAdminDashboardPage> {
  final OrgRoleFirestoreService roleService = OrgRoleFirestoreService();
  bool loading = true;
  List<OrgUserRoleMappingItem> pendingDeptAdmins = <OrgUserRoleMappingItem>[];
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
      final pending =
          await roleService.listPendingDeptAdminsForOrg(widget.orgId);
      final depts = await roleService.loadDepartmentsForOrg(widget.orgId);
      if (!mounted) {
        return;
      }
      setState(() {
        pendingDeptAdmins = pending;
        departments = depts;
        loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        pendingDeptAdmins = <OrgUserRoleMappingItem>[];
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
                'For department setup issues, contact your system administrator.',
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

  Future<void> openDetailSheet(OrgUserRoleMappingItem mapping) async {
    final user = await roleService.getUserMaster(mapping.uuid);
    if (!mounted) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.paddingOf(ctx).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const smcText(
                  textToDisplay: 'Department admin (registered)',
                  textSize: 18,
                  textBoldness: 5,
                  colorOfText: ColorConst.textPrimary,
                ),
                const SizedBox(height: 12),
                smcText(
                  textToDisplay: 'Name: ${mapping.name}',
                  textSize: 14,
                  colorOfText: ColorConst.textPrimary,
                ),
                const SizedBox(height: 6),
                smcText(
                  textToDisplay: 'UUID: ${mapping.uuid}',
                  textSize: 13,
                  colorOfText: ColorConst.textSecondary,
                  maxLines: 2,
                ),
                if (user != null) ...[
                  const SizedBox(height: 8),
                  smcText(
                    textToDisplay: 'Email: ${user.email}',
                    textSize: 13,
                    colorOfText: ColorConst.textSecondary,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  smcText(
                    textToDisplay: 'Mobile: ${user.mobile}',
                    textSize: 13,
                    colorOfText: ColorConst.textSecondary,
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: departments.isEmpty
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            openAssignDepartmentSheet(mapping);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorConst.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const smcText(
                      textToDisplay: 'Add to department',
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
  }

  void openAssignDepartmentSheet(OrgUserRoleMappingItem mapping) {
    String? chosenDeptId =
        departments.isNotEmpty ? departments.first.deptId : null;

    showModalBottomSheet<void>(
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
                  const smcText(
                    textToDisplay: 'Assign department',
                    textSize: 18,
                    textBoldness: 5,
                    colorOfText: ColorConst.textPrimary,
                  ),
                  const SizedBox(height: 12),
                  const smcText(
                    textToDisplay:
                        'Departments are loaded from smcDepartmentMaster for your organisation.',
                    textSize: 13,
                    colorOfText: ColorConst.textSecondary,
                    maxLines: 4,
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
                                await roleService.assignDeptAdminToDepartment(
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
                                      textToDisplay:
                                          'Department admin assigned.',
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
                                      textToDisplay: 'Assignment failed.',
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
                        textToDisplay: 'Confirm',
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
                      textToDisplay: 'Organisation admin',
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
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFE8EEFF),
                          child: Text(
                            widget.adminName.isEmpty
                                ? 'A'
                                : widget.adminName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: ColorConst.primaryBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              smcText(
                                textToDisplay:
                                    'Welcome back, ${widget.adminName.isEmpty ? 'Admin' : widget.adminName}',
                                textSize: 16,
                                textBoldness: 4,
                                colorOfText: ColorConst.textPrimary,
                                maxLines: 1,
                              ),
                              smcText(
                                textToDisplay: 'Org ID: ${widget.orgId}',
                                textSize: 13,
                                colorOfText: ColorConst.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const smcText(
                      textToDisplay:
                          'Department admins (DEPT_ADMIN, Registered) in your organisation.',
                      textSize: 14,
                      colorOfText: ColorConst.textSecondary,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : pendingDeptAdmins.isEmpty
                              ? const Center(
                                  child: smcText(
                                    textToDisplay:
                                        'No pending department admins. Add departments in smcDepartmentMaster to enable assignments.',
                                    textSize: 14,
                                    colorOfText: ColorConst.textSecondary,
                                    maxLines: 5,
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final double tableWidth = constraints.maxWidth;
                                    const double nameWidth = 220;
                                    const double uuidWidth = 260;
                                    const double statusWidth = 120;
                                    const double actionWidth = 120;
                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minWidth: tableWidth,
                                        ),
                                        child: DataTable(
                                          headingRowHeight: 50,
                                          dataRowMinHeight: 52,
                                          dataRowMaxHeight: 58,
                                          horizontalMargin: 8,
                                          columnSpacing: 0,
                                          dividerThickness: 1,
                                          border: TableBorder.all(
                                            color: const Color(0xFFE3EAF8),
                                            width: 1,
                                          ),
                                          headingRowColor:
                                              WidgetStateProperty.all(
                                            const Color(0xFFF4F7FF),
                                          ),
                                          columns: const [
                                            DataColumn(
                                              label: SizedBox(
                                                width: nameWidth,
                                                child: Center(
                                                  child: smcText(
                                                    textToDisplay: 'Name',
                                                    textSize: 12,
                                                    textBoldness: 4,
                                                    colorOfText:
                                                        Color(0xFF5C6B8B),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataColumn(
                                              label: SizedBox(
                                                width: uuidWidth,
                                                child: Center(
                                                  child: smcText(
                                                    textToDisplay: 'UUID',
                                                    textSize: 12,
                                                    textBoldness: 4,
                                                    colorOfText:
                                                        Color(0xFF5C6B8B),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataColumn(
                                              label: SizedBox(
                                                width: statusWidth,
                                                child: Center(
                                                  child: smcText(
                                                    textToDisplay: 'Status',
                                                    textSize: 12,
                                                    textBoldness: 4,
                                                    colorOfText:
                                                        Color(0xFF5C6B8B),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataColumn(
                                              label: SizedBox(
                                                width: actionWidth,
                                                child: Center(
                                                  child: smcText(
                                                    textToDisplay: 'Action',
                                                    textSize: 12,
                                                    textBoldness: 4,
                                                    colorOfText:
                                                        Color(0xFF5C6B8B),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                          rows: pendingDeptAdmins.map((row) {
                                            return DataRow(
                                              onSelectChanged: (_) =>
                                                  openDetailSheet(row),
                                              cells: [
                                                DataCell(
                                                  SizedBox(
                                                    width: nameWidth,
                                                    child: Center(
                                                      child: smcText(
                                                        textToDisplay: row.name,
                                                        textSize: 12,
                                                        textBoldness: 4,
                                                        colorOfText:
                                                            ColorConst.textPrimary,
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: uuidWidth,
                                                    child: Center(
                                                      child: smcText(
                                                        textToDisplay: row.uuid,
                                                        textSize: 12,
                                                        colorOfText: ColorConst
                                                            .textSecondary,
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const DataCell(
                                                  SizedBox(
                                                    width: statusWidth,
                                                    child: Center(
                                                      child: smcText(
                                                        textToDisplay:
                                                            'Registered',
                                                        textSize: 12,
                                                        textBoldness: 4,
                                                        colorOfText:
                                                            Color(0xFF3558DA),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: actionWidth,
                                                    child: Center(
                                                      child: ElevatedButton(
                                                        onPressed: departments
                                                                .isEmpty
                                                            ? null
                                                            : () =>
                                                                openAssignDepartmentSheet(
                                                                  row,
                                                                ),
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              ColorConst
                                                                  .primaryBlue,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 14,
                                                            vertical: 8,
                                                          ),
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                              8,
                                                            ),
                                                          ),
                                                        ),
                                                        child: const smcText(
                                                          textToDisplay: 'Add',
                                                          textSize: 12,
                                                          textBoldness: 4,
                                                          colorOfText:
                                                              Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
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
