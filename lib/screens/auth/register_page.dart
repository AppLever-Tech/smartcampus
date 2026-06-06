import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pinput/pinput.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/mock_master_data.dart';
import 'package:smartcampus/screens/auth/landing_page.dart';
import 'package:smartcampus/services/faculty_firestore_service.dart';
import 'package:smartcampus/services/firebase_auth_service.dart';
import 'package:smartcampus/services/org_role_firestore_service.dart';
import 'package:smartcampus/services/student_firestore_service.dart';
import 'package:smartcampus/services/user_master_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class RegisterPage extends StatefulWidget {
  final String uuid;

  const RegisterPage({
    super.key,
    required this.uuid,
  });

  @override
  State<RegisterPage> createState() => RegisterPageState();
}

class RegisterPageState extends State<RegisterPage> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final FirebaseAuthService firebaseAuthService = FirebaseAuthService();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController deptCodeController = TextEditingController();
  final ImagePicker imagePicker = ImagePicker();
  bool isSubmitting = false;
  String? formMessage;
  XFile? selectedProfileImage;
  Uint8List? selectedProfileImageBytes;

  @override
  void initState() {
    super.initState();
    mobileController.text = widget.uuid;
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    mobileController.dispose();
    deptCodeController.dispose();
    super.dispose();
  }

  Future<void> onSubmitRegistration() async {
    if (!(formKey.currentState?.validate() ?? false) || isSubmitting) {
      return;
    }

    final mobile = mobileController.text.trim();
    final fullName =
        '${firstNameController.text.trim()} ${lastNameController.text.trim()}'
            .trim();
    final normalizedUuid = firebaseAuthService.normalizeUuidForCompare(mobile);
    final enteredAccessCode = OrgRoleFirestoreService.normalizeDeptAccessCode(
      deptCodeController.text,
    );

    setState(() {
      isSubmitting = true;
      formMessage = null;
    });
    var movedToNextScreen = false;

    try {
      final roleService = OrgRoleFirestoreService();
      final userMasterService = UserMasterFirestoreService(
        authService: firebaseAuthService,
      );

      final department =
          await roleService.findDepartmentByAccessCode(enteredAccessCode).timeout(
                const Duration(seconds: 20),
                onTimeout: () =>
                    throw TimeoutException('Department lookup timeout'),
              );
      if (department == null) {
        setState(() {
          isSubmitting = false;
          formMessage =
              'Department access code not found. Check the 4-digit code with your department admin.';
        });
        return;
      }

      final studentService = StudentFirestoreService();
      final facultyService = FacultyFirestoreService();
      final existingStudent =
          await studentService.getStudentByUuid(normalizedUuid);
      final existingFaculty =
          await facultyService.getFacultyByMobile(normalizedUuid);
      if (existingStudent != null || existingFaculty != null) {
        setState(() {
          isSubmitting = false;
          formMessage =
              'This mobile number is already registered. Please sign in.';
        });
        return;
      }

      final existingUser = await userMasterService.getByUuid(normalizedUuid);
      if (existingUser != null) {
        setState(() {
          isSubmitting = false;
          formMessage =
              'This mobile number is already registered. Please sign in.';
        });
        return;
      }

      final photographUrl = await uploadProfileImage(normalizedUuid);

      await userMasterService.upsertUser(
        uuid: normalizedUuid,
        userName: fullName,
        userRole: UserRoles.unclassified,
        status: UserStatus.pendingApproval,
        orgId: department.orgId,
        deptId: department.deptId,
      );

      await FirebaseFirestore.instance
          .collection(UserMasterFirestoreService.collection)
          .doc(normalizedUuid)
          .set(
        {
          'email': emailController.text.trim().toLowerCase(),
          if (photographUrl.isNotEmpty) 'photo_url': photographUrl,
          'requested_org_id': department.orgId,
          'requested_org_name': department.deptName,
          'requested_on': readableNow(),
        },
        SetOptions(merge: true),
      );

      final user = UserMasterItem(
        uuid: normalizedUuid,
        userName: fullName,
        userRole: UserRoles.unclassified,
        status: UserStatus.pendingApproval,
        orgId: department.orgId,
        deptId: department.deptId,
        name: fullName,
        mobile: mobile,
        email: emailController.text.trim().toLowerCase(),
        photoUrl: photographUrl,
        requestedOrgId: department.orgId,
        requestedOrgName: department.deptName,
        requestedOn: readableNow(),
      );

      if (!mounted) {
        return;
      }

      movedToNextScreen = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RegistrationPendingPage(user: user),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String raw = error.toString();
      String resolvedMessage = 'Unable to submit registration right now.';
      final String lower = raw.toLowerCase();
      if (lower.contains('permission-denied')) {
        resolvedMessage =
            'Profile creation failed: Firestore permission denied for one or more collections.';
      } else if (lower.contains('unavailable') || lower.contains('network')) {
        resolvedMessage =
            'Profile creation failed: network/Firestore unavailable. Please try again.';
      } else if (raw.isNotEmpty) {
        resolvedMessage = 'Profile creation failed: $raw';
      }
      setState(() {
        isSubmitting = false;
        formMessage = resolvedMessage;
      });
    } finally {
      if (!movedToNextScreen && mounted && isSubmitting) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  Future<void> pickProfileImage() async {
    try {
      final pickedFile = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile == null) {
        return;
      }

      final bytes = await pickedFile.readAsBytes();
      if (!mounted) {
        return;
      }

      setState(() {
        selectedProfileImage = pickedFile;
        selectedProfileImageBytes = bytes;
        formMessage = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        formMessage = 'Unable to pick profile picture right now.';
      });
    }
  }

  Future<String> uploadProfileImage(String normalizedUuid) async {
    final imageFile = selectedProfileImage;
    if (imageFile == null) {
      return '';
    }

    final bytes = selectedProfileImageBytes ?? await imageFile.readAsBytes();
    final fileExtension = imageFile.name.contains('.')
        ? imageFile.name.split('.').last.toLowerCase()
        : 'jpg';
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('profile_pics')
        .child('$normalizedUuid.$fileExtension');

    final metadata = SettableMetadata(contentType: 'image/$fileExtension');
    await storageRef.putData(bytes, metadata);
    return storageRef.getDownloadURL();
  }

  String readableNow() {
    final now = DateTime.now();
    final hour = now.hour > 12
        ? now.hour - 12
        : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}\n$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isMobileLocked = widget.uuid.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: ColorConst.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const smcText(
          textToDisplay: 'User Registration',
          textSize: 20,
          textBoldness: 4,
          colorOfText: ColorConst.textPrimary,
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final horizontalPadding = width >= 980 ? 32.0 : 16.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Form(
                    key: formKey,
                    child: buildRegistrationFormCard(
                      isMobileLocked: isMobileLocked,
                      compact: width < 700,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildRegistrationFormCard({
    required bool isMobileLocked,
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 18 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD8E0F4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120E1A33),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    smcText(
                      textToDisplay: 'Your Details',
                      textSize: 24,
                      textBoldness: 5,
                      colorOfText: ColorConst.textPrimary,
                    ),
                    SizedBox(height: 8),
                    smcText(
                      textToDisplay:
                          'Enter the 4-digit department access code shared by your department admin. Your request will appear in User Management, where the admin will classify you as Student or Faculty.',
                      textSize: 13,
                      colorOfText: ColorConst.textSecondary,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 20),
                buildProfileImagePicker(compact: false, inline: true),
              ],
            ],
          ),
          if (compact) ...[
            const SizedBox(height: 22),
            Center(child: buildProfileImagePicker(compact: true, inline: true)),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: buildField(
                  controller: firstNameController,
                  label: 'First Name',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildField(
                  controller: lastNameController,
                  label: 'Last Name',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          buildField(
            controller: emailController,
            label: 'Email Address',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          buildField(
            controller: mobileController,
            label: 'Mobile Number',
            enabled: !isMobileLocked,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          buildDepartmentCodeInput(),
          if (formMessage != null) ...[
            const SizedBox(height: 16),
            buildMessageBanner(formMessage!),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onSubmitRegistration,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: ColorConst.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                  : const smcText(
                      textToDisplay: 'Create Profile',
                      textSize: 16,
                      textBoldness: 4,
                      colorOfText: Colors.white,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProfileImagePicker({bool compact = false, bool inline = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: isSubmitting ? null : pickProfileImage,
          child: Container(
            width: compact ? 104 : (inline ? 96 : 132),
            height: compact ? 104 : (inline ? 96 : 132),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FF),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD7E0F4),
                width: 1.4,
              ),
            ),
            child: ClipOval(
              child: selectedProfileImageBytes != null
                  ? Image.memory(
                      selectedProfileImageBytes!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: const Color(0xFFF4F7FF),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_rounded,
                            color: ColorConst.primaryBlue,
                            size: inline ? 24 : 28,
                          ),
                          if (!inline) ...[
                            const SizedBox(height: 6),
                            const smcText(
                              textToDisplay: 'Add Photo',
                              textSize: 12,
                              textBoldness: 3,
                              colorOfText: ColorConst.primaryBlue,
                              maxLines: 1,
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ),
        SizedBox(height: inline ? 10 : (compact ? 12 : 14)),
        OutlinedButton.icon(
          onPressed: isSubmitting ? null : pickProfileImage,
          style: OutlinedButton.styleFrom(
            foregroundColor: ColorConst.textPrimary,
            backgroundColor: Colors.white,
            side: const BorderSide(color: ColorConst.borderSoft),
            padding: EdgeInsets.symmetric(
              horizontal: inline ? 12 : 16,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.upload_rounded, size: 18),
          label: Text(
            selectedProfileImage == null
                ? 'Upload Profile Pic'
                : 'Change Profile Pic',
          ),
        ),
        if (!inline) ...[
          const SizedBox(height: 10),
          const smcText(
            textToDisplay: 'JPG or PNG from your device',
            textSize: 12,
            colorOfText: ColorConst.textSecondary,
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ],
      ],
    );
  }

  static const int _departmentCodeLength = 4;

  PinTheme get _departmentCodePinTheme => PinTheme(
        width: 52,
        height: 52,
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: ColorConst.textPrimary,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ColorConst.primaryBlue,
            width: 1.5,
          ),
        ),
      );

  PinTheme get _departmentCodeFocusedPinTheme => PinTheme(
        width: 52,
        height: 52,
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: ColorConst.textPrimary,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ColorConst.primaryBlueDark,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: ColorConst.primaryBlue.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      );

  PinTheme get _departmentCodeSubmittedPinTheme => PinTheme(
        width: 52,
        height: 52,
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: ColorConst.textPrimary,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF0FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ColorConst.primaryBlue,
            width: 1.5,
          ),
        ),
      );

  Widget buildDepartmentCodeInput() {
    return FormField<String>(
      validator: (_) {
        final digits =
            deptCodeController.text.replaceAll(RegExp(r'\D'), '');
        if (digits.isEmpty) {
          return 'Enter department access code';
        }
        if (digits.length < _departmentCodeLength) {
          return 'Enter all $_departmentCodeLength digits';
        }
        return null;
      },
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const smcText(
              textToDisplay: 'Department Access Code',
              textSize: 14,
              textBoldness: 4,
              colorOfText: ColorConst.textSecondary,
            ),
            const SizedBox(height: 6),
            const smcText(
              textToDisplay:
                  'Enter the 4-digit code from your department admin.',
              textSize: 12,
              colorOfText: ColorConst.textSecondary,
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Pinput(
                mainAxisAlignment: MainAxisAlignment.start,
                controller: deptCodeController,
                length: _departmentCodeLength,
                enabled: !isSubmitting,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_departmentCodeLength),
                ],
                defaultPinTheme: _departmentCodePinTheme,
                focusedPinTheme: _departmentCodeFocusedPinTheme,
                submittedPinTheme: _departmentCodeSubmittedPinTheme,
                forceErrorState: field.hasError,
                errorText: field.errorText,
                onChanged: (_) => field.didChange(deptCodeController.text),
                onCompleted: (_) => field.didChange(deptCodeController.text),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildField({
    required TextEditingController controller,
    required String label,
    bool enabled = true,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isMobileField = label == 'Mobile Number';

    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: isMobileField
          ? <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ]
          : null,
      style: const TextStyle(color: ColorConst.textPrimary),
      decoration: inputDecoration(label),
      validator: (value) {
        final trimmed = (value ?? '').trim();
        if (!enabled && trimmed.isEmpty) {
          return 'Required';
        }
        if (trimmed.isEmpty) {
          return 'Required';
        }
        if (label == 'Email Address' &&
            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed)) {
          return 'Enter valid email';
        }
        if (label == 'Mobile Number' &&
            !RegExp(r'^\d{10}$').hasMatch(trimmed)) {
          return 'Enter valid 10-digit mobile number';
        }
        return null;
      },
    );
  }

  InputDecoration inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      labelStyle: const TextStyle(color: ColorConst.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ColorConst.borderSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ColorConst.borderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ColorConst.primaryBlue, width: 1.4),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ColorConst.borderSoft),
      ),
    );
  }

  Widget buildMessageBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3CCCC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFC62828),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: smcText(
              textToDisplay: message,
              textSize: 12,
              colorOfText: const Color(0xFFC62828),
              maxLines: 4,
            ),
          ),
        ],
      ),
    );
  }

}

class RegistrationPendingPage extends StatelessWidget {
  final UserMasterItem user;

  const RegistrationPendingPage({
    super.key,
    required this.user,
  });

  Future<void> onLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LandingPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool compactLayout = MediaQuery.sizeOf(context).width < 960;
    return Scaffold(
      backgroundColor: ColorConst.pageBackground,
      drawer: compactLayout
          ? Drawer(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: buildPendingSidebarContent(context),
                ),
              ),
            )
          : null,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const smcText(
          textToDisplay: 'Pending Approval',
          textSize: 20,
          textBoldness: 4,
          colorOfText: ColorConst.textPrimary,
        ),
        actions: [
          TextButton(
            onPressed: () => onLogout(context),
            child: const smcText(
              textToDisplay: 'Logout',
              textSize: 14,
              textBoldness: 4,
              colorOfText: ColorConst.primaryBlue,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: compactLayout
              ? buildPendingApprovalCard()
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildPendingSidebar(context),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: buildPendingApprovalCard(),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget buildPendingSidebar(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF7F9FF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7ECF8)),
      ),
      child: buildPendingSidebarContent(context),
    );
  }

  Widget buildPendingSidebarContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
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
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: smcText(
                textToDisplay: 'SmartCampus',
                textSize: 20,
                textBoldness: 5,
                colorOfText: Color(0xFF1F2F52),
                maxLines: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        buildSidebarItem(
          icon: Icons.hourglass_top_rounded,
          title: 'Pending Approval',
          active: true,
        ),
        const SizedBox(height: 8),
        buildSidebarItem(
          icon: Icons.support_agent_rounded,
          title: 'Support',
          active: false,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => onLogout(context),
          borderRadius: BorderRadius.circular(12),
          child: buildSidebarItem(
            icon: Icons.logout_outlined,
            title: 'Logout',
            active: false,
          ),
        ),
      ],
    );
  }

  Widget buildSidebarItem({
    required IconData icon,
    required String title,
    required bool active,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEFF4FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: active ? ColorConst.primaryBlue : const Color(0xFF7D87A3),
            size: 20,
          ),
          const SizedBox(width: 10),
          smcText(
            textToDisplay: title,
            textSize: 14,
            textBoldness: 4,
            colorOfText:
                active ? ColorConst.primaryBlue : const Color(0xFF2E3954),
          ),
        ],
      ),
    );
  }

  Widget buildPendingApprovalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ColorConst.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E7),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: Color(0xFFFF9B24),
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const smcText(
            textToDisplay: 'Pending Approval from system admin',
            textSize: 18,
            textBoldness: 4,
            colorOfText: ColorConst.textPrimary,
          ),
          const SizedBox(height: 8),
          smcText(
            textToDisplay:
                '${user.displayName}, your request for ${user.requestedOrgName} is recorded.',
            textSize: 14,
            colorOfText: ColorConst.textSecondary,
            maxLines: 3,
          ),
          const SizedBox(height: 18),
          Center(
            child: buildSafeAvatar(
              name: user.displayName,
              photoUrl: user.photoUrl,
            ),
          ),
          const SizedBox(height: 18),
          buildInfoRow('Mobile', user.mobile),
          const SizedBox(height: 10),
          buildInfoRow(
            'Role',
            user.userRole.isNotEmpty ? user.userRole : user.roleId,
          ),
          const SizedBox(height: 10),
          buildInfoRow('Department', user.requestedOrgName),
          const SizedBox(height: 10),
          buildInfoRow('Requested On', user.requestedOn),
        ],
      ),
    );
  }

  Widget buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: smcText(
            textToDisplay: label,
            textSize: 13,
            textBoldness: 3,
            colorOfText: ColorConst.textSecondary,
          ),
        ),
        Expanded(
          child: smcText(
            textToDisplay: value,
            textSize: 14,
            colorOfText: ColorConst.textPrimary,
            maxLines: 3,
          ),
        ),
      ],
    );
  }

  Widget buildSafeAvatar({required String name, required String photoUrl}) {
    final String url = normalizeImageUrl(photoUrl);
    final String letter = name.trim().isEmpty
        ? 'U'
        : name.trim().substring(0, 1).toUpperCase();

    if (url.isEmpty) {
      return CircleAvatar(
        radius: 34,
        backgroundColor: const Color(0xFFE8EEFF),
        child: smcText(
          textToDisplay: letter,
          textSize: 20,
          textBoldness: 5,
          colorOfText: ColorConst.primaryBlue,
        ),
      );
    }

    return CircleAvatar(
      radius: 34,
      backgroundColor: const Color(0xFFE8EEFF),
      child: ClipOval(
        child: Image.network(
          url,
          width: 68,
          height: 68,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            return smcText(
              textToDisplay: letter,
              textSize: 20,
              textBoldness: 5,
              colorOfText: ColorConst.primaryBlue,
            );
          },
        ),
      ),
    );
  }

  String normalizeImageUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty || value.startsWith('gs://')) {
      return '';
    }
    if (value.startsWith('//')) {
      value = 'https:$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      return '';
    }
    return uri.toString();
  }
}
