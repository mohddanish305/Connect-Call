import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_radius.dart';
import '../core/constants/app_text_styles.dart';

enum ButtonVariant { primary, secondary, danger, ghost }

class CommonButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonVariant variant;
  final IconData? icon;
  final double height;
  final double? width;

  const CommonButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.height = 50,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    BorderSide borderSide = BorderSide.none;

    switch (variant) {
      case ButtonVariant.primary:
        backgroundColor = AppColors.primaryBlue;
        textColor = AppColors.white;
        break;
      case ButtonVariant.secondary:
        backgroundColor = AppColors.primarySoft;
        textColor = AppColors.primaryBlue;
        break;
      case ButtonVariant.danger:
        backgroundColor = AppColors.error;
        textColor = AppColors.white;
        break;
      case ButtonVariant.ghost:
        backgroundColor = Colors.transparent;
        textColor = AppColors.primaryBlue;
        borderSide = const BorderSide(color: AppColors.border);
        break;
    }

    return SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.6),
          disabledForegroundColor: textColor.withValues(alpha: 0.6),
          elevation: variant == ButtonVariant.primary ? 2 : 0,
          shadowColor: variant == ButtonVariant.primary
              ? AppColors.primaryBlue.withValues(alpha: 0.3)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.roundedLg,
            side: borderSide,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: textColor),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: AppTextStyles.button(color: textColor),
                  ),
                ],
              ),
      ),
    );
  }
}
