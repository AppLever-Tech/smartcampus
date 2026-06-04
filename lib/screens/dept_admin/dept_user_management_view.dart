import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/data/mock_master_data.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/services/faculty_firestore_service.dart';
import 'package:smartcampus/services/student_firestore_service.dart';
import 'package:smartcampus/services/user_master_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class DeptUserManagementView extends StatefulWidget {
  final String orgId;
  final String deptId;
  final VoidCallback? onUsersChanged;

  const DeptUserManagementView({
    super.key,
    required this.orgId,
    required this.deptId,
    this.onUsersChanged,
  });

  @override
  State<DeptUserManagementView> createState() => _DeptUserManagementViewState();
}

class _DeptUserManagementViewState extends State<DeptUserManagementView> {
  final UserMasterFirestoreService userMasterService =
      UserMasterFirestoreService();
  final StudentFirestoreService studentService = StudentFirestoreService();
  final FacultyFirestoreService facultyService = FacultyFirestoreService();
  final TextEditingController searchController = TextEditingController();

  bool loading = true;
  List<UserMasterItem> users = [];
  String roleFilter = 'All Roles';
  String statusFilter = 'All Status';
  int userRowsPerPage = 25;
  int userCurrentPage = 1;
  String? selectedUserUuid;

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadUsers() async {
    setState(() => loading = true);
    try {
      final loaded = await userMasterService.listForDepartment(
        orgId: widget.orgId,
        deptId: widget.deptId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        users = loaded;
        loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        users = [];
        loading = false;
      });
    }
  }

  List<UserMasterItem> get filteredUsers {
    final query = searchController.text.trim().toLowerCase();
    return users.where((user) {
      final roleOk = _userMatchesRoleCategory(user, roleFilter);
      final statusOk = _matchesStatusFilter(user);
      if (!roleOk || !statusOk) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return user.displayName.toLowerCase().contains(query) ||
          user.uuid.contains(query) ||
          user.userRole.toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  Future<void> approveUser(UserMasterItem user) async {
    await userMasterService.approveUser(user.uuid);
    await loadUsers();
    widget.onUsersChanged?.call();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: smcText(
          textToDisplay: '${user.displayName} approved.',
          textSize: 14,
          colorOfText: Colors.white,
        ),
      ),
    );
  }

  Future<void> classifyUser(UserMasterItem user) async {
    String selectedRole = UserRoles.student;
    final idController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const smcText(
                textToDisplay: 'Classify User',
                textSize: 18,
                textBoldness: 4,
                colorOfText: ColorConst.textPrimary,
              ),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      smcText(
                        textToDisplay: user.displayName,
                        textSize: 15,
                        textBoldness: 4,
                        colorOfText: ColorConst.textPrimary,
                      ),
                      const SizedBox(height: 4),
                      smcText(
                        textToDisplay: user.uuid,
                        textSize: 12,
                        colorOfText: ColorConst.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: InputDecoration(
                          labelText: 'Assign Role',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: UserRoles.student,
                            child: Text('Student'),
                          ),
                          DropdownMenuItem(
                            value: UserRoles.faculty,
                            child: Text('Faculty'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() => selectedRole = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: idController,
                        decoration: InputDecoration(
                          labelText: selectedRole == UserRoles.student
                              ? 'Student ID (USN)'
                              : 'Faculty ID',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'ID is required';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const smcText(
                    textToDisplay: 'Cancel',
                    textSize: 14,
                    colorOfText: ColorConst.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() != true) {
                      return;
                    }
                    Navigator.pop(dialogCtx, true);
                  },
                  child: const smcText(
                    textToDisplay: 'Classify',
                    textSize: 14,
                    textBoldness: 4,
                    colorOfText: ColorConst.primaryBlue,
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) {
      idController.dispose();
      return;
    }

    final String recordId = idController.text.trim().toUpperCase();
    idController.dispose();

    try {
      if (selectedRole == UserRoles.student) {
        final student = StudentModel(
          studentId: recordId,
          fullName: user.displayName,
          gender: '',
          dateOfBirth: '',
          mobile: user.uuid,
          email: '',
          orgId: widget.orgId,
          deptId: widget.deptId,
          createdOn: DateTime.now().toIso8601String(),
        );
        await studentService.createStudent(student);
      } else {
        final faculty = FacultyModel(
          facultyId: recordId,
          fullName: user.displayName,
          gender: '',
          dateOfBirth: '',
          mobile: user.uuid,
          email: '',
          orgId: widget.orgId,
          deptId: widget.deptId,
          createdAt: DateTime.now().toIso8601String(),
        );
        await facultyService.createFaculty(faculty);
      }

      await userMasterService.classifyUser(
        uuid: user.uuid,
        userRole: selectedRole,
        orgId: widget.orgId,
        deptId: widget.deptId,
        userName: user.displayName,
      );

      await loadUsers();
      widget.onUsersChanged?.call();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: smcText(
            textToDisplay:
                '${user.displayName} classified as ${selectedRole == UserRoles.student ? 'Student' : 'Faculty'}.',
            textSize: 14,
            colorOfText: Colors.white,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade600,
          content: smcText(
            textToDisplay: e.toString().replaceFirst('Exception: ', ''),
            textSize: 13,
            colorOfText: Colors.white,
            maxLines: 3,
          ),
        ),
      );
    }
  }

  static const List<MapEntry<String, String>> _assignableRoles = [
    MapEntry(UserRoles.unclassified, 'Unclassified'),
    MapEntry(UserRoles.student, 'Student'),
    MapEntry(UserRoles.faculty, 'Faculty'),
    MapEntry(UserRoles.deptAdmin, 'Dept Admin'),
  ];

  static const List<String> _statusOptions = [
    UserStatus.pendingApproval,
    UserStatus.approved,
  ];

  String _statusForEdit(UserMasterItem user) {
    return user.isApproved ? UserStatus.approved : UserStatus.pendingApproval;
  }

  bool _matchesStatusFilter(UserMasterItem user) {
    if (statusFilter == 'All Status') {
      return true;
    }
    if (statusFilter == UserStatus.approved) {
      return user.isApproved;
    }
    if (statusFilter == UserStatus.pendingApproval) {
      return user.isPendingApproval;
    }
    return user.status.toLowerCase() == statusFilter.toLowerCase();
  }

  String _roleStorageValue(UserMasterItem user) {
    switch (user.normalizedUserRole) {
      case 'STUDENT':
        return UserRoles.student;
      case 'FACULTY':
        return UserRoles.faculty;
      case 'DEPT_ADMIN':
        return UserRoles.deptAdmin;
      case 'UNCLASSIFIED':
        return UserRoles.unclassified;
      default:
        return user.userRole.isNotEmpty
            ? user.userRole
            : UserRoles.unclassified;
    }
  }

  String _roleLabelForValue(String value) {
    for (final entry in _assignableRoles) {
      if (entry.key == value) {
        return entry.value;
      }
    }
    return value;
  }

  Future<void> _openUserAssignmentDialog(UserMasterItem user) async {
    String selectedRole = _roleStorageValue(user);
    String selectedStatus = _statusForEdit(user);
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const smcText(
                textToDisplay: 'User Role & Status',
                textSize: 18,
                textBoldness: 4,
                colorOfText: ColorConst.textPrimary,
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    smcText(
                      textToDisplay: user.displayName,
                      textSize: 15,
                      textBoldness: 4,
                      colorOfText: ColorConst.textPrimary,
                    ),
                    const SizedBox(height: 4),
                    smcText(
                      textToDisplay: user.uuid,
                      textSize: 12,
                      colorOfText: ColorConst.textSecondary,
                    ),
                    const SizedBox(height: 20),
                    const smcText(
                      textToDisplay: 'User Role Assignment',
                      textSize: 13,
                      textBoldness: 4,
                      colorOfText: ColorConst.textPrimary,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _assignableRoles.any((e) => e.key == selectedRole)
                          ? selectedRole
                          : UserRoles.unclassified,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFF),
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
                      items: _assignableRoles
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setDialogState(() => selectedRole = value);
                            },
                    ),
                    const SizedBox(height: 16),
                    const smcText(
                      textToDisplay: 'Status',
                      textSize: 13,
                      textBoldness: 4,
                      colorOfText: ColorConst.textPrimary,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFF),
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
                      items: _statusOptions
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setDialogState(() => selectedStatus = value);
                            },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogCtx),
                  child: const smcText(
                    textToDisplay: 'Cancel',
                    textSize: 14,
                    colorOfText: ColorConst.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setDialogState(() => saving = true);
                          try {
                            await userMasterService.updateUserRoleAndStatus(
                              uuid: user.uuid,
                              userRole: selectedRole,
                              status: selectedStatus,
                            );
                            if (!dialogCtx.mounted) {
                              return;
                            }
                            Navigator.pop(dialogCtx);
                            await loadUsers();
                            widget.onUsersChanged?.call();
                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: smcText(
                                  textToDisplay:
                                      '${user.displayName} updated to ${_roleLabelForValue(selectedRole)} / $selectedStatus.',
                                  textSize: 14,
                                  colorOfText: Colors.white,
                                  maxLines: 2,
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!dialogCtx.mounted) {
                              return;
                            }
                            setDialogState(() => saving = false);
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.red.shade600,
                                content: smcText(
                                  textToDisplay:
                                      e.toString().replaceFirst('Exception: ', ''),
                                  textSize: 13,
                                  colorOfText: Colors.white,
                                  maxLines: 3,
                                ),
                              ),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const smcText(
                          textToDisplay: 'Save',
                          textSize: 14,
                          textBoldness: 4,
                          colorOfText: ColorConst.primaryBlue,
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _selectAndOpenUserDialog(UserMasterItem user) {
    setState(() => selectedUserUuid = user.uuid);
    _openUserAssignmentDialog(user);
  }

  static const List<String> _roleFilterOptions = [
    'All Roles',
    'Unclassified',
    'Student',
    'Faculty',
    'Dept Admin',
  ];

  bool _userMatchesRoleCategory(UserMasterItem user, String label) {
    if (label == 'All Roles') {
      return true;
    }
    final String filterValue = label == 'Dept Admin' ? 'DEPT_ADMIN' : label;
    return user.userRole.toLowerCase() == label.toLowerCase() ||
        user.normalizedUserRole ==
            filterValue.toUpperCase().replaceAll(' ', '_');
  }

  int _roleCategoryCount(String label) {
    if (label == 'All Roles') {
      return users.length;
    }
    return users.where((user) => _userMatchesRoleCategory(user, label)).length;
  }

  Widget _buildRoleFilterChip(String label) {
    final bool isSelected = roleFilter == label;
    final int count = _roleCategoryCount(label);
    return GestureDetector(
      onTap: () => setState(() {
        roleFilter = label;
        userCurrentPage = 1;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? ColorConst.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? ColorConst.primaryBlue : const Color(0xFFE3EAF8),
          ),
        ),
        child: smcText(
          textToDisplay: '$label ($count)',
          textSize: 13,
          textBoldness: isSelected ? 5 : 4,
          colorOfText: isSelected ? Colors.white : ColorConst.textSecondary,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    if (status.toLowerCase().trim() == 'approved') {
      return Colors.green;
    }
    return Colors.orange;
  }

  String _displayRole(UserMasterItem user) {
    if (user.userRole.isEmpty) {
      return '—';
    }
    if (user.normalizedUserRole == 'DEPT_ADMIN') {
      return 'Dept Admin';
    }
    if (user.normalizedUserRole == 'STUDENT') {
      return 'Student';
    }
    if (user.normalizedUserRole == 'FACULTY') {
      return 'Faculty';
    }
    if (user.isUnclassified) {
      return 'Unclassified';
    }
    return user.userRole;
  }

  Widget _buildUserAvatar(UserMasterItem user, {double radius = 18}) {
    final String letter = user.displayName.trim().isEmpty
        ? '?'
        : user.displayName.trim().substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEAF0FF),
      child: smcText(
        textToDisplay: letter,
        textSize: 12,
        textBoldness: 5,
        colorOfText: ColorConst.primaryBlue,
      ),
    );
  }

  Widget _buildBadge(String label, {Color? color}) {
    final Color badgeColor = color ?? ColorConst.primaryBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: smcText(
        textToDisplay: label,
        textSize: 11,
        textBoldness: 3,
        colorOfText: badgeColor,
        maxLines: 1,
      ),
    );
  }

  Widget _buildPaginationFooter({
    required int totalRows,
    required int startIndex,
    required int endIndex,
    required int safePage,
    required int totalPages,
  }) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE3EAF8))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  smcText(
                    textToDisplay: totalRows == 0
                        ? 'Showing 0 entries'
                        : 'Showing ${startIndex + 1} to $endIndex of $totalRows entries',
                    textSize: 12,
                    colorOfText: const Color(0xFF7D87A3),
                  ),
                  const SizedBox(width: 16),
                  const smcText(
                    textToDisplay: 'Rows per page:',
                    textSize: 12,
                    colorOfText: Color(0xFF7D87A3),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: userRowsPerPage,
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10')),
                      DropdownMenuItem(value: 25, child: Text('25')),
                      DropdownMenuItem(value: 50, child: Text('50')),
                      DropdownMenuItem(value: 100, child: Text('100')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          userRowsPerPage = value;
                          userCurrentPage = 1;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: safePage > 1
                        ? () => setState(() => userCurrentPage = 1)
                        : null,
                    icon: const Icon(Icons.first_page_rounded),
                  ),
                  IconButton(
                    onPressed: safePage > 1
                        ? () => setState(() => userCurrentPage = safePage - 1)
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
                        ? () => setState(() => userCurrentPage = safePage + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                  IconButton(
                    onPressed: safePage < totalPages
                        ? () => setState(() => userCurrentPage = totalPages)
                        : null,
                    icon: const Icon(Icons.last_page_rounded),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<UserMasterItem> rows = filteredUsers;
    final int totalRows = rows.length;
    final int totalPages =
        totalRows == 0 ? 1 : ((totalRows - 1) ~/ userRowsPerPage) + 1;
    final int safePage = userCurrentPage.clamp(1, totalPages);
    final int startIndex = (safePage - 1) * userRowsPerPage;
    final int endIndex = (startIndex + userRowsPerPage).clamp(0, totalRows);
    final List<UserMasterItem> pageRows = totalRows == 0
        ? const <UserMasterItem>[]
        : rows.sublist(startIndex, endIndex);

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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  Icons.manage_accounts_outlined,
                  color: ColorConst.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: smcText(
                            textToDisplay: 'User Management',
                            textSize: 16,
                            textBoldness: 5,
                            colorOfText: Color(0xFF1F2F52),
                            maxLines: 1,
                          ),
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
                            textToDisplay: '${users.length}',
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
                          'View, approve, and classify users in your department.',
                      textSize: 12,
                      colorOfText: Color(0xFF7D87A3),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Refresh',
                onPressed: loadUsers,
                icon: const Icon(Icons.refresh_rounded),
                color: ColorConst.primaryBlue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _roleFilterOptions.map(_buildRoleFilterChip).toList(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFCFDFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8EDFA)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool stackFilters = constraints.maxWidth < 560;
                final Widget searchField = SizedBox(
                  height: 44,
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => setState(() => userCurrentPage = 1),
                    decoration: InputDecoration(
                      hintText: 'Search users...',
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
                );
                final Widget statusDropdown = SizedBox(
                  height: 44,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: statusFilter,
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
                    items: const [
                      DropdownMenuItem(
                        value: 'All Status',
                        child: Text('All Status'),
                      ),
                      DropdownMenuItem(
                        value: UserStatus.pendingApproval,
                        child: Text('Pending Approval'),
                      ),
                      DropdownMenuItem(
                        value: UserStatus.approved,
                        child: Text('Approved'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          statusFilter = value;
                          userCurrentPage = 1;
                        });
                      }
                    },
                  ),
                );
                final Widget resetButton = SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        searchController.clear();
                        statusFilter = 'All Status';
                        userCurrentPage = 1;
                      });
                    },
                    child: const smcText(
                      textToDisplay: 'Reset',
                      textSize: 12,
                      textBoldness: 3,
                      colorOfText: Color(0xFF4F5E7D),
                    ),
                  ),
                );

                if (stackFilters) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: statusDropdown),
                          const SizedBox(width: 12),
                          resetButton,
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 3, child: searchField),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: statusDropdown),
                    const SizedBox(width: 12),
                    resetButton,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE3EAF8)),
                    ),
                    child: totalRows == 0
                        ? const Center(
                            child: smcText(
                              textToDisplay: 'No users found for this department.',
                              textSize: 13,
                              colorOfText: Color(0xFF8A96B2),
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final double tableWidth =
                                        constraints.maxWidth;
                                    return SingleChildScrollView(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minWidth: tableWidth,
                                          ),
                                          child: DataTable(
                                            showCheckboxColumn: false,
                                            headingRowHeight: 50,
                                            dataRowMinHeight: 52,
                                            dataRowMaxHeight: 58,
                                            horizontalMargin: 0,
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
                                                  width: 50,
                                                  child: Center(
                                                    child: smcText(
                                                      textToDisplay: 'S.No',
                                                      textSize: 12,
                                                      textBoldness: 4,
                                                      colorOfText: Color(0xFF5C6B8B),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataColumn(
                                                label: SizedBox(
                                                  width: 130,
                                                  child: Padding(
                                                    padding: EdgeInsets.only(left: 8),
                                                    child: Align(
                                                      alignment: Alignment.centerLeft,
                                                      child: smcText(
                                                        textToDisplay: 'UUID',
                                                        textSize: 12,
                                                        textBoldness: 4,
                                                        colorOfText: Color(0xFF5C6B8B),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataColumn(
                                                label: SizedBox(
                                                  width: 220,
                                                  child: Center(
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
                                                  width: 120,
                                                  child: Center(
                                                    child: smcText(
                                                      textToDisplay: 'Role',
                                                      textSize: 12,
                                                      textBoldness: 4,
                                                      colorOfText: Color(0xFF5C6B8B),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataColumn(
                                                label: SizedBox(
                                                  width: 120,
                                                  child: Center(
                                                    child: smcText(
                                                      textToDisplay: 'Status',
                                                      textSize: 12,
                                                      textBoldness: 4,
                                                      colorOfText: Color(0xFF5C6B8B),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataColumn(
                                                label: SizedBox(
                                                  width: 120,
                                                  child: Center(
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
                                            rows: pageRows.asMap().entries.map((entry) {
                                              final int index = entry.key;
                                              final UserMasterItem user =
                                                  entry.value;
                                              final int serialNo =
                                                  startIndex + index + 1;
                                              final bool isSelected =
                                                  selectedUserUuid == user.uuid;
                                              final bool canApprove =
                                                  user.isPendingApproval;
                                              final bool canClassify =
                                                  user.isUnclassified &&
                                                      user.isApproved;
                                              return DataRow(
                                                selected: isSelected,
                                                onSelectChanged: (_) {
                                                  _selectAndOpenUserDialog(user);
                                                },
                                                color: isSelected
                                                    ? WidgetStateProperty.all(
                                                        const Color(0xFFE8F0FE),
                                                      )
                                                    : null,
                                                cells: [
                                                  DataCell(
                                                    Center(
                                                      child: smcText(
                                                        textToDisplay: '$serialNo',
                                                        textSize: 12,
                                                        colorOfText: const Color(0xFF2E3954),
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Padding(
                                                      padding: const EdgeInsets.only(left: 8),
                                                      child: Align(
                                                        alignment: Alignment.centerLeft,
                                                        child: smcText(
                                                          textToDisplay: user.uuid,
                                                          textSize: 12,
                                                          textBoldness: 4,
                                                          colorOfText: const Color(0xFF2E3954),
                                                          maxLines: 1,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Padding(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          _buildUserAvatar(user),
                                                          const SizedBox(width: 10),
                                                          Expanded(
                                                            child: smcText(
                                                              textToDisplay:
                                                                  user.displayName,
                                                              textSize: 12,
                                                              colorOfText:
                                                                  const Color(0xFF2E3954),
                                                              maxLines: 1,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Center(
                                                      child: _buildBadge(
                                                        _displayRole(user),
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Center(
                                                      child: _buildBadge(
                                                        user.displayStatus,
                                                        color: _statusColor(
                                                          user.displayStatus,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Center(
                                                      child: canApprove ||
                                                              canClassify
                                                          ? PopupMenuButton<String>(
                                                              icon: const Icon(
                                                                Icons.more_vert_rounded,
                                                                size: 18,
                                                                color: Color(0xFF8A96B2),
                                                              ),
                                                              onSelected: (val) {
                                                                if (val == 'manage') {
                                                                  _selectAndOpenUserDialog(
                                                                    user,
                                                                  );
                                                                } else if (val ==
                                                                    'approve') {
                                                                  approveUser(user);
                                                                } else if (val ==
                                                                    'classify') {
                                                                  classifyUser(user);
                                                                }
                                                              },
                                                              itemBuilder: (context) => [
                                                                const PopupMenuItem(
                                                                  value: 'manage',
                                                                  child: Text(
                                                                    'Role & Status',
                                                                  ),
                                                                ),
                                                                if (canApprove)
                                                                  const PopupMenuItem(
                                                                    value: 'approve',
                                                                    child: Text('Approve'),
                                                                  ),
                                                                if (canClassify)
                                                                  const PopupMenuItem(
                                                                    value: 'classify',
                                                                    child: Text('Classify'),
                                                                  ),
                                                              ],
                                                            )
                                                          : IconButton(
                                                              padding: EdgeInsets.zero,
                                                              constraints:
                                                                  const BoxConstraints(),
                                                              icon: const Icon(
                                                                Icons.more_vert_rounded,
                                                                size: 18,
                                                                color: Color(0xFF8A96B2),
                                                              ),
                                                              onPressed: () =>
                                                                  _selectAndOpenUserDialog(
                                                                    user,
                                                                  ),
                                                            ),
                                                    ),
                                                    onTap: () =>
                                                        _selectAndOpenUserDialog(user),
                                                  ),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              _buildPaginationFooter(
                                totalRows: totalRows,
                                startIndex: startIndex,
                                endIndex: endIndex,
                                safePage: safePage,
                                totalPages: totalPages,
                              ),
                            ],
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
