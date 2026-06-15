import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class AppInfoDialog {
  AppInfoDialog._();

  static const String appName = 'SmartCampus';
  static const String appIconAsset = 'assets/icons/app_icon.png';

  static Future<void> show(BuildContext context) async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!context.mounted) {
      return;
    }

    final versionLabel = packageInfo.buildNumber.trim().isNotEmpty
        ? 'Version ${packageInfo.version} (${packageInfo.buildNumber})'
        : 'Version ${packageInfo.version}';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                appIconAsset,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            const smcText(
              textToDisplay: appName,
              textSize: 20,
              textBoldness: 5,
              colorOfText: ColorConst.textPrimary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            smcText(
              textToDisplay: versionLabel,
              textSize: 14,
              colorOfText: ColorConst.textSecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const smcText(
              textToDisplay: 'Close',
              textSize: 14,
              textBoldness: 4,
              colorOfText: ColorConst.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }
}
