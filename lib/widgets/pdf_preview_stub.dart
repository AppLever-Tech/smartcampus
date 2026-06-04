import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/widgets/smc_text.dart';

Widget buildPdfPreview(String url, {double height = 480}) {
  return Container(
    height: height,
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FF),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ColorConst.borderSoft),
    ),
    child: const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf_outlined,
            size: 48,
            color: ColorConst.primaryBlue,
          ),
          SizedBox(height: 12),
          smcText(
            textToDisplay: 'PDF preview is available on web.',
            textSize: 13,
            colorOfText: ColorConst.textSecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
