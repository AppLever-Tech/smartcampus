import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/mock_master_data.dart';
import 'package:smartcampus/screens/landing_page.dart';
import 'package:smartcampus/services/org_role_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';
import 'package:smartcampus/screens/basic_details_screen.dart';



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
  int selectedMenuIndex = 0;
  List<OrgUserRoleMappingItem> pendingDeptAdmins = <OrgUserRoleMappingItem>[];
  List<DepartmentMasterItem> departments = <DepartmentMasterItem>[];
  int totalAssignedDepartments = 0;
  String organizationDisplayName = '';


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
      final assignedCount = await roleService.countAssignedDepartmentsForOrg(
        widget.orgId,
      );
      final org = await roleService.authService.getOrganizationById(widget.orgId);
      if (!mounted) {
        return;
      }
      setState(() {
        pendingDeptAdmins = pending;
        departments = depts;
        totalAssignedDepartments = assignedCount;
        organizationDisplayName =
            (org?.orgName ?? '').trim().isEmpty ? widget.orgId : org!.orgName;
        loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        pendingDeptAdmins = <OrgUserRoleMappingItem>[];
        totalAssignedDepartments = 0;
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

  void onNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: smcText(
          textToDisplay: 'No new notifications.',
          textSize: 14,
          colorOfText: Colors.white,
        ),
      ),
    );
  }

  Future<void> openCreateDepartmentSheet() async {
    final deptIdController = TextEditingController();
    final deptNameController = TextEditingController();
    final establishedYearController = TextEditingController();
    final affiliationController = TextEditingController();

    String selectedDeptType = 'Engineering';
    String selectedAccreditation = 'None';
    final Set<String> selectedPrograms = {};

    const deptTypes = ['Engineering', 'Management', 'Science', 'Arts', 'Other'];
    const accreditationOptions = ['None', 'NBA', 'NAAC', 'NBA & NAAC'];
    const programOptions = [
      'B.E', 'B.Tech', 'M.Tech', 'MCA', 'MBA', 'M.Sc', 'B.Sc', 'BCA', 'Ph.D'
    ];

    bool saving = false;

    await showModalBottomSheet<void>(
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
                    // Header row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const smcText(
                          textToDisplay: 'Create Department',
                          textSize: 18,
                          textBoldness: 5,
                          colorOfText: ColorConst.textPrimary,
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                          color: ColorConst.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Department ID
                    TextField(
                      controller: deptIdController,
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

                    // Department Name
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

                    // Established Year
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

                    // Department Type
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

                    // Programs Offered
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
                          selectedColor: ColorConst.primaryBlue.withValues(alpha: 0.15),
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

                    // Affiliation / University
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

                    // Accreditation Status
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
                                if (deptId.isEmpty || deptName.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: smcText(
                                        textToDisplay:
                                            'Department ID and name are required.',
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
                                    orgId: widget.orgId,
                                    deptId: deptId,
                                    deptName: deptName,
                                    establishedYear:
                                        establishedYearController.text.trim(),
                                    deptType: selectedDeptType,
                                    programsOffered: selectedPrograms.toList(),
                                    affiliation:
                                        affiliationController.text.trim(),
                                    accreditationStatus: selectedAccreditation,
                                    createdBy: FirebaseAuth.instance.currentUser
                                            ?.uid ??
                                        '',
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: smcText(
                                        textToDisplay:
                                            'Department saved successfully.',
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
                          textToDisplay:
                              saving ? 'Saving...' : 'Save Department',
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
                        'Departments are available for your organisation.',
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
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4D7BFF), Color(0xFF3D5BDB)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.school_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: smcText(
                            textToDisplay: 'SmartCampus',
                            textSize: 20,
                            textBoldness: 5,
                            colorOfText: ColorConst.textPrimary,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const smcText(
                      textToDisplay: 'Organisation Admin',
                      textSize: 13,
                      textBoldness: 4,
                      colorOfText: ColorConst.textSecondary,
                    ),
                    const SizedBox(height: 20),
                    _menuTile(
                      title: 'Dashboard',
                      icon: Icons.dashboard_outlined,
                      isSelected: selectedMenuIndex == 0,
                      onTap: () {
                        setState(() {
                          selectedMenuIndex = 0;
                        });
                      },
                    ),

                    const SizedBox(height: 8),

                    _menuTile(
                      title: 'Departments',
                      icon: Icons.account_tree_outlined,
                      isSelected: selectedMenuIndex == 2,
                      onTap: () {
                        setState(() {
                          selectedMenuIndex = 2;
                        });
                      },
                    ),
                    const SizedBox(height: 8),



                    _menuTile(
                      title: 'Basic Details',
                      icon: Icons.info_outline_rounded,
                      isSelected: selectedMenuIndex == 1,
                      onTap: () {
                        setState(() {
                          selectedMenuIndex = 1;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _menuTile(
                      title: 'Notification',
                      icon: Icons.notifications_none_rounded,
                      isSelected: false,
                      onTap: onNotification,
                    ),
                    const SizedBox(height: 8),
                    const Spacer(),
                    _menuTile(
                      title: 'Support',
                      icon: Icons.support_agent_rounded,
                      isSelected: false,
                      onTap: onSupport,
                    ),
                    const SizedBox(height: 8),
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
                child: selectedMenuIndex == 0
                ?Column(
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
                                textToDisplay:
                                    'Organisation: ${organizationDisplayName.isEmpty ? widget.orgId : organizationDisplayName}',
                                textSize: 13,
                                colorOfText: ColorConst.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    /*const SizedBox(height: 16),
                    const smcText(
                      textToDisplay:
                        'Department admins (DEPT_ADMIN, Registered) in your organisation.',
                      textSize: 14,
                      colorOfText: ColorConst.textSecondary,
                      maxLines: 3,
                    ),*/
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: openCreateDepartmentSheet,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorConst.primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, color: Colors.white),
                          label: const smcText(
                            textToDisplay: 'Create Department',
                            textSize: 13,
                            textBoldness: 4,
                            colorOfText: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (loading)
                      const Expanded(child: Center(child: CircularProgressIndicator()))
                    else ...[
                      Row(
                        children: [
                          _buildCountCard(
                            label: 'Total Departments',
                            value: '${departments.length}',
                            icon: Icons.account_tree_outlined,
                          ),
                          const SizedBox(width: 12),
                          _buildCountCard(
                            label: 'Total Assigned Departments',
                            value: '$totalAssignedDepartments',
                            icon: Icons.assignment_turned_in_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE3EAF8)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 14,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: pendingDeptAdmins.isEmpty
                                ? const Center(
                                    child: smcText(
                                      textToDisplay:
                                          'No pending department admins. Add departments to enable assignments.',
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
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.only(left: 4, bottom: 8),
                                            child: smcText(
                                              textToDisplay: 'Pending Department Admins',
                                              textSize: 14,
                                              textBoldness: 5,
                                              colorOfText: ColorConst.textPrimary,
                                            ),
                                          ),
                                          Expanded(
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: ConstrainedBox(
                                                constraints:
                                                    BoxConstraints(minWidth: tableWidth),
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
                                                    DataColumn(label: SizedBox(width: nameWidth, child: Center(child: smcText(textToDisplay: 'Name', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                                    DataColumn(label: SizedBox(width: uuidWidth, child: Center(child: smcText(textToDisplay: 'UUID', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                                    DataColumn(label: SizedBox(width: statusWidth, child: Center(child: smcText(textToDisplay: 'Status', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                                    DataColumn(label: SizedBox(width: actionWidth, child: Center(child: smcText(textToDisplay: 'Action', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                                  ],
                                                  rows: pendingDeptAdmins.map((row) {
                                                    return DataRow(
                                                      onSelectChanged: (_) => openDetailSheet(row),
                                                      cells: [
                                                        DataCell(SizedBox(width: nameWidth, child: Center(child: smcText(textToDisplay: row.name, textSize: 12, textBoldness: 4, colorOfText: ColorConst.textPrimary, maxLines: 1)))),
                                                        DataCell(SizedBox(width: uuidWidth, child: Center(child: smcText(textToDisplay: row.uuid, textSize: 12, colorOfText: ColorConst.textSecondary, maxLines: 1)))),
                                                        const DataCell(SizedBox(width: statusWidth, child: Center(child: smcText(textToDisplay: 'Registered', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF3558DA))))),
                                                        DataCell(
                                                          SizedBox(
                                                            width: actionWidth,
                                                            child: Center(
                                                              child: ElevatedButton(
                                                                onPressed: departments.isEmpty ? null : () => openAssignDepartmentSheet(row),
                                                                style: ElevatedButton.styleFrom(
                                                                  backgroundColor: ColorConst.primaryBlue,
                                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                                ),
                                                                child: const smcText(textToDisplay: 'Assign', textSize: 12, textBoldness: 4, colorOfText: Colors.white),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],

                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ],
                )

                    : selectedMenuIndex == 1
                    ? BasicDetailsScreen(
                  isAdmin: true,
                  orgId: widget.orgId,
                )

                    : selectedMenuIndex == 2
                    ? _buildDepartmentsPage()

                    : const SizedBox()

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

  Widget _buildDepartmentsPage() {

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
        BorderRadius.circular(14),

        border: Border.all(
          color: const Color(0xFFE3EAF8),
        ),
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [

          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,

            children: [

              const smcText(
                textToDisplay: 'Departments',
                textSize: 22,
                textBoldness: 5,
                colorOfText:
                ColorConst.textPrimary,
              ),

              ElevatedButton.icon(

                onPressed:
                openCreateDepartmentSheet,

                icon: const Icon(
                  Icons.add,
                  color: Colors.white,
                ),

                label: const smcText(
                  textToDisplay:
                  'Create Department',

                  textSize: 14,

                  colorOfText:
                  Colors.white,
                ),

                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  ColorConst.primaryBlue,
                ),
              ),

            ],
          ),

          const SizedBox(height: 20),

          Expanded(

            child: departments.isEmpty

                ? const Center(
              child: smcText(
                textToDisplay:
                "No departments added",

                textSize: 15,

                colorOfText:
                ColorConst
                    .textSecondary,
              ),
            )

                : ListView.builder(

              itemCount:
              departments.length,

              itemBuilder:
                  (context,index){

                final dept =
                departments[index];

                return Card(

                  child: ListTile(

                    leading:
                    const CircleAvatar(

                      child: Icon(
                        Icons.account_tree,
                      ),
                    ),

                    title: Text(
                      dept.deptName,
                    ),

                    subtitle: Text(
                      "ID : ${dept.deptId}",
                    ),

                  ),

                );

              },

            ),

          ),

        ],

      ),

    );

  }

  Widget _buildCountCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFF7FAFF),
              icon == Icons.assignment_turned_in_outlined
                  ? const Color(0xFFEFF4FF)
                  : const Color(0xFFF2F9FF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE3EAF8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDCE7FF)),
              ),
              child: Icon(icon, color: ColorConst.primaryBlue, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                smcText(
                  textToDisplay: value,
                  textSize: 18,
                  textBoldness: 5,
                  colorOfText: ColorConst.textPrimary,
                ),
                smcText(
                  textToDisplay: label,
                  textSize: 12,
                  colorOfText: ColorConst.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
