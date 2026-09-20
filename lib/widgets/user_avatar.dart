import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';

class UserAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;
  final bool? isOnline;
  final bool showBadge;

  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 24,
    this.isOnline,
    this.showBadge = false,
  });

  String _getInitials(String fullName) {
    try {
      final cleaned = fullName.trim();
      if (cleaned.isEmpty) return 'U';
      final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      if (parts.isEmpty) return 'U';
      if (parts.length == 1) {
        return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'U';
      }
      final first = parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '';
      final second = parts[1].isNotEmpty ? parts[1][0].toUpperCase() : '';
      final combined = '$first$second';
      return combined.isNotEmpty ? combined : 'U';
    } catch (_) {
      return 'U';
    }
  }

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    final initials = _getInitials(name);

    Widget avatarContent;

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      avatarContent = ClipOval(
        child: Image.network(
          photoUrl!,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitialsFallback(diameter, initials),
        ),
      );
    } else {
      avatarContent = _buildInitialsFallback(diameter, initials);
    }

    if (!showBadge || isOnline == null) {
      return avatarContent;
    }

    final badgeSize = (radius * 0.55).clamp(10.0, 18.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatarContent,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              color: isOnline! ? AppColors.success : AppColors.mutedText,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialsFallback(double size, String initials) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primaryBlueDark, AppColors.primaryBlueLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.title(color: AppColors.white).copyWith(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
