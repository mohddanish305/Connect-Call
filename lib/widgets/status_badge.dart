import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_radius.dart';
import '../core/constants/app_text_styles.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  factory StatusBadge.online() {
    return const StatusBadge(
      label: 'Online',
      color: AppColors.success,
    );
  }

  factory StatusBadge.offline() {
    return const StatusBadge(
      label: 'Offline',
      color: AppColors.mutedText,
    );
  }

  factory StatusBadge.missed() {
    return const StatusBadge(
      label: 'Missed',
      color: AppColors.error,
      icon: Icons.call_missed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.roundedFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.caption(color: color).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
