import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/widgets/profile_photo_avatar.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class FacultyDashboardMobileLayout extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onLogout;
  final FacultyModel faculty;
  final String displayName;
  final Widget dashboardContent;
  final Widget classesContent;
  final Widget profileContent;
  final Widget proctoringContent;

  const FacultyDashboardMobileLayout({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.onLogout,
    required this.faculty,
    required this.displayName,
    required this.dashboardContent,
    required this.classesContent,
    required this.profileContent,
    required this.proctoringContent,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            _buildProfileAvatar(radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  smcText(
                    textToDisplay:
                        'Welcome, ${faculty.fullName.isNotEmpty ? faculty.fullName : displayName}',
                    textSize: 15,
                    textBoldness: 5,
                    colorOfText: ColorConst.textPrimary,
                    maxLines: 1,
                  ),
                  const smcText(
                    textToDisplay: 'Faculty Portal',
                    textSize: 12,
                    colorOfText: ColorConst.textSecondary,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: onLogout,
            tooltip: 'Logout',
            icon: const Icon(
              Icons.logout_rounded,
              color: ColorConst.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFE3EAF8),
          ),
        ),
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox.expand(child: dashboardContent),
          ),
          SizedBox.expand(child: profileContent),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox.expand(child: classesContent),
          ),
          SizedBox.expand(child: proctoringContent),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE3EAF8)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: selectedIndex,
            onTap: onIndexChanged,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            selectedItemColor: ColorConst.primaryBlue,
            unselectedItemColor: ColorConst.textSecondary,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard_rounded),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.class_outlined),
                activeIcon: Icon(Icons.class_rounded),
                label: 'Classes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.supervisor_account_outlined),
                activeIcon: Icon(Icons.supervisor_account_rounded),
                label: 'Proctoring',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar({required double radius}) {
    final String name =
        faculty.fullName.isNotEmpty ? faculty.fullName : displayName;
    final String initial = name.trim().isEmpty
        ? 'F'
        : name.trim().substring(0, 1).toUpperCase();
    final String photoUrl =
        normalizeProfilePhotoUrl(faculty.photographUrl);

    return ProfilePhotoAvatar(
      photoUrl: photoUrl,
      fallbackInitial: initial,
      radius: radius,
    );
  }
}
