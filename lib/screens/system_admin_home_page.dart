import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/mock_master_data.dart';
import 'package:smartcampus/screens/landing_page.dart';
import 'package:smartcampus/services/org_role_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';
import 'package:url_launcher/url_launcher.dart';

class SystemAdminHomePage extends StatefulWidget {
  final String systemAdminName;

  const SystemAdminHomePage({super.key, required this.systemAdminName});

  @override
  State<SystemAdminHomePage> createState() => SystemAdminHomePageState();
}

class SystemAdminHomePageState extends State<SystemAdminHomePage> {
  final OrgRoleFirestoreService roleService = OrgRoleFirestoreService();
  final GlobalKey<FormState> createOrgFormKey = GlobalKey<FormState>();
  final TextEditingController orgNameController = TextEditingController();
  final TextEditingController orgAddressController = TextEditingController();
  final TextEditingController orgWebsiteController = TextEditingController();
  final TextEditingController orgIdController = TextEditingController();
  final TextEditingController organizationSearchController =
      TextEditingController();
  String selectedOrgType = 'College';
  String selectedTypeFilter = 'All Types';
  bool sortOrgIdAscending = true;
  int rowsPerPage = 10;
  int currentPage = 1;
  bool loadingList = true;
  bool savingOrg = false;
  String selectedMenu = 'Dashboard';
  List<OrgUserRoleMappingItem> pendingOrgAdmins = <OrgUserRoleMappingItem>[];
  List<OrganizationItem> organizations = <OrganizationItem>[];

  static const List<String> orgTypes = <String>[
    'College',
    'Company',
    'Research Institute',
    'Training Center',
  ];

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  @override
  void dispose() {
    orgNameController.dispose();
    orgAddressController.dispose();
    orgWebsiteController.dispose();
    orgIdController.dispose();
    organizationSearchController.dispose();
    super.dispose();
  }

  Future<void> refreshData() async {
    setState(() {
      loadingList = true;
    });
    try {
      final pending = await roleService.listPendingOrgAdmins();
      final orgs = await roleService.loadAllOrganizations();
      if (!mounted) {
        return;
      }
      setState(() {
        pendingOrgAdmins = pending;
        organizations = orgs;
        loadingList = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        pendingOrgAdmins = <OrgUserRoleMappingItem>[];
        loadingList = false;
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

  Future<void> openOrganizationWebsite(String rawUrl) async {
    final String trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final String normalized = trimmed.startsWith('http://') ||
            trimmed.startsWith('https://')
        ? trimmed
        : 'https://$trimmed';
    final Uri uri = Uri.parse(normalized);
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: smcText(
            textToDisplay: 'Unable to open website link.',
            textSize: 13,
            colorOfText: Colors.white,
          ),
        ),
      );
    }
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
                'For help with SmartCampus access or data, contact your platform owner or IT support.',
            textSize: 14,
            colorOfText: ColorConst.textSecondary,
            maxLines: 6,
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

  void onMenuTap(String menu) {
    if (menu == 'Notification') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: smcText(
            textToDisplay: 'No new notifications.',
            textSize: 13,
            colorOfText: Colors.white,
          ),
        ),
      );
      return;
    }
    if (menu == 'Support') {
      onSupport();
      return;
    }
    if (menu == 'Logout') {
      onLogout();
      return;
    }
    setState(() {
      selectedMenu = menu;
    });
  }

  Widget buildLeftMenu() {
    return Container(
      width: 255,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF7F9FF)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE7ECF8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x112B4A88),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5D7CFF), Color(0xFF3A62F6)],
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.school_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: smcText(
                  textToDisplay: 'SmartCampus',
                  textSize: 22,
                  textBoldness: 5,
                  colorOfText: Color(0xFF1F2F52),
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          buildLeftMenuItem(
            icon: Icons.dashboard_outlined,
            title: 'Dashboard',
            isActive: selectedMenu == 'Dashboard',
            onTap: () => onMenuTap('Dashboard'),
          ),
          const SizedBox(height: 8),
          buildLeftMenuItem(
            icon: Icons.support_agent_rounded,
            title: 'Support',
            isActive: false,
            onTap: () => onMenuTap('Support'),
          ),
          const SizedBox(height: 8),
          buildLeftMenuItem(
            icon: Icons.notifications_none_rounded,
            title: 'Notification',
            isActive: false,
            onTap: () => onMenuTap('Notification'),
          ),
          const SizedBox(height: 8),
          buildLeftMenuItem(
            icon: Icons.logout_outlined,
            title: 'Logout',
            isActive: false,
            onTap: () => onMenuTap('Logout'),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget buildLeftMenuItem({
    required IconData icon,
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFFEEF3FF), Color(0xFFE4EDFF)],
                )
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? const Color(0xFFD9E6FF) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  isActive ? const Color(0xFF305EF6) : const Color(0xFF7D87A3),
              size: 20,
            ),
            const SizedBox(width: 10),
            smcText(
              textToDisplay: title,
              textSize: 14,
              textBoldness: 4,
              colorOfText:
                  isActive ? const Color(0xFF305EF6) : const Color(0xFF2E3954),
            ),
          ],
        ),
      ),
    );
  }

  void openCreateOrganizationSheet() {
    orgNameController.clear();
    orgAddressController.clear();
    orgWebsiteController.clear();
    orgIdController.clear();
    selectedOrgType = 'College';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: MediaQuery.paddingOf(ctx).bottom + 18,
              ),
              child: Form(
                key: createOrgFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const smcText(
                        textToDisplay: 'Create organisation',
                        textSize: 20,
                        textBoldness: 5,
                        colorOfText: ColorConst.textPrimary,
                      ),
                      const SizedBox(height: 8),
                      const smcText(
                        textToDisplay:
                            'Organisation is stored in smcOrganization. Org ID must be exactly 6 digits (you can change it later).',
                        textSize: 13,
                        colorOfText: ColorConst.textSecondary,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: orgIdController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration:
                            fieldDecoration('Organisation ID (6 digits)'),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (!RegExp(r'^\d{6}$').hasMatch(t)) {
                            return 'Enter exactly 6 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: orgNameController,
                        decoration: fieldDecoration('Organisation name'),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      InputDecorator(
                        decoration: fieldDecoration('Organisation type'),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedOrgType,
                            isExpanded: true,
                            items: orgTypes
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setModal(() {
                                  selectedOrgType = v;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: orgAddressController,
                        maxLines: 2,
                        decoration: fieldDecoration('Address'),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: orgWebsiteController,
                        decoration: fieldDecoration('Website (optional)'),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: savingOrg ? null : submitCreateOrganization,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorConst.primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: savingOrg
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const smcText(
                                  textToDisplay: 'Save organisation',
                                  textSize: 15,
                                  textBoldness: 4,
                                  colorOfText: Colors.white,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      counterText: '',
      filled: true,
      fillColor: const Color(0xFFFCFDFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ColorConst.borderSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ColorConst.borderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ColorConst.primaryBlue),
      ),
    );
  }

  Future<void> submitCreateOrganization() async {
    if (!(createOrgFormKey.currentState?.validate() ?? false) || savingOrg) {
      return;
    }
    setState(() {
      savingOrg = true;
    });
    try {
      await roleService.createOrUpdateOrganization(
        orgIdSix: orgIdController.text.trim(),
        orgName: orgNameController.text.trim(),
        orgType: selectedOrgType,
        orgAddress: orgAddressController.text.trim(),
        orgWebsite: orgWebsiteController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: smcText(
            textToDisplay: 'Organisation saved to smcOrganization.',
            textSize: 14,
            colorOfText: Colors.white,
            maxLines: 2,
          ),
        ),
      );
      await refreshData();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: smcText(
            textToDisplay: 'Could not save organisation.',
            textSize: 14,
            colorOfText: Colors.white,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          savingOrg = false;
        });
      }
    }
  }

  Future<void> openUserDetailSheet(OrgUserRoleMappingItem mapping) async {
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
                  textToDisplay: 'Organisation admin (registered)',
                  textSize: 18,
                  textBoldness: 5,
                  colorOfText: ColorConst.textPrimary,
                ),
                const SizedBox(height: 12),
                smcText(
                  textToDisplay: 'Name: ${mapping.name}',
                  textSize: 14,
                  colorOfText: ColorConst.textPrimary,
                  maxLines: 2,
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
                    onPressed: organizations.isEmpty
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            openAssignOrganizationSheet(mapping);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorConst.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const smcText(
                      textToDisplay: 'Add to organisation',
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

  void openAssignOrganizationSheet(OrgUserRoleMappingItem mapping) {
    String? chosenOrgId =
        organizations.isNotEmpty ? organizations.first.orgId : null;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            OrganizationItem? organizationById(String? id) {
              if (id == null) {
                return null;
              }
              for (final o in organizations) {
                if (o.orgId.toUpperCase() == id.toUpperCase()) {
                  return o;
                }
              }
              return null;
            }

            final OrganizationItem? chosenOrg =
                organizationById(chosenOrgId);

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
                    textToDisplay: 'Assign organisation',
                    textSize: 18,
                    textBoldness: 5,
                    colorOfText: ColorConst.textPrimary,
                  ),
                  const SizedBox(height: 12),
                  const smcText(
                    textToDisplay:
                        'Pick an organisation from smcOrganization / master list.',
                    textSize: 13,
                    colorOfText: ColorConst.textSecondary,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: fieldDecoration('Organisation'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: chosenOrgId,
                        isExpanded: true,
                        items: organizations
                            .map(
                              (o) => DropdownMenuItem<String>(
                                value: o.orgId,
                                child: Text('${o.orgName} (${o.orgId})'),
                              ),
                            )
                            .toList(),
                        onChanged: (id) {
                          setModalState(() {
                            chosenOrgId = id;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: chosenOrg == null
                          ? null
                          : () async {
                              try {
                                await roleService.assignOrgAdminToOrganization(
                                  mapping: mapping,
                                  organization: chosenOrg,
                                );
                                if (!context.mounted) {
                                  return;
                                }
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: smcText(
                                      textToDisplay:
                                          'User assigned and approved.',
                                      textSize: 14,
                                      colorOfText: Colors.white,
                                    ),
                                  ),
                                );
                                await refreshData();
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
                        textToDisplay: 'Confirm assignment',
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
    final bool compactLayout = MediaQuery.sizeOf(context).width < 960;
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3FF),
      /*floatingActionButton: FloatingActionButton.extended(
        onPressed: openCreateOrganizationSheet,
        backgroundColor: const Color(0xFF3A62F6),
        elevation: 2,
        icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
        label: const smcText(
          textToDisplay: 'Create organisation',
          textSize: 14,
          textBoldness: 4,
          colorOfText: Colors.white,
        ),
      ),*/
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const smcText(
          textToDisplay: 'System admin',
          textSize: 20,
          textBoldness: 4,
          colorOfText: ColorConst.textPrimary,
        ),
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEDF2FF), Color(0xFFEAF0FF)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: compactLayout
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildLeftMenu(),
                      const SizedBox(height: 14),
                      Expanded(child: buildOrganisationContent()),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildLeftMenu(),
                      const SizedBox(width: 18),
                      Expanded(child: buildOrganisationContent()),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget buildOrganisationContent() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE0E8FB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x162B4A88),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

         /* buildTopHeaderBar(),
          const SizedBox(height: 14),
          buildSummaryCard(
            title: 'Total Organisations',
            value: '${organizations.length}',
            subtitle: 'All organisations in SmartCampus',
            icon: Icons.apartment_rounded,
            iconColor: const Color(0xFF13A568),
            iconBackground: const Color(0xFFE9FAF2),
          ),*/
          const SizedBox(height: 14),
          Expanded(
            child: loadingList
                ? const Center(child: CircularProgressIndicator())
                : buildOrganisationTable(),
          ),
        ],
      ),
    );
  }

  Widget buildOrganisationTable() {
    final String searchTerm = organizationSearchController.text.trim().toLowerCase();
    final List<OrganizationItem> typeFiltered = selectedTypeFilter == 'All Types'
        ? organizations
        : organizations.where((item) => item.orgType == selectedTypeFilter).toList();
    final List<OrganizationItem> searched = typeFiltered.where((item) {
      if (searchTerm.isEmpty) {
        return true;
      }
      final String target =
          '${item.orgId} ${item.orgName} ${item.orgType} ${item.orgWebsite}'
              .toLowerCase();
      return target.contains(searchTerm);
    }).toList();
    searched.sort((a, b) => sortOrgIdAscending
        ? a.orgId.compareTo(b.orgId)
        : b.orgId.compareTo(a.orgId));
    final int totalRows = searched.length;
    final int totalPages = totalRows == 0 ? 1 : ((totalRows - 1) ~/ rowsPerPage) + 1;
    final int safePage = currentPage.clamp(1, totalPages);
    final int startIndex = (safePage - 1) * rowsPerPage;
    final int endIndex = (startIndex + rowsPerPage).clamp(0, totalRows);
    final List<OrganizationItem> pageRows =
        totalRows == 0 ? <OrganizationItem>[] : searched.sublist(startIndex, endIndex);
    final List<String> availableTypes = <String>{
      'All Types',
      ...organizations.map((item) => item.orgType).where((e) => e.isNotEmpty),
    }.toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4EBFB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.business_outlined,
                  color: ColorConst.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const smcText(
                        textToDisplay: 'Total Organisations',
                        textSize: 16,
                        textBoldness: 5,
                        colorOfText: Color(0xFF1F2F52),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF4FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: smcText(
                          textToDisplay: '${organizations.length}',
                          textSize: 12,
                          textBoldness: 4,
                          colorOfText: ColorConst.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const smcText(
                    textToDisplay:
                        'View and manage all organisations in the system.',
                    textSize: 12,
                    colorOfText: Color(0xFF7D87A3),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: openCreateOrganizationSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A62F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: const smcText(
                    textToDisplay: 'Add Organisation',
                    textSize: 13,
                    textBoldness: 4,
                    colorOfText: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFCFDFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8EDFA)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: organizationSearchController,
                      onChanged: (_) => setState(() => currentPage = 1),
                      decoration: InputDecoration(
                        hintText: 'Search organisations...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: Color(0xFF8A96B2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: ColorConst.primaryBlue),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 44,
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedTypeFilter,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: ColorConst.primaryBlue),
                        ),
                      ),
                      items: availableTypes
                          .map(
                            (type) =>
                                DropdownMenuItem<String>(value: type, child: Text(type)),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          selectedTypeFilter = value;
                          currentPage = 1;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        sortOrgIdAscending = !sortOrgIdAscending;
                      });
                    },
                    icon: Icon(
                      sortOrgIdAscending
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 16,
                    ),
                    label: const smcText(
                      textToDisplay: 'Sort by Org ID',
                      textSize: 12,
                      textBoldness: 3,
                      colorOfText: Color(0xFF4F5E7D),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        organizationSearchController.clear();
                        selectedTypeFilter = 'All Types';
                        sortOrgIdAscending = true;
                        currentPage = 1;
                      });
                    },
                    child: const smcText(
                      textToDisplay: 'Reset',
                      textSize: 12,
                      textBoldness: 3,
                      colorOfText: Color(0xFF4F5E7D),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE3EAF8)),
              ),
              child: totalRows == 0
                  ? const Center(
                      child: smcText(
                        textToDisplay: 'No organisations found.',
                        textSize: 13,
                        colorOfText: Color(0xFF8A96B2),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double tableWidth = constraints.maxWidth;
                              const double orgIdWidth = 90;
                              const double typeWidth = 120;
                              const double actionWidth = 74;
                              final double remainingWidth = tableWidth -
                                  orgIdWidth -
                                  typeWidth -
                                  actionWidth;
                              final double nameWidth = (remainingWidth * 0.45).clamp(170, 340);
                              final double websiteWidth =
                                  (remainingWidth - nameWidth).clamp(180, 420);

                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: tableWidth),
                                  child: DataTable(
                                    showCheckboxColumn: false,
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
                                    headingRowColor: WidgetStateProperty.all(
                                      const Color(0xFFF4F7FF),
                                    ),
                                    columns: [
                                      DataColumn(
                                        label: SizedBox(
                                          width: orgIdWidth,
                                          child: const Center(
                                            child: smcText(
                                              textToDisplay: 'Org ID',
                                              textSize: 12,
                                              textBoldness: 4,
                                              colorOfText: Color(0xFF5C6B8B),
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: SizedBox(
                                          width: nameWidth,
                                          child: const Center(
                                            child: smcText(
                                              textToDisplay: 'Name',
                                              textSize: 12,
                                              textBoldness: 4,
                                              colorOfText: Color(0xFF5C6B8B),
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: SizedBox(
                                          width: typeWidth,
                                          child: const Center(
                                            child: smcText(
                                              textToDisplay: 'Type',
                                              textSize: 12,
                                              textBoldness: 4,
                                              colorOfText: Color(0xFF5C6B8B),
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: SizedBox(
                                          width: websiteWidth,
                                          child: const Center(
                                            child: smcText(
                                              textToDisplay: 'Website',
                                              textSize: 12,
                                              textBoldness: 4,
                                              colorOfText: Color(0xFF5C6B8B),
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: SizedBox(
                                          width: actionWidth,
                                          child: const Center(
                                            child: smcText(
                                              textToDisplay: 'Actions',
                                              textSize: 12,
                                              textBoldness: 4,
                                              colorOfText: Color(0xFF5C6B8B),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows: pageRows.map((org) {
                                      return DataRow(
                                        onSelectChanged: (_) =>
                                            openOrganizationDetailsSheet(org),
                                        cells: [
                                          DataCell(
                                            SizedBox(
                                              width: orgIdWidth,
                                              child: Center(
                                                child: smcText(
                                                  textToDisplay: org.orgId,
                                                  textSize: 12,
                                                  textBoldness: 5,
                                                  colorOfText: ColorConst.primaryBlue,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: nameWidth,
                                              child: Center(
                                                child: smcText(
                                                  textToDisplay: org.orgName,
                                                  textSize: 12,
                                                  colorOfText: const Color(0xFF2E3954),
                                                  maxLines: 1,
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: typeWidth,
                                              child: Center(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEFF4FF),
                                                    borderRadius:
                                                        BorderRadius.circular(999),
                                                  ),
                                                  child: smcText(
                                                    textToDisplay: org.orgType,
                                                    textSize: 11,
                                                    textBoldness: 3,
                                                    colorOfText:
                                                        const Color(0xFF3558DA),
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: websiteWidth,
                                              child: Center(
                                                child: org.orgWebsite.isEmpty
                                                    ? const smcText(
                                                        textToDisplay: '-',
                                                        textSize: 12,
                                                        colorOfText: Color(0xFF6E7A96),
                                                        maxLines: 1,
                                                      )
                                                    : InkWell(
                                                        onTap: () =>
                                                            openOrganizationWebsite(
                                                          org.orgWebsite,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(6),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Flexible(
                                                              child: smcText(
                                                                textToDisplay:
                                                                    org.orgWebsite,
                                                                textSize: 12,
                                                                colorOfText: const Color(
                                                                  0xFF2D67B7,
                                                                ),
                                                                maxLines: 1,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 6),
                                                            const Icon(
                                                              Icons.open_in_new_rounded,
                                                              size: 15,
                                                              color: Color(0xFF2D67B7),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ),
                                          const DataCell(
                                            Center(
                                              child: Icon(
                                                Icons.more_vert_rounded,
                                                size: 18,
                                                color: Color(0xFF8A96B2),
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
                        Container(
                          height: 58,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0xFFE3EAF8)),
                            ),
                          ),
                          child: Row(
                            children: [
                              smcText(
                                textToDisplay: totalRows == 0
                                    ? 'Showing 0 entries'
                                    : 'Showing ${startIndex + 1} to $endIndex of $totalRows entries',
                                textSize: 12,
                                colorOfText: const Color(0xFF7D87A3),
                              ),
                              const Spacer(),
                              const smcText(
                                textToDisplay: 'Rows per page:',
                                textSize: 12,
                                colorOfText: Color(0xFF7D87A3),
                              ),
                              const SizedBox(width: 8),
                              DropdownButton<int>(
                                value: rowsPerPage,
                                items: const [
                                  DropdownMenuItem(value: 10, child: Text('10')),
                                  DropdownMenuItem(value: 25, child: Text('25')),
                                  DropdownMenuItem(value: 50, child: Text('50')),
                                ],
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() {
                                    rowsPerPage = value;
                                    currentPage = 1;
                                  });
                                },
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: safePage > 1
                                    ? () => setState(() => currentPage = 1)
                                    : null,
                                icon: const Icon(Icons.first_page_rounded),
                              ),
                              IconButton(
                                onPressed: safePage > 1
                                    ? () => setState(() => currentPage = safePage - 1)
                                    : null,
                                icon: const Icon(Icons.chevron_left_rounded),
                              ),
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF0FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: smcText(
                                  textToDisplay: '$safePage',
                                  textSize: 12,
                                  textBoldness: 4,
                                  colorOfText: ColorConst.primaryBlue,
                                ),
                              ),
                              IconButton(
                                onPressed: safePage < totalPages
                                    ? () => setState(() => currentPage = safePage + 1)
                                    : null,
                                icon: const Icon(Icons.chevron_right_rounded),
                              ),
                              IconButton(
                                onPressed: safePage < totalPages
                                    ? () => setState(() => currentPage = totalPages)
                                    : null,
                                icon: const Icon(Icons.last_page_rounded),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> openOrganizationDetailsSheet(OrganizationItem organization) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SystemAdminOrganizationDetailsPage(
          organization: organization,
          roleService: roleService,
        ),
      ),
    );
    if (updated == true && mounted) {
      await refreshData();
    }
  }

  Widget buildTopHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5ECFB)),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: CircleAvatar(
          radius: 17,
          backgroundColor: const Color(0xFFEAF0FF),
          child: smcText(
            textToDisplay: widget.systemAdminName.isEmpty
                ? 'A'
                : widget.systemAdminName.substring(0, 1).toUpperCase(),
            textSize: 13,
            textBoldness: 4,
            colorOfText: ColorConst.primaryBlue,
          ),
        ),
      ),
    );
  }

  Widget buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EBFB)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                smcText(
                  textToDisplay: title,
                  textSize: 12,
                  textBoldness: 3,
                  colorOfText: const Color(0xFF7D87A3),
                  maxLines: 1,
                ),
                const SizedBox(height: 3),
                smcText(
                  textToDisplay: value,
                  textSize: 22,
                  textBoldness: 5,
                  colorOfText: const Color(0xFF1C2E52),
                ),
                smcText(
                  textToDisplay: subtitle,
                  textSize: 11,
                  colorOfText: const Color(0xFF8D98B4),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  
}

class SystemAdminOrganizationDetailsPage extends StatefulWidget {
  final OrganizationItem organization;
  final OrgRoleFirestoreService roleService;

  const SystemAdminOrganizationDetailsPage({
    super.key,
    required this.organization,
    required this.roleService,
  });

  @override
  State<SystemAdminOrganizationDetailsPage> createState() =>
      SystemAdminOrganizationDetailsPageState();
}

class SystemAdminOrganizationDetailsPageState
    extends State<SystemAdminOrganizationDetailsPage> {
  List<UserMasterItem> allUsers = <UserMasterItem>[];
  String? assigningUuid;
  bool loadingUsers = true;
  final TextEditingController assigneeSearchController = TextEditingController();
  int selectedSectionIndex = 0;

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    try {
      final users = await widget.roleService.listAllUsers();
      if (!mounted) {
        return;
      }
      setState(() {
        allUsers = users;
        loadingUsers = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        allUsers = <UserMasterItem>[];
        loadingUsers = false;
      });
    }
  }

  @override
  void dispose() {
    assigneeSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sortedUsers = [...allUsers]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final String search = assigneeSearchController.text.trim().toLowerCase();
    final filteredUsers = sortedUsers.where((user) {
      if (search.isEmpty) {
        return true;
      }
      final target = '${user.name} ${user.mobile} ${user.uuid}'.toLowerCase();
      return target.contains(search);
    }).toList();
    final bool isBasicInfoSelected = selectedSectionIndex == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 64,
        surfaceTintColor: Colors.white,
        leadingWidth: 190,
        leading: TextButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 18,
            color: ColorConst.textSecondary,
          ),
          label: const smcText(
            textToDisplay: 'Back to Organisations',
            textSize: 14,
            colorOfText: ColorConst.textSecondary,
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4FE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.apartment_rounded,
                color: ColorConst.primaryBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            smcText(
              textToDisplay: widget.organization.orgName,
              textSize: 30,
              textBoldness: 4,
              colorOfText: ColorConst.textPrimary,
            ),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFDDE2EB)),
        ),
      ),
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 180,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Color(0xFFDDE2EB))),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildSectionTile(
                      title: 'Basic Info',
                      icon: Icons.info_rounded,
                      isSelected: isBasicInfoSelected,
                      onTap: () {
                        setState(() {
                          selectedSectionIndex = 0;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildSectionTile(
                      title: 'Add Assignee',
                      icon: Icons.person_add_alt_1_rounded,
                      isSelected: !isBasicInfoSelected,
                      onTap: () {
                        setState(() {
                          selectedSectionIndex = 1;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: isBasicInfoSelected
                  ? _buildBasicInfoView(context)
                  : _buildAssigneeView(filteredUsers),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTile({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEAF0FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),
              Icon(
                icon,
                size: 16,
                color: isSelected ? ColorConst.primaryBlue : ColorConst.textSecondary,
              ),
              const SizedBox(width: 10),
              smcText(
                textToDisplay: title,
                textSize: 14,
                textBoldness: isSelected ? 4 : 3,
                colorOfText: isSelected
                    ? ColorConst.primaryBlue
                    : ColorConst.textPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const smcText(
            textToDisplay: 'Basic Info',
            textSize: 34,
            textBoldness: 5,
            colorOfText: ColorConst.textPrimary,
          ),
          const SizedBox(height: 4),
          const smcText(
            textToDisplay: 'View organisation details and information.',
            textSize: 14,
            colorOfText: ColorConst.textSecondary,
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE3E7EE)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x100B1D4D),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const smcText(
                  textToDisplay: 'Organisation Details',
                  textSize: 22,
                  textBoldness: 5,
                  colorOfText: ColorConst.textPrimary,
                ),
                const SizedBox(height: 10),
                _buildInfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Org ID',
                  value: widget.organization.orgId,
                ),
                _buildInfoRow(
                  icon: Icons.apartment_rounded,
                  label: 'Name',
                  value: widget.organization.orgName,
                ),
                _buildInfoRow(
                  icon: Icons.school_outlined,
                  label: 'Type',
                  value: widget.organization.orgType,
                ),
                _buildInfoRow(
                  icon: Icons.language_rounded,
                  label: 'Website',
                  value: widget.organization.orgWebsite.isEmpty
                      ? '-'
                      : widget.organization.orgWebsite,
                  isLink: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isLink = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE9EDF3))),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4FE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: ColorConst.primaryBlue),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: smcText(
              textToDisplay: label,
              textSize: 14,
              colorOfText: ColorConst.textSecondary,
            ),
          ),
          const smcText(
            textToDisplay: ':',
            textSize: 14,
            colorOfText: ColorConst.textSecondary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: isLink && value != '-'
                ? InkWell(
                    onTap: () async {
                      final String normalized = value.startsWith('http')
                          ? value
                          : 'https://$value';
                      await launchUrl(
                        Uri.parse(normalized),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    child: Row(
                      children: [
                        Flexible(
                          child: smcText(
                            textToDisplay: value,
                            textSize: 14,
                            textBoldness: 4,
                            colorOfText: ColorConst.primaryBlue,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.open_in_new_rounded,
                          size: 15,
                          color: ColorConst.primaryBlue,
                        ),
                      ],
                    ),
                  )
                : smcText(
                    textToDisplay: value,
                    textSize: 14,
                    textBoldness: 4,
                    colorOfText: ColorConst.textPrimary,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssigneeView(List<UserMasterItem> filteredUsers) {
    if (loadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7E9EE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: ColorConst.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: assigneeSearchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Search by name,mobile',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              smcText(
                textToDisplay: 'Total Users: ${filteredUsers.length}',
                textSize: 13,
                textBoldness: 4,
                colorOfText: ColorConst.textPrimary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filteredUsers.isEmpty
              ? const Center(
                  child: smcText(
                    textToDisplay: 'No users available.',
                    textSize: 13,
                    colorOfText: ColorConst.textSecondary,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filteredUsers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final bool isAssigning = assigningUuid == user.uuid;
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F5)),
                      ),
                      child: ListTile(
                        leading: _buildUserAvatar(user),
                        title: smcText(
                          textToDisplay: user.name,
                          textSize: 14,
                          textBoldness: 4,
                          colorOfText: const Color(0xFF4F3B6A),
                        ),
                        subtitle: smcText(
                          textToDisplay:
                              'Mob: ${user.mobile.isEmpty ? user.uuid : user.mobile}',
                          textSize: 12,
                          colorOfText: ColorConst.textSecondary,
                        ),
                        trailing: IconButton(
                          onPressed: isAssigning
                              ? null
                              : () async {
                                  setState(() {
                                    assigningUuid = user.uuid;
                                  });
                                  try {
                                    final mapping = OrgUserRoleMappingItem(
                                      uuid: user.uuid,
                                      orgId: widget.organization.orgId,
                                      roleId: '',
                                      name: user.name,
                                      status: 'Registered',
                                    );
                                    await widget.roleService.assignOrgAdminToOrganization(
                                      mapping: mapping,
                                      organization: widget.organization,
                                    );
                                    if (!context.mounted) {
                                      return;
                                    }
                                    setState(() {
                                      assigningUuid = null;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: const Color(0xFF0F9D58),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        content: Row(
                                          children: [
                                            const Icon(
                                              Icons.verified_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: smcText(
                                                textToDisplay:
                                                    'Assigned successfully to ${widget.organization.orgName}',
                                                textSize: 14,
                                                textBoldness: 4,
                                                colorOfText: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  } catch (error) {
                                    if (!context.mounted) {
                                      return;
                                    }
                                    setState(() {
                                      assigningUuid = null;
                                    });
                                    final message = error
                                        .toString()
                                        .replaceFirst('StateError: ', '')
                                        .trim();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: const Color(0xFFC62828),
                                        content: smcText(
                                          textToDisplay: message.isEmpty
                                              ? 'Failed to assign org admin.'
                                              : message,
                                          textSize: 13,
                                          colorOfText: Colors.white,
                                          maxLines: 2,
                                        ),
                                      ),
                                    );
                                  }
                                },
                          icon: isAssigning
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: ColorConst.primaryBlue,
                                ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUserAvatar(UserMasterItem user) {
    final String imageUrl = _normalizedImageUrl(user.photoUrl);
    final String fallbackLetter = user.name.trim().isEmpty
        ? 'U'
        : user.name.trim().substring(0, 1).toUpperCase();

    if (imageUrl.isEmpty) {
      return CircleAvatar(
        backgroundColor: const Color(0xFFE9EEFF),
        child: smcText(
          textToDisplay: fallbackLetter,
          textSize: 13,
          textBoldness: 5,
          colorOfText: ColorConst.primaryBlue,
        ),
      );
    }

    return CircleAvatar(
      backgroundColor: const Color(0xFFE9EEFF),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            return smcText(
              textToDisplay: fallbackLetter,
              textSize: 13,
              textBoldness: 5,
              colorOfText: ColorConst.primaryBlue,
            );
          },
        ),
      ),
    );
  }

  String _normalizedImageUrl(String rawUrl) {
    String value = rawUrl.trim();
    if (value.isEmpty) {
      return '';
    }
    if (value.startsWith('gs://')) {
      return '';
    }
    try {
      value = Uri.decodeFull(value);
    } catch (_) {
      // keep original value if decode fails
    }
    if (value.startsWith('//')) {
      value = 'https:$value';
    }
    if (!(value.startsWith('http://') || value.startsWith('https://'))) {
      return '';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      return '';
    }
    return uri.toString();
  }
}
