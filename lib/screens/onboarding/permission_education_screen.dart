import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_spacing.dart';
import '../../providers/call_provider.dart';
import '../../services/permission_service.dart';
import '../home/home_screen.dart';

class PermissionEducationScreen extends ConsumerWidget {
  const PermissionEducationScreen({super.key});

  Future<void> _requestPermissions(BuildContext context, WidgetRef ref) async {
    final permissionService = ref.read(permissionServiceProvider);
    
    // Request both permissions
    final status = await permissionService.requestVideoPermissions();
    
    if (context.mounted) {
      if (status == CallPermissionStatus.permanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Permissions permanently denied. Please enable them in App Settings.'),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => permissionService.openAppSettings(),
            ),
          ),
        );
      }
      
      // Navigate to Home regardless of outcome. Calls will be blocked later if they try to make one without permissions.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  void _skipPermissions(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              
              // Illustration/Icons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_rounded, color: AppColors.cyan, size: 48),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videocam_rounded, color: AppColors.cyan, size: 48),
                  ),
                ],
              ),
              
              const SizedBox(height: AppSpacing.xxxl),
              
              // Title
              Text(
                'Camera & Microphone Access',
                style: AppTextStyles.h1(color: AppColors.white),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              // Description
              Text(
                'ConnectCall needs access to your camera and microphone so you can make and receive high-quality audio and video calls with your contacts.',
                style: AppTextStyles.body(color: AppColors.darkMutedText),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: AppSpacing.xl),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkElevatedSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security_rounded, color: AppColors.success, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your privacy is our priority. ConnectCall only uses these permissions when you are actively on a call.',
                        style: AppTextStyles.caption(color: AppColors.darkMutedText),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),
              
              // Buttons
              ElevatedButton(
                onPressed: () => _requestPermissions(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Allow Permissions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              
              const SizedBox(height: AppSpacing.md),
              
              TextButton(
                onPressed: () => _skipPermissions(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.darkMutedText,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Not Now',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
