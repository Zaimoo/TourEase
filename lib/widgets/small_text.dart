import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class SmallText extends StatelessWidget {
  final Color color;
  final String text;
  final double fontSize;
  final FontWeight fontWeight;

  const SmallText({super.key, this.color = const Color(0xFF000000), required this.text,  this.fontSize = 12, this.fontWeight = FontWeight.normal,});

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
