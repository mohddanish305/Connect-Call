import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common_button.dart';

class EditProfileDialog extends ConsumerStatefulWidget {
  const EditProfileDialog({super.key});

  @override
  ConsumerState<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<EditProfileDialog> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _nameController.text = user.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() => _isLoading = true);
    final success = await ref.read(authNotifierProvider.notifier).updateProfile(
          name: newName,
        );
    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Profile',
              style: AppTextStyles.h3(
                color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Display Name',
              style: AppTextStyles.bodyMedium(
                color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Enter your name',
                prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: AppTextStyles.button(
                        color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CommonButton(
                    text: 'Save',
                    height: 44,
                    isLoading: _isLoading,
                    onPressed: _handleSave,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
