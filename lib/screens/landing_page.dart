import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/screens/register_page.dart';
import 'package:smartcampus/screens/screen_brancher.dart';
import 'package:smartcampus/services/firebase_auth_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => LandingPageState();
}

class LandingPageState extends State<LandingPage> {
  final TextEditingController uuidController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final FirebaseAuthService firebaseAuthService = FirebaseAuthService();
  String? errorText;
  String? otpErrorText;
  bool isLoading = false;
  bool showWelcomeBackUi = false;
  bool showOtpInput = false;
  String? pendingUuidForOtp;

  @override
  void dispose() {
    uuidController.dispose();
    otpController.dispose();
    super.dispose();
  }

  void onGetOtp() {
    final String uuid = uuidController.text.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(uuid)) {
      setState(() {
        errorText = 'Enter valid 10-digit mobile number';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorText = null;
      otpErrorText = null;
    });

    firebaseAuthService.getRoleByUuid(uuid).then((roleMasterUser) {
      if (!mounted) {
        return;
      }
      if (roleMasterUser == null) {
        final String rawError = firebaseAuthService.lastLookupError ?? '';
        String resolvedErrorMessage =
            'User not found ';
        if (rawError.isNotEmpty) {
          final lower = rawError.toLowerCase();
          if (lower.contains('permission-denied')) {
            resolvedErrorMessage =
                'Firebase connected, but Firestore permission denied. Update Firestore rules.';
          } else if (lower.contains('unavailable') ||
              lower.contains('network')) {
            resolvedErrorMessage =
                'Firebase connected, but network/Firestore unavailable. Check internet.';
          } else {
            resolvedErrorMessage = 'Firestore error: $rawError';
          }
        }
        setState(() {
          isLoading = false;
          errorText = resolvedErrorMessage;
          showOtpInput = false;
        });
        return;
      }
      firebaseAuthService.sendOtp(
        mobileOrUuid: uuid,
        onCodeSent: () {
          if (!mounted) {
            return;
          }
          setState(() {
            isLoading = false;
            errorText = null;
            otpErrorText = null;
            showOtpInput = true;
            pendingUuidForOtp = roleMasterUser.uuid;
            otpController.clear();
          });
        },
        onError: (message) {
          if (!mounted) {
            return;
          }
          setState(() {
            isLoading = false;
            errorText = message;
            showOtpInput = false;
          });
        },
      );
    });
  }

  void onVerifyOtp() {
    if (pendingUuidForOtp == null) {
      setState(() {
        otpErrorText = 'Please request OTP first';
      });
      return;
    }

    final String enteredOtp = otpController.text.trim();
    if (enteredOtp.length != 6) {
      setState(() {
        otpErrorText = 'Please enter 6 digit OTP';
      });
      return;
    }

    setState(() {
      errorText = null;
      otpErrorText = null;
      isLoading = true;
    });

    firebaseAuthService
        .verifyOtp(
          otpCode: enteredOtp,
          onError: (message) {
            if (!mounted) {
              return;
            }
            setState(() {
              isLoading = false;
              otpErrorText = message;
            });
          },
        )
        .then((isVerified) {
          if (!mounted || !isVerified) {
            return;
          }
          setState(() {
            isLoading = false;
          });
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ScreenBrancher(uuid: pendingUuidForOtp!),
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool isWebLayout = width >= 1024;

    return Scaffold(
      backgroundColor: ColorConst.pageBackground,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF3F5FF), ColorConst.pageBackground],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FF),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: ColorConst.borderSoft),
                  ),
                  child: isWebLayout ? buildWebSection() : buildMobileSection(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildWebSection() {
    if (showWelcomeBackUi) {
      return Center(child: SizedBox(width: 430, child: buildRightLoginCard()));
    }

    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(alignment: Alignment.center, child: buildBrandChip()),
                const SizedBox(height: 22),
                const smcText(
                  textToDisplay: 'Build campus intelligent with AI !',
                  textSize: 18,
                  textBoldness: 4,
                  colorOfText: ColorConst.textPrimary,
                  maxLines: 1,
                ),
                const SizedBox(height: 10),
                const smcText(
                  textToDisplay:
                      'Smart Campus brings students, faculty and departments together on one intelligent platform.',
                  textSize: 15,
                  colorOfText: ColorConst.textSecondary,
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                const Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FeatureTile(
                            icon: Icons.groups_rounded,
                            iconBgColor: Color(0xFFE8EDFF),
                            iconColor: ColorConst.primaryBlue,
                            title: 'Students',
                            subtitle: 'Your campus,\nyour way.',
                          ),
                        ),
                        SizedBox(width: 18),
                        Expanded(
                          child: FeatureTile(
                            icon: Icons.edit_note_rounded,
                            iconBgColor: Color(0xFFE3F7EE),
                            iconColor: Color(0xFF16A46B),
                            title: 'Faculty',
                            subtitle: 'Teach, manage\nand inspire.',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FeatureTile(
                            icon: Icons.menu_book_rounded,
                            iconBgColor: Color(0xFFF0E8FF),
                            iconColor: Color(0xFF8B53F6),
                            title: 'Subjects',
                            subtitle: 'Access notes,\nassignments and more.',
                          ),
                        ),
                        SizedBox(width: 18),
                        Expanded(
                          child: FeatureTile(
                            icon: Icons.work_outline_rounded,
                            iconBgColor: Color(0xFFFFEAEB),
                            iconColor: Color(0xFFF05A64),
                            title: 'Departments',
                            subtitle:
                                'Streamline operations\nand collaboration.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Container(
                  height: 210,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF3FF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Image.asset(
                          'assets/images/org.png',
                          width: double.infinity,
                          height: 210,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                buildIconOverlayAuthActions(),
              ],
            ),
          ),
        ),
        if (showWelcomeBackUi) ...[
          const SizedBox(width: 24),
          SizedBox(width: 430, child: buildRightLoginCard()),
        ],
      ],
    );
  }

  Widget buildIconOverlayAuthActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      showWelcomeBackUi = true;
                      showOtpInput = false;
                      otpController.clear();
                      otpErrorText = null;
                      errorText = null;
                      pendingUuidForOtp = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 1.5,
                    backgroundColor: ColorConst.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const smcText(
                    textToDisplay: 'Sign In',
                    textSize: 15,
                    textBoldness: 3,
                    colorOfText: Colors.white,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RegisterPage(uuid: uuidController.text.trim()),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ColorConst.primaryBlue,
                    side: const BorderSide(
                      color: ColorConst.primaryBlue,
                      width: 1.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const smcText(
                    textToDisplay: 'Sign Up',
                    textSize: 15,
                    textBoldness: 3,
                    colorOfText: ColorConst.primaryBlue,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Smart Campus helps manage students, faculty and departments.',
                  ),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: ColorConst.textPrimary,
              side: const BorderSide(color: ColorConst.borderSoft, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const smcText(
              textToDisplay: 'Know More',
              textSize: 14,
              textBoldness: 3,
              colorOfText: ColorConst.textPrimary,
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildMobileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!showWelcomeBackUi) ...[
          buildBrandChip(),
          const SizedBox(height: 16),
          const smcText(
            textToDisplay: 'Build campus intelligent with AI !',
            textSize: 18,
            textBoldness: 4,
            colorOfText: ColorConst.textPrimary,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const smcText(
            textToDisplay:
                'Smart Campus brings students, faculty and departments together on one intelligent platform.',
            textSize: 14,
            colorOfText: ColorConst.textSecondary,
            maxLines: 3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          const FeatureTile(
            icon: Icons.groups_rounded,
            iconBgColor: Color(0xFFE8EDFF),
            iconColor: ColorConst.primaryBlue,
            title: 'Students',
            subtitle: 'Your campus, your way.',
          ),
          const SizedBox(height: 12),
          const FeatureTile(
            icon: Icons.edit_note_rounded,
            iconBgColor: Color(0xFFE3F7EE),
            iconColor: Color(0xFF16A46B),
            title: 'Faculty',
            subtitle: 'Teach, manage and inspire.',
          ),
          const SizedBox(height: 12),
          const FeatureTile(
            icon: Icons.menu_book_rounded,
            iconBgColor: Color(0xFFF0E8FF),
            iconColor: Color(0xFF8B53F6),
            title: 'Subjects',
            subtitle: 'Access notes, assignments and more.',
          ),
          const SizedBox(height: 12),
          const FeatureTile(
            icon: Icons.work_outline_rounded,
            iconBgColor: Color(0xFFFFEAEB),
            iconColor: Color(0xFFF05A64),
            title: 'Departments',
            subtitle: 'Streamline operations and collaboration.',
          ),
          const SizedBox(height: 18),
          Container(
            height: 170,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3FF),
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/org.png',
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          buildIconOverlayAuthActions(),
        ] else ...[
          buildRightLoginCard(),
        ],
      ],
    );
  }

  Widget buildBrandChip() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 138,
          height: 138,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFEAF0FF),
          ),
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: ClipOval(
              child: Image.asset(
                'assets/icons/app_icon.png',
                width: 112,
                height: 112,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const smcText(
          textToDisplay: 'Smart Campus',
          textSize: 23,
          textBoldness: 4,
          colorOfText: ColorConst.textPrimary,
          maxLines: 1,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget buildRightLoginCard() {
    if (!showWelcomeBackUi) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: ColorConst.borderSoft),
          boxShadow: const [
            BoxShadow(
              color: Color(0x17000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 102,
              height: 102,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColorConst.primaryBlue.withValues(alpha: 0.1),
              ),
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/icons/app_icon.png',
                  width: 66,
                  height: 66,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const smcText(
              textToDisplay: 'Smart Campus',
              textSize: 30 / 2,
              textBoldness: 4,
              colorOfText: ColorConst.textPrimary,
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
            const SizedBox(height: 6),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ColorConst.borderSoft),
        boxShadow: const [
          BoxShadow(
            color: Color(0x17000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () {
                setState(() {
                  showWelcomeBackUi = false;
                  showOtpInput = false;
                  otpController.clear();
                  otpErrorText = null;
                  pendingUuidForOtp = null;
                });
              },
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: ColorConst.textPrimary,
              ),
              tooltip: 'Back',
            ),
          ),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ColorConst.primaryBlue.withValues(alpha: 0.1),
            ),
            alignment: Alignment.center,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icons/app_icon.png',
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.school_rounded,
                  color: ColorConst.primaryBlue,
                  size: 44,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const smcText(
            textToDisplay: 'Welcome Back!',
            textSize: 34 / 2,
            textBoldness: 4,
            colorOfText: ColorConst.textPrimary,
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
          const SizedBox(height: 6),
          const smcText(
            textToDisplay: 'Enter your mobile number to get OTP',
            textSize: 14,
            colorOfText: ColorConst.textSecondary,
            textAlign: TextAlign.center,
            maxLines: 1,
          ),

          if (!showOtpInput) ...[
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ColorConst.borderSoft),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.phone_android_rounded,
                    size: 20,
                    color: ColorConst.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  const smcText(
                    textToDisplay: '+91',
                    textSize: 15,
                    textBoldness: 2,
                    colorOfText: ColorConst.textPrimary,
                    maxLines: 1,
                  ),
                  const SizedBox(width: 12),
                  Container(width: 1, height: 26, color: ColorConst.borderSoft),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: uuidController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        hintText: 'Enter Mobile Number',
                        hintStyle: const TextStyle(
                          color: ColorConst.textSecondary,
                        ),
                        border: InputBorder.none,
                        errorText: errorText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (showOtpInput) ...[
            const SizedBox(height: 14),
            Pinput(
              controller: otpController,
              length: 6,
              onCompleted: (value) {
                if (!isLoading) {
                  onVerifyOtp();
                }
              },
              defaultPinTheme: PinTheme(
                width: 46,
                height: 52,
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: ColorConst.textPrimary,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ColorConst.borderSoft),
                ),
              ),
              focusedPinTheme: PinTheme(
                width: 46,
                height: 52,
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: ColorConst.textPrimary,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ColorConst.primaryBlue, width: 1.4),
                ),
              ),
            ),
            if (otpErrorText != null) ...[
              const SizedBox(height: 6),
              smcText(
                textToDisplay: otpErrorText!,
                textSize: 12,
                colorOfText: const Color(0xFFC62828),
                maxLines: 2,
              ),
            ],
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isLoading
                  ? null
                  : (showOtpInput ? onVerifyOtp : onGetOtp),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: ColorConst.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                  : smcText(
                      textToDisplay: showOtpInput ? 'Verify OTP' : 'Get OTP',
                      textSize: 16,
                      textBoldness: 3,
                      colorOfText: Colors.white,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: ColorConst.textSecondary,
              ),
              SizedBox(width: 6),
              smcText(
                textToDisplay: 'Secure',
                textSize: 12,
                colorOfText: ColorConst.textSecondary,
                maxLines: 1,
              ),
              SizedBox(width: 12),
              smcText(
                textToDisplay: '•',
                textSize: 12,
                colorOfText: ColorConst.textSecondary,
                maxLines: 1,
              ),
              SizedBox(width: 12),
              smcText(
                textToDisplay: 'Fast',
                textSize: 12,
                colorOfText: ColorConst.textSecondary,
                maxLines: 1,
              ),
              SizedBox(width: 12),
              smcText(
                textToDisplay: '•',
                textSize: 12,
                colorOfText: ColorConst.textSecondary,
                maxLines: 1,
              ),
              SizedBox(width: 12),
              smcText(
                textToDisplay: 'Easy',
                textSize: 12,
                colorOfText: ColorConst.textSecondary,
                maxLines: 1,
              ),
            ],
          ),
          const SizedBox(height: 14),

          /*Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6EBFA)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 20,
                  color: ColorConst.primaryBlue,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      smcText(
                        textToDisplay: 'Your data is safe with us.',
                        textSize: 12,
                        textBoldness: 3,
                        colorOfText: ColorConst.textPrimary,
                        maxLines: 1,
                      ),
                      SizedBox(height: 2),
                      smcText(
                        textToDisplay:
                            'We use secure encryption to protect your information.',
                        textSize: 11,
                        colorOfText: ColorConst.textSecondary,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),*/
        ],
      ),
    );
  }
}

class FeatureTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;

  const FeatureTile({
    super.key,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              smcText(
                textToDisplay: title,
                textSize: 21 / 2,
                textBoldness: 4,
                colorOfText: ColorConst.textPrimary,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              smcText(
                textToDisplay: subtitle,
                textSize: 14,
                colorOfText: ColorConst.textSecondary,
                maxLines: 3,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
