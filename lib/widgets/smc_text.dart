import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class smcText extends StatelessWidget {
  final String textToDisplay;
  final double textSize;
  final int textBoldness;
  final Color colorOfText;
  final TextAlign textAlign;
  final int maxLines;
  final TextOverflow overflow;

  const smcText({
    super.key,
    required this.textToDisplay,
    required this.textSize,
    this.textBoldness = 1,
    this.colorOfText = Colors.black,
    this.textAlign = TextAlign.left,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
  });

  FontWeight get fontWeight {
    switch (textBoldness) {
      case 2:
        return FontWeight.w500;
      case 3:
        return FontWeight.w600;
      case 4:
        return FontWeight.w700;
      case 5:
        return FontWeight.w800;
      default:
        return FontWeight.w400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      textToDisplay,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      style: GoogleFonts.poppins(
        fontSize: textSize,
        fontWeight: fontWeight,
        color: colorOfText,
      ),
    );
  }
}
