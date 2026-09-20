import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/block_provider.dart';
import '../../widgets/user_avatar.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final blockService = ref.watch(blockServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Blocked Users')),
        body: const Center(child: Text('Please sign in.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.id)
            .collection('blockedUsers')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.block_rounded,
                    size: 64,
                    color: isDark ? AppColors.darkMutedText : AppColors.mutedText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Blocked Users',
                    style: AppTextStyles.h3(
                      color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Users you block will appear here.',
                    style: AppTextStyles.body(
                      color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final blockedUid = doc.id;
              final data = doc.data();
              final blockedName = (data['blockedName'] as String?)?.isNotEmpty == true
                  ? data['blockedName'] as String
                  : 'User ($blockedUid)';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: AppRadius.roundedLg,
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      name: blockedName,
                      radius: 20,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        blockedName,
                        style: AppTextStyles.bodyMedium(
                          color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onPressed: () async {
                        try {
                          await blockService.unblockUser(blockedUid);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Unblocked $blockedName'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to unblock: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Unblock'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
