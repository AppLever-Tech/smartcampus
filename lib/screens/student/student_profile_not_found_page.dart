import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/screens/auth/landing_page.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class StudentProfileNotFoundPage extends StatelessWidget {
  final VoidCallback? onLogout;

  const StudentProfileNotFoundPage({super.key, this.onLogout});

  Future<void> _signOut(BuildContext context) async {
    if (onLogout != null) {
      onLogout!();
      return;
    }
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.person_off_outlined,
                      size: 36,
                      color: Color(0xFFC62828),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const smcText(
                    textToDisplay: 'Student profile not found',
                    textSize: 20,
                    textBoldness: 5,
                    colorOfText: ColorConst.textPrimary,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  const smcText(
                    textToDisplay:
                        'No matching record was found in Smart Campus for your account. '
                        'Please contact your department admin to add your student profile with the correct mobile number.',
                    textSize: 14,
                    colorOfText: ColorConst.textSecondary,
                    textAlign: TextAlign.center,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _signOut(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorConst.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const smcText(
                        textToDisplay: 'Sign out',
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
        ),
      ),
    );
  }
}
