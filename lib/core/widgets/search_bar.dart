import 'package:flutter/material.dart';

class AppSearchBar extends StatelessWidget {
  final String? hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterPressed;
  final TextEditingController? controller;
  final bool showFilter;

  const AppSearchBar({
    super.key,
    this.hint,
    this.onChanged,
    this.onFilterPressed,
    this.controller,
    this.showFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint ?? 'Search...',
                prefixIcon: const Icon(Icons.search, size: 22),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
              ),
            ),
          ),
          if (showFilter) ...[
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: onFilterPressed,
                icon: const Icon(Icons.tune, size: 22),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
