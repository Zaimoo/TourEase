import 'package:flutter/material.dart';

class BadgeButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final String text;

  const BadgeButton({
    super.key,
    this.onPressed,
    this.backgroundColor = const Color(0xFF64B5F6),
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(0, 0), // allows button to shrink to text size
        tapTargetSize: MaterialTapTargetSize.shrinkWrap, // removes extra padding
      ),
      onPressed: onPressed,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12, // smaller text
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
