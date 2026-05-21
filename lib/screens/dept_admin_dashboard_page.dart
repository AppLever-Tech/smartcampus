import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/mock_master_data.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/screens/landing_page.dart';
import 'package:smartcampus/screens/person_detail_page.dart';
import 'package:smartcampus/services/faculty_firestore_service.dart';
import 'package:smartcampus/services/student_firestore_service.dart';
import 'package:smartcampus/services/org_role_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class DeptAdminDashboardPage extends StatefulWidget {
  final String orgId;
  final String deptId;
  final String adminName;

  const DeptAdminDashboardPage({
    super.key,
    required this.orgId,
    this.deptId = '',
    required this.adminName,
  });

  @override
  State<DeptAdminDashboardPage> createState() => DeptAdminDashboardPageState();
}

class DeptAdminDashboardPageState extends State<DeptAdminDashboardPage> {
  final OrgRoleFirestoreService roleService = OrgRoleFirestoreService();
  final FacultyFirestoreService facultyService = FacultyFirestoreService();
  final StudentFirestoreService studentService = StudentFirestoreService();

  bool loading = true;
  int selectedMenuIndex = 0; // 0: Dashboard, 1: Students, 2: Faculties
  List<OrgUserRoleMappingItem> facultyAndStudents = [];
  List<DepartmentMasterItem> departments = [];
  List<FacultyModel> facultyList = [];
  List<StudentModel> studentList = [];
  String organizationDisplayName = '';
  bool canEditOrDelete = false;

  // Search and Pagination for Students
  final TextEditingController studentSearchController = TextEditingController();
  int studentRowsPerPage = 10;
  int studentCurrentPage = 1;
  String studentGenderFilter = 'All';

  // Search and Pagination for Faculty
  final TextEditingController facultySearchController = TextEditingController();
  int facultyRowsPerPage = 10;
  int facultyCurrentPage = 1;
  String facultyGenderFilter = 'All';

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    studentSearchController.dispose();
    facultySearchController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final people = await roleService.listFacultyAndStudentsForOrg(widget.orgId);
      final depts = await roleService.loadDepartmentsForOrg(widget.orgId);
      final org = await roleService.authService.getOrganizationById(widget.orgId);
      final faculty = await facultyService.listFacultyForDept(
        orgId: widget.orgId,
        deptId: widget.deptId,
      );
      final students = await studentService.listStudentsForDept(
        orgId: widget.orgId,
        deptId: widget.deptId,
      );

      bool allowed = false;
      if (currentUser != null) {
        // 1. Check if creator of the department
        final currentDept = depts.where((d) => d.deptId == widget.deptId).firstOrNull;
        if (currentDept != null && currentDept.createdBy == currentUser.uid) {
          allowed = true;
        } else {
          // 2. Check if user has DEPT_ADMIN role for this specific department
          final mappings = await roleService.getAllRoleMappingsForUuid(currentUser.uid);
          allowed = mappings.any((m) =>
              m.normalizedRoleId == 'DEPT_ADMIN' &&
              m.orgId.toUpperCase() == widget.orgId.toUpperCase() &&
              m.deptId.toUpperCase() == widget.deptId.toUpperCase()
          );
        }
      }

      if (!mounted) return;
      setState(() {
        canEditOrDelete = allowed;
        facultyAndStudents = people;
        departments = depts;
        facultyList = faculty;
        studentList = students;
        organizationDisplayName =
        (org?.orgName ?? '').trim().isEmpty ? widget.orgId : org!.orgName;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        facultyAndStudents = [];
        loading = false;
      });
    }
  }

  Future<void> onLogout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LandingPage()),
          (route) => false,
    );
  }

  void onSupport() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
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
      ),
    );
  }

  // ── Assign Department sheet (existing) ────────────────────────

  Future<void> openAssignDepartmentSheet(OrgUserRoleMappingItem mapping) async {
    if (departments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: smcText(
            textToDisplay: 'No departments found. Please add departments first.',
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
              if (id == null) return null;
              for (final d in departments) {
                if (d.deptId == id) return d;
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
                          setModalState(() => chosenDeptId = id);
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
                          await roleService.assignFacultyOrStudentDepartment(
                            mapping: mapping,
                            department: chosen,
                          );
                          if (!context.mounted) return;
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
                          if (!context.mounted) return;
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

  // ── Create/Edit Student bottom sheet ──────────────────────────

  Future<void> openCreateStudentSheet({StudentModel? studentToEdit, bool isViewOnly = false}) async {
    final formKey = GlobalKey<FormState>();

    // Basic Profile
    final studentIdCtrl = TextEditingController(text: studentToEdit?.studentId ?? '');
    final fullNameCtrl = TextEditingController(text: studentToEdit?.fullName ?? '');
    String selectedGender = studentToEdit?.gender ?? 'Male';
    DateTime? selectedDob;
    if (studentToEdit?.dateOfBirth != null && studentToEdit!.dateOfBirth.isNotEmpty) {
      try {
        selectedDob = DateTime.parse(studentToEdit.dateOfBirth);
      } catch (_) {}
    }
    final dobCtrl = TextEditingController(
      text: selectedDob != null
          ? '${selectedDob.day.toString().padLeft(2, '0')}/${selectedDob.month.toString().padLeft(2, '0')}/${selectedDob.year}'
          : '',
    );

    // Identity / Category
    final aadhaarCtrl = TextEditingController(text: studentToEdit?.aadhaarNumber ?? '');
    String selectedCategory = studentToEdit?.category ?? 'Gen';
    String selectedNationality = studentToEdit?.nationality ?? 'Indian';
    String selectedBloodGroup = studentToEdit?.bloodGroup ?? 'A+';

    // Contact
    final mobileCtrl = TextEditingController(text: studentToEdit?.mobile ?? '');
    final emailCtrl = TextEditingController(text: studentToEdit?.email ?? '');

    // Address
    final permanentAddrCtrl = TextEditingController(text: studentToEdit?.permanentAddress ?? '');
    final correspondenceAddrCtrl = TextEditingController(text: studentToEdit?.correspondenceAddress ?? '');

    // Emergency Contact
    final emergNameCtrl = TextEditingController(text: studentToEdit?.emergencyContactName ?? '');
    final emergRelationCtrl = TextEditingController(text: studentToEdit?.emergencyContactRelation ?? '');
    final emergMobileCtrl = TextEditingController(text: studentToEdit?.emergencyContactMobile ?? '');

    bool saving = false;
    Uint8List? photographBytes;
    String? photographUrl = studentToEdit?.photographUrl;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            InputDecoration _fieldDecor(String label, {String? hint}) =>
                InputDecoration(
                  labelText: label,
                  hintText: hint,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    color: ColorConst.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: ColorConst.borderSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: ColorConst.borderSoft),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: ColorConst.primaryBlue,
                      width: 1.2,
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFD),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                );

            Widget _sectionHeader(String title, IconData icon) => Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: ColorConst.primaryBlue),
                  const SizedBox(width: 6),
                  smcText(
                    textToDisplay: title,
                    textSize: 12,
                    textBoldness: 4,
                    colorOfText: ColorConst.primaryBlue,
                  ),
                ],
              ),
            );

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 4,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 12,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 32,
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCE2F4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: smcText(
                              textToDisplay: isViewOnly ? 'Student Details' : (studentToEdit == null ? 'Create Student' : 'Edit Student'),
                              textSize: 18,
                              textBoldness: 5,
                              colorOfText: ColorConst.textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: ColorConst.textSecondary,
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),

                      _sectionHeader('Basic Profile Information', Icons.person_outline_rounded),
                      TextFormField(
                        controller: studentIdCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Student ID (USN) *', hint: 'e.g. 1AB20CS001'),
                        textCapitalization: TextCapitalization.characters,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Student ID is required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: fullNameCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Full Name *'),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedGender,
                        decoration: _fieldDecor('Gender *'),
                        items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: isViewOnly ? null : (v) => setModalState(() => selectedGender = v!),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: dobCtrl,
                        readOnly: true,
                        decoration: _fieldDecor('Date of Birth *').copyWith(
                          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
                        ),
                        onTap: isViewOnly ? null : () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime(2005),
                            firstDate: DateTime(1990),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setModalState(() {
                              selectedDob = picked;
                              dobCtrl.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                            });
                          }
                        },
                        validator: (_) => selectedDob == null ? 'Date of birth is required' : null,
                      ),
                      const SizedBox(height: 8),

                      GestureDetector(
                        onTap: isViewOnly ? null : () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            setModalState(() => photographBytes = bytes);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ColorConst.borderSoft),
                          ),
                          child: photographBytes != null
                              ? Image.memory(photographBytes!, height: 80, fit: BoxFit.cover)
                              : Row(children: [const Icon(Icons.photo_camera_outlined, size: 16), const SizedBox(width: 8), Text(isViewOnly ? 'Photograph' : 'Upload Photograph', style: const TextStyle(fontSize: 12))]),
                        ),
                      ),

                      _sectionHeader('Identity & Category', Icons.verified_user_outlined),
                      TextFormField(
                        controller: aadhaarCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Aadhaar / Govt ID'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: _fieldDecor('Category *'),
                        items: ['Gen', 'OBC', 'SC', 'ST'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: isViewOnly ? null : (v) => setModalState(() => selectedCategory = v!),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedNationality,
                        decoration: _fieldDecor('Nationality *'),
                        items: ['Indian', 'NRI', 'Foreigner'].map((n) => DropdownMenuItem(value: n, child: Text(n, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: isViewOnly ? null : (v) => setModalState(() => selectedNationality = v!),
                      ),
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 4),
                        child: smcText(textToDisplay: 'Blood Group *', textSize: 12, colorOfText: ColorConst.textSecondary),
                      ),
                      Wrap(
                        spacing: 4,
                        runSpacing: 0,
                        children: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'].map((bg) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Radio<String>(
                                value: bg,
                                groupValue: selectedBloodGroup,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                activeColor: ColorConst.primaryBlue,
                                onChanged: isViewOnly ? null : (v) => setModalState(() => selectedBloodGroup = v!),
                              ),
                              smcText(textToDisplay: bg, textSize: 12, colorOfText: ColorConst.textPrimary),
                              const SizedBox(width: 4),
                            ],
                          );
                        }).toList(),
                      ),

                      _sectionHeader('Contact Details', Icons.contact_phone_outlined),
                      TextFormField(
                        controller: mobileCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Mobile Number *'),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: emailCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Email Address *'),
                        keyboardType: TextInputType.emailAddress,
                      ),

                      _sectionHeader('Address', Icons.home_outlined),
                      TextFormField(
                        controller: permanentAddrCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Permanent Address'),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: correspondenceAddrCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Correspondence Address'),
                        maxLines: 1,
                      ),

                      _sectionHeader('Emergency Contact (Parent/Guardian)', Icons.emergency_outlined),
                      TextFormField(controller: emergNameCtrl, readOnly: isViewOnly, decoration: _fieldDecor('Contact Person Name')),
                      const SizedBox(height: 6),
                      TextFormField(controller: emergRelationCtrl, readOnly: isViewOnly, decoration: _fieldDecor('Relation')),
                      const SizedBox(height: 6),
                      TextFormField(controller: emergMobileCtrl, readOnly: isViewOnly, decoration: _fieldDecor('Emergency Mobile'), keyboardType: TextInputType.phone),

                      const SizedBox(height: 12),
                      if (!isViewOnly)
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: saving ? null : () async {
                            if (!formKey.currentState!.validate()) return;
                            setModalState(() => saving = true);

                            if (photographBytes != null) {
                              final ref = FirebaseStorage.instance
                                  .ref()
                                  .child('student_photos')
                                  .child('${studentIdCtrl.text.trim().toUpperCase()}_${DateTime.now().millisecondsSinceEpoch}.jpg');
                              await ref.putData(photographBytes!, SettableMetadata(contentType: 'image/jpeg'));
                              photographUrl = await ref.getDownloadURL();
                            }

                            final student = StudentModel(
                              documentId: studentToEdit?.documentId,
                              studentId: studentIdCtrl.text.trim().toUpperCase(),
                              fullName: fullNameCtrl.text.trim(),
                              gender: selectedGender,
                              dateOfBirth: selectedDob?.toIso8601String().split('T')[0] ?? '',
                              photographUrl: photographUrl ?? '',
                              aadhaarNumber: aadhaarCtrl.text.trim(),
                              category: selectedCategory,
                              nationality: selectedNationality,
                              bloodGroup: selectedBloodGroup,
                              mobile: mobileCtrl.text.trim(),
                              email: emailCtrl.text.trim().toLowerCase(),
                              permanentAddress: permanentAddrCtrl.text.trim(),
                              correspondenceAddress: correspondenceAddrCtrl.text.trim(),
                              emergencyContactName: emergNameCtrl.text.trim(),
                              emergencyContactRelation: emergRelationCtrl.text.trim(),
                              emergencyContactMobile: emergMobileCtrl.text.trim(),
                              orgId: widget.orgId,
                              deptId: widget.deptId,
                              createdAt: studentToEdit?.createdAt ?? DateTime.now().toIso8601String(),
                            );

                            try {
                              if (studentToEdit != null) {
                                await studentService.updateStudent(documentId: studentToEdit.documentId!, updated: student);
                              } else {
                                await studentService.createStudent(student);
                              }
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.green.shade600,
                                  content: smcText(
                                    textToDisplay: 'Student ${studentToEdit == null ? 'added' : 'updated'} successfully.',
                                    textSize: 14,
                                    colorOfText: Colors.white,
                                  ),
                                ),
                              );
                              await refresh();
                            } catch (e) {
                              if (!ctx.mounted) return;
                              setModalState(() => saving = false);
                              final errorMsg = e.toString().replaceFirst('Exception: ', '');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.red.shade600,
                                  content: smcText(
                                    textToDisplay: 'Error: $errorMsg',
                                    textSize: 13,
                                    colorOfText: Colors.white,
                                    maxLines: 3,
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: ColorConst.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          child: saving ? const CircularProgressIndicator(color: Colors.white) : smcText(textToDisplay: studentToEdit == null ? 'Save Student' : 'Update Student', textSize: 15, colorOfText: Colors.white),
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

  // ── Create/Edit Faculty bottom sheet ──────────────────────────

  Future<void> openCreateFacultySheet({FacultyModel? facultyToEdit, bool isViewOnly = false}) async {
    final formKey = GlobalKey<FormState>();

    // Controllers — Basic Profile
    final facultyIdCtrl = TextEditingController(text: facultyToEdit?.facultyId ?? '');
    final fullNameCtrl = TextEditingController(text: facultyToEdit?.fullName ?? '');
    String selectedGender = facultyToEdit?.gender ?? 'Male';
    DateTime? selectedDob;
    if (facultyToEdit?.dateOfBirth != null && facultyToEdit!.dateOfBirth.isNotEmpty) {
      try {
        selectedDob = DateTime.parse(facultyToEdit.dateOfBirth);
      } catch (_) {}
    }
    final dobCtrl = TextEditingController(
      text: selectedDob != null
          ? '${selectedDob.day.toString().padLeft(2, '0')}/${selectedDob.month.toString().padLeft(2, '0')}/${selectedDob.year}'
          : '',
    );

    // Compliance
    final aadhaarCtrl = TextEditingController(text: facultyToEdit?.aadhaarNumber ?? '');
    final panCtrl = TextEditingController(text: facultyToEdit?.panNumber ?? '');

    // Contact
    final mobileCtrl = TextEditingController(text: facultyToEdit?.mobile ?? '');
    final emailCtrl = TextEditingController(text: facultyToEdit?.email ?? '');

    // Address
    final permanentAddrCtrl = TextEditingController(text: facultyToEdit?.permanentAddress ?? '');
    final currentAddrCtrl = TextEditingController(text: facultyToEdit?.currentAddress ?? '');

    // Emergency Contact
    final emergNameCtrl = TextEditingController(text: facultyToEdit?.emergencyContactName ?? '');
    final emergRelationCtrl = TextEditingController(text: facultyToEdit?.emergencyContactRelation ?? '');
    final emergMobileCtrl = TextEditingController(text: facultyToEdit?.emergencyContactMobile ?? '');

    bool saving = false;
    Uint8List? photographBytes;
    String? photographUrl = facultyToEdit?.photographUrl;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            // ── helpers ────────────────────────────────────────
            InputDecoration _fieldDecor(String label, {String? hint}) =>
                InputDecoration(
                  labelText: label,
                  hintText: hint,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    color: ColorConst.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: ColorConst.borderSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: ColorConst.borderSoft),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: ColorConst.primaryBlue,
                      width: 1.2,
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFD),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                );

            Widget _sectionHeader(String title, IconData icon) => Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: ColorConst.primaryBlue),
                  const SizedBox(width: 6),
                  smcText(
                    textToDisplay: title,
                    textSize: 12,
                    textBoldness: 4,
                    colorOfText: ColorConst.primaryBlue,
                  ),
                ],
              ),
            );

            // ── sheet body ─────────────────────────────────────
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 4,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 12,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── drag handle ────────────────────────
                      Center(
                        child: Container(
                          width: 32,
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCE2F4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),

                      // ── title row ─────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: smcText(
                              textToDisplay: isViewOnly ? 'Faculty Details' : (facultyToEdit == null ? 'Create Faculty' : 'Edit Faculty'),
                              textSize: 18,
                              textBoldness: 5,
                              colorOfText: ColorConst.textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: ColorConst.textSecondary,
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),

                      // ══════════════════════════════════════
                      // 1. Basic Profile Information
                      // ══════════════════════════════════════
                      _sectionHeader(
                        'Basic Profile Information',
                        Icons.person_outline_rounded,
                      ),

                      // Faculty / Employee ID
                      TextFormField(
                        controller: facultyIdCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor(
                          'Faculty / Employee ID *',
                          hint: 'e.g. FAC-2024-001',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Faculty ID is required'
                            : null,
                      ),
                      const SizedBox(height: 8),

                      // Full Name
                      TextFormField(
                        controller: fullNameCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Full Name *'),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Full name is required'
                            : null,
                      ),
                      const SizedBox(height: 8),

                      // Gender dropdown
                      DropdownButtonFormField<String>(
                        value: selectedGender,
                        decoration: _fieldDecor('Gender *'),
                        borderRadius: BorderRadius.circular(10),
                        items: const [
                          'Male',
                          'Female',
                          'Other',
                          'Prefer not to say',
                        ]
                            .map(
                              (g) => DropdownMenuItem(
                            value: g,
                            child: Text(g, style: const TextStyle(fontSize: 13)),
                          ),
                        )
                            .toList(),
                        onChanged: isViewOnly ? null : (v) {
                          if (v != null) {
                            setModalState(() => selectedGender = v);
                          }
                        },
                      ),
                      const SizedBox(height: 8),

                      // Date of Birth — tap-to-pick
                      TextFormField(
                        controller: dobCtrl,
                        readOnly: true,
                        decoration: _fieldDecor('Date of Birth *').copyWith(
                          suffixIcon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: ColorConst.textSecondary,
                          ),
                        ),
                        onTap: isViewOnly ? null : () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime(1990),
                            firstDate: DateTime(1940),
                            lastDate: DateTime.now()
                                .subtract(const Duration(days: 365 * 18)),
                            helpText: 'Select Date of Birth',
                          );
                          if (picked != null) {
                            setModalState(() {
                              selectedDob = picked;
                              dobCtrl.text =
                              '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                            });
                          }
                        },
                        validator: (_) =>
                        selectedDob == null ? 'Date of birth is required' : null,
                      ),
                      const SizedBox(height: 8),

                      // Photograph upload
                      GestureDetector(
                        onTap: isViewOnly ? null : () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 70,
                            maxWidth: 600,
                          );
                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            setModalState(() {
                              photographBytes = bytes;
                            });
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ColorConst.borderSoft),
                          ),
                          child: photographBytes != null
                              ? Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  photographBytes!,
                                  height: 80,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if (!isViewOnly)
                              GestureDetector(
                                onTap: () => setModalState(() => photographBytes = null),
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          )
                              : Row(
                            children: [
                              const Icon(Icons.photo_camera_outlined, size: 16, color: ColorConst.primaryBlue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: smcText(
                                  textToDisplay: isViewOnly ? 'Photograph' : 'Tap to upload photograph (optional)',
                                  textSize: 12,
                                  colorOfText: ColorConst.textSecondary,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ══════════════════════════════════════
                      // 2. India-Specific Compliance
                      // ══════════════════════════════════════
                      _sectionHeader(
                        'Compliance (Aadhaar / PAN)',
                        Icons.verified_user_outlined,
                      ),

                      TextFormField(
                        controller: aadhaarCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Aadhaar Number'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (v.trim().length != 12) {
                            return 'Aadhaar must be 12 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: panCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('PAN Number'),
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
                          if (!panRegex.hasMatch(v.trim().toUpperCase())) {
                            return 'Invalid PAN (e.g. ABCDE1234F)';
                          }
                          return null;
                        },
                      ),

                      // ══════════════════════════════════════
                      // 3. Contact Details
                      // ══════════════════════════════════════
                      _sectionHeader(
                        'Contact Details',
                        Icons.contact_phone_outlined,
                      ),

                      TextFormField(
                        controller: mobileCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Mobile Number *'),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Mobile number is required';
                          }
                          if (v.trim().length != 10) {
                            return 'Enter valid 10-digit mobile number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: emailCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Email Address *'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          final emailRegex =
                          RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
                          if (!emailRegex.hasMatch(v.trim())) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),

                      // ══════════════════════════════════════
                      // 4. Address
                      // ══════════════════════════════════════
                      _sectionHeader(
                        'Address',
                        Icons.home_outlined,
                      ),

                      TextFormField(
                        controller: permanentAddrCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Permanent Address'),
                        maxLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: currentAddrCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Current Address'),
                        maxLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                      ),

                      // ══════════════════════════════════════
                      // 5. Emergency Contact
                      // ══════════════════════════════════════
                      _sectionHeader(
                        'Emergency Contact',
                        Icons.emergency_outlined,
                      ),

                      TextFormField(
                        controller: emergNameCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Contact Person Name'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: emergRelationCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor(
                          'Relation',
                          hint: 'e.g. Spouse, Parent, Sibling',
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: emergMobileCtrl,
                        readOnly: isViewOnly,
                        decoration: _fieldDecor('Emergency Mobile'),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (v.trim().length != 10) {
                            return 'Enter valid 10-digit number';
                          }
                          return null;
                        },
                      ),

                      // ── Save button ────────────────────────
                      const SizedBox(height: 16),
                      if (!isViewOnly)
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: saving
                              ? null
                              : () async {
                            if (!formKey.currentState!.validate()) return;
                            setModalState(() => saving = true);

                            // Upload photo if selected
                            if (photographBytes != null) {
                              final ref = FirebaseStorage.instance
                                  .ref()
                                  .child('faculty_photos')
                                  .child('${facultyIdCtrl.text.trim().toUpperCase()}_${DateTime.now().millisecondsSinceEpoch}.jpg');
                              await ref.putData(
                                photographBytes!,
                                SettableMetadata(contentType: 'image/jpeg'),
                              );
                              photographUrl = await ref.getDownloadURL();
                            }

                            final faculty = FacultyModel(
                              documentId: facultyToEdit?.documentId,
                              facultyId: facultyIdCtrl.text.trim().toUpperCase(),
                              fullName: fullNameCtrl.text.trim(),
                              gender: selectedGender,
                              dateOfBirth: selectedDob != null
                                  ? '${selectedDob!.year}-'
                                  '${selectedDob!.month.toString().padLeft(2, '0')}-'
                                  '${selectedDob!.day.toString().padLeft(2, '0')}'
                                  : '',
                              aadhaarNumber: aadhaarCtrl.text.trim(),
                              panNumber: panCtrl.text.trim().toUpperCase(),
                              mobile: mobileCtrl.text.trim(),
                              email: emailCtrl.text.trim().toLowerCase(),
                              permanentAddress: permanentAddrCtrl.text.trim(),
                              currentAddress: currentAddrCtrl.text.trim(),
                              emergencyContactName: emergNameCtrl.text.trim(),
                              emergencyContactRelation:
                              emergRelationCtrl.text.trim(),
                              emergencyContactMobile:
                              emergMobileCtrl.text.trim(),
                              orgId: widget.orgId,
                              deptId: widget.deptId,
                              photographUrl: photographUrl ?? '',
                              createdAt: facultyToEdit?.createdAt ?? DateTime.now().toIso8601String(),
                            );

                            try {
                              if (facultyToEdit != null) {
                                await facultyService.updateFaculty(
                                  documentId: facultyToEdit.documentId!,
                                  updated: faculty,
                                );
                              } else {
                                await facultyService.createFaculty(faculty);
                              }
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.green.shade600,
                                  content: smcText(
                                    textToDisplay:
                                    '${faculty.fullName} ${facultyToEdit == null ? 'added' : 'updated'} successfully.',
                                    textSize: 14,
                                    colorOfText: Colors.white,
                                  ),
                                ),
                              );
                              await refresh();
                            } catch (e) {
                              if (!ctx.mounted) return;
                              setModalState(() => saving = false);
                              final errorMsg = e.toString().replaceFirst('Exception: ', '');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.red.shade600,
                                  content: smcText(
                                    textToDisplay: 'Error: $errorMsg',
                                    textSize: 13,
                                    colorOfText: Colors.white,
                                    maxLines: 3,
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorConst.primaryBlue,
                            disabledBackgroundColor: ColorConst.primaryBlue.withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: saving
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                              : smcText(
                            textToDisplay: facultyToEdit == null ? 'Save Faculty' : 'Update Faculty',
                            textSize: 15,
                            textBoldness: 4,
                            colorOfText: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
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

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Row(
          children: [
            // ── Side nav ────────────────────────────────────────
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
                      textToDisplay: 'Department Admin',
                      textSize: 20,
                      textBoldness: 5,
                      colorOfText: ColorConst.textPrimary,
                    ),
                    const SizedBox(height: 20),
                    _menuTile(
                      title: 'Dashboard',
                      icon: Icons.dashboard_outlined,
                      isSelected: selectedMenuIndex == 0,
                      onTap: () => setState(() => selectedMenuIndex = 0),
                    ),
                    const SizedBox(height: 8),
                    _menuTile(
                      title: 'Students',
                      icon: Icons.school_outlined,
                      isSelected: selectedMenuIndex == 1,
                      onTap: () => setState(() => selectedMenuIndex = 1),
                    ),
                    const SizedBox(height: 8),
                    _menuTile(
                      title: 'Faculties',
                      icon: Icons.people_alt_outlined,
                      isSelected: selectedMenuIndex == 2,
                      onTap: () => setState(() => selectedMenuIndex = 2),
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

            // ── Main content ─────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome + Organization Info
                    Row(
                      children: [
                        Expanded(
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

                    const SizedBox(height: 16),

                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildSelectedView(),
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

  Widget _buildSelectedView() {
    switch (selectedMenuIndex) {
      case 1:
        return _buildStudentsView();
      case 2:
        return _buildFacultiesView();
      default:
        return _buildDashboardView();
    }
  }

  Widget _buildDashboardView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const smcText(
          textToDisplay: 'Department Overview',
          textSize: 16,
          textBoldness: 5,
          colorOfText: ColorConst.textPrimary,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard(
              title: 'Total Students',
              count: studentList.length.toString(),
              icon: Icons.school_rounded,
              color: Colors.blue,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              title: 'Total Faculty',
              count: facultyList.length.toString(),
              icon: Icons.people_alt_rounded,
              color: Colors.green,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({required String title, required String count, required IconData icon, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3EAF8)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                smcText(
                  textToDisplay: title,
                  textSize: 13,
                  colorOfText: ColorConst.textSecondary,
                ),
                smcText(
                  textToDisplay: count,
                  textSize: 20,
                  textBoldness: 5,
                  colorOfText: ColorConst.textPrimary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: smcText(
                textToDisplay: 'Students in your department',
                textSize: 14,
                textBoldness: 3,
                colorOfText: ColorConst.textSecondary,
              ),
            ),
            ElevatedButton.icon(
              onPressed: openCreateStudentSheet,
              icon: const Icon(Icons.school_rounded, size: 18, color: Colors.white),
              label: const smcText(
                textToDisplay: 'Create Student',
                textSize: 14,
                textBoldness: 4,
                colorOfText: Colors.white,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorConst.primaryBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(child: buildStudentTable()),
      ],
    );
  }

  Widget _buildFacultiesView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: smcText(
                textToDisplay: 'Faculty in your department',
                textSize: 14,
                textBoldness: 3,
                colorOfText: ColorConst.textSecondary,
              ),
            ),
            ElevatedButton.icon(
              onPressed: openCreateFacultySheet,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Colors.white),
              label: const smcText(
                textToDisplay: 'Create Faculty',
                textSize: 14,
                textBoldness: 4,
                colorOfText: Colors.white,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorConst.primaryBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(child: buildFacultyTable()),
      ],
    );
  }

  // ── Student Table ───────────────────────────────────────────

  Widget buildStudentTable() {
    final String searchTerm = studentSearchController.text.trim().toLowerCase();
    final List<StudentModel> genderFiltered = studentGenderFilter == 'All'
        ? studentList
        : studentList.where((s) => s.gender == studentGenderFilter).toList();
    final List<StudentModel> searched = genderFiltered.where((s) {
      if (searchTerm.isEmpty) return true;
      return '${s.studentId} ${s.fullName} ${s.gender} ${s.category}'
          .toLowerCase()
          .contains(searchTerm);
    }).toList();

    final int totalRows = searched.length;
    final int totalPages = totalRows == 0 ? 1 : ((totalRows - 1) ~/ studentRowsPerPage) + 1;
    final int safePage = studentCurrentPage.clamp(1, totalPages);
    final int startIndex = (safePage - 1) * studentRowsPerPage;
    final int endIndex = (startIndex + studentRowsPerPage).clamp(0, totalRows);
    final List<StudentModel> pageRows =
        totalRows == 0 ? <StudentModel>[] : searched.sublist(startIndex, endIndex);

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
                child: const Icon(Icons.school_outlined, color: ColorConst.primaryBlue),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const smcText(
                        textToDisplay: 'Student List',
                        textSize: 16,
                        textBoldness: 5,
                        colorOfText: Color(0xFF1F2F52),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF4FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: smcText(
                          textToDisplay: '${studentList.length}',
                          textSize: 12,
                          textBoldness: 4,
                          colorOfText: ColorConst.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const smcText(
                    textToDisplay: 'View and manage all students in your department.',
                    textSize: 12,
                    colorOfText: Color(0xFF7D87A3),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search and Filters
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
                      controller: studentSearchController,
                      onChanged: (_) => setState(() => studentCurrentPage = 1),
                      decoration: InputDecoration(
                        hintText: 'Search students...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF8A96B2)),
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
                      value: studentGenderFilter,
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
                      items: ['All', 'Male', 'Female', 'Other']
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            studentGenderFilter = v;
                            studentCurrentPage = 1;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        studentSearchController.clear();
                        studentGenderFilter = 'All';
                        studentCurrentPage = 1;
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
                        textToDisplay: 'No students found.',
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
                                    border: TableBorder.all(color: const Color(0xFFE3EAF8), width: 1),
                                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF4F7FF)),
                                    columns: const [
                                      DataColumn(label: SizedBox(width: 100, child: Center(child: smcText(textToDisplay: 'USN / ID', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 180, child: Center(child: smcText(textToDisplay: 'Name', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 100, child: Center(child: smcText(textToDisplay: 'Gender', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 120, child: Center(child: smcText(textToDisplay: 'Category', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 100, child: Center(child: smcText(textToDisplay: 'Photo', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 80, child: Center(child: smcText(textToDisplay: 'Actions', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                    ],
                                    rows: pageRows.map((s) {
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Center(
                                              child: InkWell(
                                                onTap: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => PersonDetailPage(person: s, isStudent: true),
                                                  ),
                                                ),
                                                child: smcText(
                                                  textToDisplay: s.studentId,
                                                  textSize: 12,
                                                  textBoldness: 4,
                                                  colorOfText: Colors.blue,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(Center(child: smcText(textToDisplay: s.fullName, textSize: 12, colorOfText: const Color(0xFF2E3954), maxLines: 1))),
                                          DataCell(
                                            Center(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(color: const Color(0xFFEFF4FF), borderRadius: BorderRadius.circular(999)),
                                                child: smcText(textToDisplay: s.gender, textSize: 11, textBoldness: 3, colorOfText: const Color(0xFF3558DA)),
                                              ),
                                            ),
                                          ),
                                          DataCell(Center(child: smcText(textToDisplay: s.category, textSize: 12, colorOfText: const Color(0xFF2E3954)))),
                                          DataCell(
                                            Center(
                                              child: s.photographUrl.isNotEmpty
                                                  ? InkWell(
                                                      onTap: () async {
                                                        final uri = Uri.parse(s.photographUrl);
                                                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                                                      },
                                                      child: const Icon(Icons.image_outlined, size: 18, color: ColorConst.primaryBlue),
                                                    )
                                                  : const Icon(Icons.image_not_supported_outlined, size: 18, color: Colors.grey),
                                            ),
                                          ),
                                          DataCell(
                                            Center(
                                              child: PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF8A96B2)),
                                                onSelected: (val) {
                                                  if (val == 'edit') openCreateStudentSheet(studentToEdit: s);
                                                  else if (val == 'delete') _deleteStudentWithConfirmation(s);
                                                },
                                                itemBuilder: (context) => [
                                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                                                ],
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
                        // Pagination
                        Container(
                          height: 58,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE3EAF8)))),
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
                              const smcText(textToDisplay: 'Rows per page:', textSize: 12, colorOfText: Color(0xFF7D87A3)),
                              const SizedBox(width: 8),
                              DropdownButton<int>(
                                value: studentRowsPerPage,
                                items: const [
                                  DropdownMenuItem(value: 10, child: Text('10')),
                                  DropdownMenuItem(value: 25, child: Text('25')),
                                  DropdownMenuItem(value: 50, child: Text('50')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      studentRowsPerPage = value;
                                      studentCurrentPage = 1;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: safePage > 1 ? () => setState(() => studentCurrentPage = 1) : null,
                                icon: const Icon(Icons.first_page_rounded),
                              ),
                              IconButton(
                                onPressed: safePage > 1 ? () => setState(() => studentCurrentPage = safePage - 1) : null,
                                icon: const Icon(Icons.chevron_left_rounded),
                              ),
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: const Color(0xFFEAF0FF), borderRadius: BorderRadius.circular(8)),
                                child: smcText(textToDisplay: '$safePage', textSize: 12, textBoldness: 4, colorOfText: ColorConst.primaryBlue),
                              ),
                              IconButton(
                                onPressed: safePage < totalPages ? () => setState(() => studentCurrentPage = safePage + 1) : null,
                                icon: const Icon(Icons.chevron_right_rounded),
                              ),
                              IconButton(
                                onPressed: safePage < totalPages ? () => setState(() => studentCurrentPage = totalPages) : null,
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

  Future<void> _deleteStudentWithConfirmation(StudentModel student) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Are you sure you want to delete ${student.fullName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true && student.documentId != null) {
      try {
        await studentService.deleteStudent(student.documentId!);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student deleted successfully')));
        refresh();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Faculty Table ───────────────────────────────────────────

  Widget buildFacultyTable() {
    final String searchTerm = facultySearchController.text.trim().toLowerCase();
    final List<FacultyModel> genderFiltered = facultyGenderFilter == 'All'
        ? facultyList
        : facultyList.where((f) => f.gender == facultyGenderFilter).toList();
    final List<FacultyModel> searched = genderFiltered.where((f) {
      if (searchTerm.isEmpty) return true;
      return '${f.facultyId} ${f.fullName} ${f.gender} ${f.email}'
          .toLowerCase()
          .contains(searchTerm);
    }).toList();

    final int totalRows = searched.length;
    final int totalPages = totalRows == 0 ? 1 : ((totalRows - 1) ~/ facultyRowsPerPage) + 1;
    final int safePage = facultyCurrentPage.clamp(1, totalPages);
    final int startIndex = (safePage - 1) * facultyRowsPerPage;
    final int endIndex = (startIndex + facultyRowsPerPage).clamp(0, totalRows);
    final List<FacultyModel> pageRows =
        totalRows == 0 ? <FacultyModel>[] : searched.sublist(startIndex, endIndex);

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
                child: const Icon(Icons.people_alt_outlined, color: ColorConst.primaryBlue),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const smcText(
                        textToDisplay: 'Faculty List',
                        textSize: 16,
                        textBoldness: 5,
                        colorOfText: Color(0xFF1F2F52),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF4FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: smcText(
                          textToDisplay: '${facultyList.length}',
                          textSize: 12,
                          textBoldness: 4,
                          colorOfText: ColorConst.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const smcText(
                    textToDisplay: 'View and manage all faculty in your department.',
                    textSize: 12,
                    colorOfText: Color(0xFF7D87A3),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search and Filters
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
                      controller: facultySearchController,
                      onChanged: (_) => setState(() => facultyCurrentPage = 1),
                      decoration: InputDecoration(
                        hintText: 'Search faculty...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF8A96B2)),
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
                      value: facultyGenderFilter,
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
                      items: ['All', 'Male', 'Female', 'Other', 'Prefer not to say']
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            facultyGenderFilter = v;
                            facultyCurrentPage = 1;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        facultySearchController.clear();
                        facultyGenderFilter = 'All';
                        facultyCurrentPage = 1;
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
                        textToDisplay: 'No faculty found.',
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
                                    border: TableBorder.all(color: const Color(0xFFE3EAF8), width: 1),
                                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF4F7FF)),
                                    columns: const [
                                      DataColumn(label: SizedBox(width: 120, child: Center(child: smcText(textToDisplay: 'Faculty ID', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 180, child: Center(child: smcText(textToDisplay: 'Name', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 100, child: Center(child: smcText(textToDisplay: 'Gender', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 200, child: Center(child: smcText(textToDisplay: 'Email', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 100, child: Center(child: smcText(textToDisplay: 'Photo', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                      DataColumn(label: SizedBox(width: 80, child: Center(child: smcText(textToDisplay: 'Actions', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                    ],
                                    rows: pageRows.map((f) {
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Center(
                                              child: InkWell(
                                                onTap: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => PersonDetailPage(person: f, isStudent: false),
                                                  ),
                                                ),
                                                child: smcText(
                                                  textToDisplay: f.facultyId,
                                                  textSize: 12,
                                                  textBoldness: 4,
                                                  colorOfText: Colors.blue,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(Center(child: smcText(textToDisplay: f.fullName, textSize: 12, colorOfText: const Color(0xFF2E3954), maxLines: 1))),
                                          DataCell(
                                            Center(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(color: const Color(0xFFEFF4FF), borderRadius: BorderRadius.circular(999)),
                                                child: smcText(textToDisplay: f.gender, textSize: 11, textBoldness: 3, colorOfText: const Color(0xFF3558DA)),
                                              ),
                                            ),
                                          ),
                                          DataCell(Center(child: smcText(textToDisplay: f.email, textSize: 12, colorOfText: const Color(0xFF718096), maxLines: 1))),
                                          DataCell(
                                            Center(
                                              child: f.photographUrl.isNotEmpty
                                                  ? InkWell(
                                                      onTap: () async {
                                                        final uri = Uri.parse(f.photographUrl);
                                                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                                                      },
                                                      child: const Icon(Icons.image_outlined, size: 18, color: ColorConst.primaryBlue),
                                                    )
                                                  : const Icon(Icons.image_not_supported_outlined, size: 18, color: Colors.grey),
                                            ),
                                          ),
                                          DataCell(
                                            Center(
                                              child: PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF8A96B2)),
                                                onSelected: (val) {
                                                  if (val == 'edit') openCreateFacultySheet(facultyToEdit: f);
                                                  else if (val == 'delete') _deleteFacultyWithConfirmation(f);
                                                },
                                                itemBuilder: (context) => [
                                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                                                ],
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
                        // Pagination
                        Container(
                          height: 58,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE3EAF8)))),
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
                              const smcText(textToDisplay: 'Rows per page:', textSize: 12, colorOfText: Color(0xFF7D87A3)),
                              const SizedBox(width: 8),
                              DropdownButton<int>(
                                value: facultyRowsPerPage,
                                items: const [
                                  DropdownMenuItem(value: 10, child: Text('10')),
                                  DropdownMenuItem(value: 25, child: Text('25')),
                                  DropdownMenuItem(value: 50, child: Text('50')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      facultyRowsPerPage = value;
                                      facultyCurrentPage = 1;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: safePage > 1 ? () => setState(() => facultyCurrentPage = 1) : null,
                                icon: const Icon(Icons.first_page_rounded),
                              ),
                              IconButton(
                                onPressed: safePage > 1 ? () => setState(() => facultyCurrentPage = safePage - 1) : null,
                                icon: const Icon(Icons.chevron_left_rounded),
                              ),
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: const Color(0xFFEAF0FF), borderRadius: BorderRadius.circular(8)),
                                child: smcText(textToDisplay: '$safePage', textSize: 12, textBoldness: 4, colorOfText: ColorConst.primaryBlue),
                              ),
                              IconButton(
                                onPressed: safePage < totalPages ? () => setState(() => facultyCurrentPage = safePage + 1) : null,
                                icon: const Icon(Icons.chevron_right_rounded),
                              ),
                              IconButton(
                                onPressed: safePage < totalPages ? () => setState(() => facultyCurrentPage = totalPages) : null,
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

  Future<void> _deleteFacultyWithConfirmation(FacultyModel faculty) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Faculty'),
        content: Text('Are you sure you want to delete ${faculty.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && faculty.documentId != null) {
      try {
        await facultyService.deleteFaculty(faculty.documentId!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Faculty deleted successfully')),
        );
        refresh();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting faculty: $e')),
        );
      }
    }
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
              color:
              isSelected ? ColorConst.primaryBlue : ColorConst.textSecondary,
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
