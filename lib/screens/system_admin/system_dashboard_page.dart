import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/mock_master_data.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class SystemDashboardPage extends StatelessWidget {
  final String userName;
  final List<OrganizationItem> organizations;

  const SystemDashboardPage({
    super.key,
    required this.userName,
    required this.organizations,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConst.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const smcText(
          textToDisplay: 'System Dashboard',
          textSize: 22,
          textBoldness: 4,
          colorOfText: ColorConst.textPrimary,
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: smcText(
                textToDisplay: userName,
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
            const smcText(
              textToDisplay: 'All Organizations',
              textSize: 18,
              textBoldness: 3,
              colorOfText: ColorConst.textPrimary,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: organizations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final org = organizations[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ColorConst.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ColorConst.borderSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        smcText(
                          textToDisplay: org.orgName,
                          textSize: 16,
                          textBoldness: 4,
                          colorOfText: ColorConst.textPrimary,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 4),
                        smcText(
                          textToDisplay: 'Org ID: ${org.orgId}  |  ${org.orgType}',
                          textSize: 13,
                          colorOfText: ColorConst.textSecondary,
                        ),
                        const SizedBox(height: 4),
                        smcText(
                          textToDisplay: 'Admin: ${org.adminName} (${org.adminUuid})',
                          textSize: 13,
                          colorOfText: ColorConst.textSecondary,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
