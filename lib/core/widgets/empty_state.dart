import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final IconData? icon;
  final String? assetPath;

  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.buttonText,
    this.onButtonPressed,
    this.icon,
    this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (assetPath != null)
              SvgPicture.asset(
                assetPath!,
                height: 120,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.3) ?? Colors.grey,
                  BlendMode.srcIn,
                ),
              )
            else if (icon != null)
              Icon(
                icon,
                size: 80,
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.3),
              )
            else
              Icon(
                Icons.inbox_outlined,
                size: 80,
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.3),
              ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onButtonPressed,
                icon: const Icon(Icons.add, size: 20),
                label: Text(buttonText!),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
