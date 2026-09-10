import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../widgets/user_avatar.dart';

class OnboardingIllustration1 extends StatelessWidget {
  const OnboardingIllustration1({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SizedBox(
        width: 320,
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer subtle circular aura
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? AppColors.darkElevatedSurface : AppColors.primarySoft)
                    .withValues(alpha: 0.45),
                border: Border.all(
                  color: (isDark ? AppColors.primaryBlueLight : AppColors.primaryBlue)
                      .withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
            ),

            // Middle ring
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.cyan.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
            ),

            // Center ConnectCall Hub
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.phone_in_talk_rounded,
                  color: AppColors.white,
                  size: 38,
                ),
              ),
            ),

            // Floating Contact 1 (Top Right - Sarah)
            Positioned(
              top: 18,
              right: 28,
              child: _buildAvatarNode(
                name: 'Sarah',
                photoUrl:
                    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&auto=format&fit=crop&q=80',
                isOnline: true,
                badgeText: 'Online',
                badgeColor: AppColors.success,
                isDark: isDark,
              ),
            ),

            // Floating Contact 2 (Bottom Left - Alex)
            Positioned(
              bottom: 24,
              left: 20,
              child: _buildAvatarNode(
                name: 'Alex',
                photoUrl:
                    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80',
                isOnline: true,
                badgeText: 'In Call',
                badgeColor: AppColors.cyanDark,
                isDark: isDark,
              ),
            ),

            // Floating Contact 3 (Bottom Right - John)
            Positioned(
              bottom: 30,
              right: 32,
              child: _buildAvatarNode(
                name: 'John',
                photoUrl:
                    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
                isOnline: false,
                isDark: isDark,
              ),
            ),

            // Floating signal chip (Top Left)
            Positioned(
              top: 36,
              left: 30,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Live Presence',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarNode({
    required String name,
    required String photoUrl,
    required bool isOnline,
    String? badgeText,
    Color? badgeColor,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: UserAvatar(
            name: name,
            photoUrl: photoUrl,
            radius: 24,
            isOnline: isOnline,
            showBadge: true,
          ),
        ),
        if (badgeText != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (badgeColor ?? AppColors.primaryBlue).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: badgeColor ?? AppColors.primaryBlue,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class OnboardingIllustration2 extends StatelessWidget {
  const OnboardingIllustration2({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SizedBox(
        width: 320,
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video Call Mock Card
            Container(
              width: 250,
              height: 210,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0B192E),
                    Color(0xFF132B4F),
                  ],
                ),
                borderRadius: AppRadius.roundedXl,
                border: Border.all(
                  color: AppColors.cyan.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Video user background
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const UserAvatar(
                          name: 'Sarah Johnson',
                          photoUrl:
                              'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&auto=format&fit=crop&q=80',
                          radius: 36,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Sarah Johnson',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Audio Waveform bars
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildWaveformBar(12, AppColors.cyan),
                            _buildWaveformBar(24, AppColors.primaryBlueLight),
                            _buildWaveformBar(18, AppColors.cyan),
                            _buildWaveformBar(30, AppColors.primaryBlueLight),
                            _buildWaveformBar(14, AppColors.cyan),
                            _buildWaveformBar(22, AppColors.primaryBlueLight),
                            _buildWaveformBar(10, AppColors.cyan),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Top HD Voice Pill
                  Positioned(
                    top: 12,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.graphic_eq_rounded, color: AppColors.cyan, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'HD Audio • 60 FPS',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Floating Controls Bar (Bottom)
            Positioned(
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMiniActionIcon(Icons.mic_rounded, AppColors.primaryBlue, isDark),
                    const SizedBox(width: 14),
                    _buildMiniActionIcon(Icons.videocam_rounded, AppColors.cyanDark, isDark),
                    const SizedBox(width: 14),
                    _buildMiniActionIcon(Icons.volume_up_rounded, AppColors.primaryBlueLight, isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildWaveformBar(double height, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.5),
      width: 3.5,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  static Widget _buildMiniActionIcon(IconData icon, Color color, bool isDark) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class OnboardingIllustration3 extends StatelessWidget {
  const OnboardingIllustration3({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SizedBox(
        width: 320,
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background Card 1 (Subtle offset)
            Positioned(
              top: 25,
              child: Transform.rotate(
                angle: -0.05,
                child: Container(
                  width: 250,
                  height: 76,
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.darkElevatedSurface : AppColors.surfaceSecondary)
                        .withValues(alpha: 0.6),
                    borderRadius: AppRadius.roundedLg,
                    border: Border.all(
                      color: (isDark ? AppColors.darkBorder : AppColors.border).withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),

            // Foreground Call History Card 1
            Positioned(
              top: 48,
              child: Container(
                width: 270,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: AppRadius.roundedLg,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    const UserAvatar(
                      name: 'Sarah Johnson',
                      photoUrl:
                          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&auto=format&fit=crop&q=80',
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Sarah Johnson',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.call_received_rounded, size: 12, color: AppColors.success),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Video Call • 11:45 AM',
                                  style: TextStyle(color: AppColors.secondaryText, fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.cyanSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '02:35',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.cyanDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Foreground Call History Card 2
            Positioned(
              top: 140,
              child: Container(
                width: 270,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: AppRadius.roundedLg,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    const UserAvatar(
                      name: 'Alex Wilson',
                      photoUrl:
                          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80',
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Alex Wilson',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.call_made_rounded, size: 12, color: AppColors.primaryBlue),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Audio Call • Yesterday',
                                  style: TextStyle(color: AppColors.secondaryText, fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '05:12',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
