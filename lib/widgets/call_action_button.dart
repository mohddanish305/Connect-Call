import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';

enum CallButtonType { normal, active, endCall, acceptCall }

class CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final CallButtonType type;
  final double size;

  const CallActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.type = CallButtonType.normal,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color iconColor;

    switch (type) {
      case CallButtonType.normal:
        bgColor = AppColors.darkElevatedSurface.withValues(alpha: 0.85);
        iconColor = AppColors.white;
        break;
      case CallButtonType.active:
        bgColor = AppColors.white;
        iconColor = AppColors.primaryBlue;
        break;
      case CallButtonType.endCall:
        bgColor = AppColors.error;
        iconColor = AppColors.white;
        break;
      case CallButtonType.acceptCall:
        bgColor = AppColors.success;
        iconColor = AppColors.white;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Ink(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
                boxShadow: [
                  BoxShadow(
                    color: type == CallButtonType.endCall
                        ? AppColors.error.withValues(alpha: 0.4)
                        : (type == CallButtonType.acceptCall
                            ? AppColors.success.withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.2)),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: iconColor,
                  size: size * 0.46,
                ),
              ),
            ),
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.caption(color: AppColors.darkSecondaryText),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
