import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/call_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/empty_state_widget.dart';
import '../call/audio_call_screen.dart';
import '../call/video_call_screen.dart';
import '../group_call/create_group_call_dialog.dart';
import '../profile/user_profile_screen.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/user_tile.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _searchController = TextEditingController();
  String? _callingUserId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startCall(UserModel targetUser, CallType callType) async {
    debugPrint('[CALL TRACE] 01 ${callType == CallType.video ? "Video" : "Audio"} button pressed (target: ${targetUser.id})');
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null && targetUser.id == currentUser.id) {
      debugPrint('[CALL TRACE] Cannot call yourself');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot call yourself.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_callingUserId != null) {
      debugPrint('[CALL TRACE] Double tap prevented: _callingUserId is $_callingUserId');
      return;
    }

    setState(() => _callingUserId = targetUser.id);
    debugPrint('[CALL TRACE] UI loading state set to true for: ${targetUser.id}');

    try {
      final success = await ref.read(callControllerProvider.notifier).startCall(
            targetUser: targetUser,
            callType: callType,
          );

      if (success && mounted) {
        debugPrint('[CALL TRACE] 10 navigation START');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => callType == CallType.video
                ? const VideoCallScreen()
                : const AudioCallScreen(),
          ),
        );
        debugPrint('[CALL TRACE] 11 navigation END');
      } else if (mounted) {
        debugPrint('[CALL TRACE] navigation SKIPPED: success=$success');
        final session = ref.read(callControllerProvider);
        if (session.errorMessage != null) {
          debugPrint('[CALL TRACE] UI showing error message: ${session.errorMessage}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(session.errorMessage!),
              backgroundColor: AppColors.error,
              action: session.errorMessage!.contains('Settings')
                  ? SnackBarAction(
                      label: 'Settings',
                      textColor: Colors.white,
                      onPressed: () => ref.read(permissionServiceProvider).openAppSettings(),
                    )
                  : null,
            ),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('[CALL TRACE] UI _startCall EXCEPTION: $e\n$stack');
    } finally {
      if (mounted) {
        setState(() => _callingUserId = null);
        debugPrint('[CALL TRACE] UI loading state cleared (finally)');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(filteredContactsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_rounded),
            tooltip: 'New Group Call (3+)',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const CreateGroupCallDialog(),
              );
            },
          ),
        ],
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
                      ref.invalidate(contactsStreamProvider);
                    },
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primaryBlue,
                  onRefresh: () async {
                    ref.invalidate(contactsListProvider);
                    ref.invalidate(contactsStreamProvider);
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final user = contacts[index];
                      return UserTile(
                        user: user,
                        isCalling: _callingUserId == user.id,
                        onAudioCall: () => _startCall(user, CallType.audio),
                        onVideoCall: () => _startCall(user, CallType.video),
                        onTap: () => UserProfileScreen.show(context, user),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primaryBlue),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        'Unable to load contacts',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Please check your connection and pull down to refresh.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(contactsListProvider);
                          ref.invalidate(contactsStreamProvider);
                        },
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

