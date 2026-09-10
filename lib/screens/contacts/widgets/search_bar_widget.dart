import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_text_styles.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hintText;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.hintText = 'Search people...',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkElevatedSurface : AppColors.surfaceSecondary,
        borderRadius: AppRadius.roundedLg,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.body(
          color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTextStyles.body(
            color: isDark ? AppColors.darkMutedText : AppColors.mutedText,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
            size: 22,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
