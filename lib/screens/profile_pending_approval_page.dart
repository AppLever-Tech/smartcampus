import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/mock_master_data.dart';
import 'package:smartcampus/screens/landing_page.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class ProfilePendingApprovalPage extends StatelessWidget {
  final String displayName;
  final UserMasterItem? user;

  const ProfilePendingApprovalPage({
    super.key,
    required this.displayName,
    this.user,
  });

  @override
  Widget build(BuildContext context) {
    final shownUser = user;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FF),
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 230,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Color(0xFFE4EAF7))),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.school_outlined,
                          color: ColorConst.primaryBlue,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        smcText(
                          textToDisplay: 'SmartCampus',
                          textSize: 20,
                          textBoldness: 5,
                          colorOfText: ColorConst.textPrimary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _menuTile(
                      title: 'Pending Approval',
                      icon: Icons.hourglass_top_rounded,
                      isSelected: true,
                      onTap: () {},
                    ),
                    const SizedBox(height: 8),
                    _menuTile(
                      title: 'Support',
                      icon: Icons.support_agent_rounded,
                      isSelected: false,
                      onTap: () => onSupport(context),
                    ),
                    const Spacer(),
                    _menuTile(
                      title: 'Logout',
                      icon: Icons.logout_rounded,
                      isSelected: false,
                      onTap: () => onLogout(context),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 860),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE4EAF7)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF4E7),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.hourglass_top_rounded,
                                  color: Color(0xFFFF9B24),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const smcText(
                                      textToDisplay:
                                          'Pending Approval from system admin',
                                      textSize: 18,
                                      textBoldness: 5,
                                      colorOfText: ColorConst.textPrimary,
                                    ),
                                    const SizedBox(height: 6),
                                    smcText(
                                      textToDisplay:
                                          '$displayName, your request is recorded and is under review.',
                                      textSize: 14,
                                      colorOfText: ColorConst.textSecondary,
                                      maxLines: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE9EDF5)),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              buildInfoRow(
                                icon: Icons.phone_iphone_rounded,
                                label: 'Mobile',
                                value: shownUser?.mobile ?? '-',
                              ),
                              buildInfoRow(
                                icon: Icons.person_outline_rounded,
                                label: 'Role',
                                value: shownUser?.roleId.isNotEmpty == true
                                    ? shownUser!.roleId
                                    : '-',
                              ),
                              buildInfoRow(
                                icon: Icons.badge_outlined,
                                label: 'Org ID',
                                value: shownUser?.requestedOrgId ?? '-',
                              ),
                              buildInfoRow(
                                icon: Icons.calendar_today_outlined,
                                label: 'Requested On',
                                value: shownUser?.requestedOn ?? '-',
                                showDivider: false,
                              ),
                              const SizedBox(height: 18),
                              const smcText(
                                textToDisplay:
                                    'You will be notified once approval is completed.',
                                textSize: 12,
                                colorOfText: ColorConst.textSecondary,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  void onSupport(BuildContext context) {
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
              'Your request is already submitted. Please wait for system admin approval.',
          textSize: 14,
          colorOfText: ColorConst.textSecondary,
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const smcText(
              textToDisplay: 'Close',
              textSize: 14,
              colorOfText: ColorConst.primaryBlue,
            ),
          ),
        ],
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

  Widget buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool showDivider = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFE9EDF5)))
            : null,
      ),
      child: Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6D7CA3)),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: smcText(
            textToDisplay: label,
            textSize: 13,
            textBoldness: 4,
            colorOfText: ColorConst.textSecondary,
          ),
        ),
        const smcText(
          textToDisplay: ':',
          textSize: 13,
          colorOfText: ColorConst.textSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: smcText(
            textToDisplay: value,
            textSize: 13,
            colorOfText: ColorConst.textPrimary,
            maxLines: 2,
          ),
        ),
      ],
    ));
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
