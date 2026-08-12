import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isExpanded;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? height;
  final bool outlined;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isExpanded = true,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.height,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = outlined
        ? OutlinedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, size: 20),
            label: Text(text),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(0, height ?? 52),
            ),
          )
        : ElevatedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, size: 20, color: textColor),
            label: Text(text),
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: textColor,
              minimumSize: Size(0, height ?? 52),
            ),
          );

    if (isExpanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(text),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
        ),
      ),
    );
  }
}

class IconActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;

  const IconActionButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color?.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: size * 0.5, color: color),
        ),
      ),
    );
  }
}
