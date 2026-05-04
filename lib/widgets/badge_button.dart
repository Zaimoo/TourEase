import 'package:flutter/material.dart';

class BadgeButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final String text;
  final IconData? icon;

  const BadgeButton({
    super.key,
    this.onPressed,
    this.backgroundColor = const Color(0xFF64B5F6),
    required this.text,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 3,
        shadowColor: backgroundColor?.withOpacity(0.4),
        minimumSize: const Size(0, 40),
      ),
      onPressed: onPressed,
      icon: icon != null
          ? Icon(icon, size: 18, color: Colors.white)
          : const SizedBox.shrink(),
      label: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
