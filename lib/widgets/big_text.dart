import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class BigText extends StatelessWidget {
  final Color color;
  final String text;
  final double fontSize;
  final FontWeight fontWeight;

  const BigText({super.key, this.color = const Color(0xFF000000), required this.text,  this.fontSize = 30, this.fontWeight = FontWeight.w800,});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.openSans(
      fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      )
    );
  }
}
