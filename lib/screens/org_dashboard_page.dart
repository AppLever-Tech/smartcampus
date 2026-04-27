import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class OrgDashboardPage extends StatelessWidget {
  final String orgId;
  final String adminName;

  const OrgDashboardPage({
    super.key,
    required this.orgId,
    required this.adminName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConst.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const smcText(
          textToDisplay: 'Organization Dashboard',
          textSize: 22,
          textBoldness: 4,
          colorOfText: ColorConst.textPrimary,
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: smcText(
                textToDisplay: adminName,
                textSize: 14,
                textBoldness: 2,
                colorOfText: ColorConst.textSecondary,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            smcText(
              textToDisplay: 'Org ID: $orgId',
              textSize: 14,
              colorOfText: ColorConst.textSecondary,
            ),
            const SizedBox(height: 14),
            const StatCard(
              title: 'Departments',
              value: '12',
              icon: Icons.account_tree_outlined,
            ),
            const SizedBox(height: 10),
            const StatCard(
              title: 'Faculties',
              value: '148',
              icon: Icons.groups_outlined,
            ),
            const SizedBox(height: 10),
            const StatCard(
              title: 'Students',
              value: '2860',
              icon: Icons.school_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorConst.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorConst.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ColorConst.primaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: ColorConst.primaryBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: smcText(
              textToDisplay: title,
              textSize: 16,
              textBoldness: 3,
              colorOfText: ColorConst.textPrimary,
            ),
          ),
          smcText(
            textToDisplay: value,
            textSize: 18,
            textBoldness: 4,
            colorOfText: ColorConst.primaryBlue,
          ),
        ],
      ),
    );
  }
}
