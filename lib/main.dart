import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/screens/landing_page.dart';
import 'package:smartcampus/screens/screen_brancher.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(

      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {

    debugPrint("Exception occurred: $e");
  }
  runApp(const SmartCampusApp());
}

class SmartCampusApp extends StatelessWidget {
  const SmartCampusApp({super.key});

  String? _resolveUuidFromUser(User user) {
    final phoneNumber = user.phoneNumber?.trim();
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return null;
    }
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartCampus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: ColorConst.pageBackground,
        colorScheme: ColorScheme.fromSeed(seedColor: ColorConst.primaryBlue),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }

          final user = snapshot.data;
          if (user != null) {
            final uuid = _resolveUuidFromUser(user);
            if (uuid != null && uuid.isNotEmpty) {
              return ScreenBrancher(uuid: uuid);
            }
          }
          return const LandingPage();
        },
      ),
    );
  }
}
