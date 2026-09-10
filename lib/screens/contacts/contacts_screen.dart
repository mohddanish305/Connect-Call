import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../../providers/call_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/empty_state_widget.dart';
import '../call/audio_call_screen.dart';
import '../call/video_call_screen.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/user_tile.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startCall(UserModel targetUser, CallType callType) async {
    final success = await ref.read(callControllerProvider.notifier).startCall(
          targetUser: targetUser,
          callType: callType,
        );

    if (success && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => callType == CallType.video
              ? const VideoCallScreen()
              : const AudioCallScreen(),
        ),
      );
    } else {
      final session = ref.read(callControllerProvider);
      if (session.errorMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(session.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(filteredContactsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: SearchBarWidget(
              controller: _searchController,
              onChanged: (val) {
                ref.read(searchQueryProvider.notifier).state = val;
              },
              onClear: () {
                _searchController.clear();
                ref.read(searchQueryProvider.notifier).state = '';
              },
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          // Contacts List
          Expanded(
            child: contactsAsync.when(
              data: (contacts) {
                if (contacts.isEmpty) {
                  return EmptyStateWidget.noContacts(
                    onAction: () {
                      _searchController.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                      ref.invalidate(contactsListProvider);
                    },
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(contactsListProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final user = contacts[index];
                      return UserTile(
                        user: user,
                        onAudioCall: () => _startCall(user, CallType.audio),
                        onVideoCall: () => _startCall(user, CallType.video),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primaryBlue),
              ),
              error: (e, _) => Center(
                child: Text('Failed to load contacts: $e'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
