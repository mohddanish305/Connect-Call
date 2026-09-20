import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/block_provider.dart';
import '../../providers/call_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/user_avatar.dart';
import '../call/audio_call_screen.dart';
import '../call/video_call_screen.dart';
import '../profile/user_profile_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounceTimer;
  String _currentQuery = '';
  bool _isSearching = false;
  List<UserModel> _searchResults = [];
  String? _callingUserId;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _loadInitialContacts();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialContacts() async {
    setState(() => _isSearching = true);
    final userService = ref.read(userServiceProvider);
    final currentUser = ref.read(currentUserProvider);
    final contacts = await userService.getContacts(currentUserId: currentUser?.id);
    if (mounted) {
      setState(() {
        _searchResults = contacts;
        _isSearching = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _currentQuery = query;
      _isSearching = true;
    });

    final userService = ref.read(userServiceProvider);
    final currentUser = ref.read(currentUserProvider);
    final results = await userService.searchContacts(query, currentUserId: currentUser?.id);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _performSearch('');
  }

  Future<void> _startCall(UserModel targetUser, CallType callType) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null && targetUser.id == currentUser.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot call yourself.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final isBlocked = ref.read(isUserBlockedProvider(targetUser.id));
    if (isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have blocked this user.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_callingUserId != null) return; // Prevent double-tap

    setState(() => _callingUserId = targetUser.id);

    try {
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
      } else if (mounted) {
        final session = ref.read(callControllerProvider);
        if (session.errorMessage != null) {
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
    } finally {
      if (mounted) {
        setState(() => _callingUserId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkElevatedSurface : AppColors.surfaceSecondary,
              borderRadius: AppRadius.roundedMd,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              style: AppTextStyles.body(
                color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
              ),
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                hintStyle: AppTextStyles.body(
                  color: isDark ? AppColors.darkMutedText : AppColors.mutedText,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                        onPressed: _clearSearch,
                        tooltip: 'Clear search',
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    final blockedIds = ref.watch(blockedUserIdsStreamProvider).valueOrNull ?? {};
    final visibleResults = _searchResults.where((u) => !blockedIds.contains(u.id)).toList();

    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      );
    }

    if (visibleResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkElevatedSurface : AppColors.surfaceSecondary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_search_rounded,
                  size: 48,
                  color: isDark ? AppColors.darkMutedText : AppColors.mutedText,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _currentQuery.isEmpty ? 'Find someone to call' : 'No users found',
                style: AppTextStyles.h3(
                  color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _currentQuery.isEmpty
                    ? 'Search contacts by name, email, or phone number.'
                    : 'No matching contact for "$_currentQuery". Try a different query.',
                style: AppTextStyles.body(
                  color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      itemCount: visibleResults.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 68,
        color: isDark ? AppColors.darkBorder : AppColors.border,
      ),
      itemBuilder: (context, index) {
        final user = visibleResults[index];
        final isBusyWithThisUser = _callingUserId == user.id;

        return InkWell(
          onTap: () => UserProfileScreen.show(context, user),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
            children: [
              UserAvatar(
                name: user.name,
                photoUrl: user.photoUrl,
                radius: 24,
                isOnline: user.isOnline,
                showBadge: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: AppTextStyles.bodyMedium(
                        color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email.isNotEmpty ? user.email : user.phone,
                      style: AppTextStyles.caption(
                        color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.lastSeenFormatted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(
                        color: user.isOnline ? AppColors.success : AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              if (isBusyWithThisUser)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Audio Call Button
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkElevatedSurface : AppColors.surfaceSecondary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phone_rounded,
                          color: AppColors.primaryBlue,
                          size: 18,
                        ),
                      ),
                      tooltip: 'Voice call ${user.name}',
                      onPressed: () => _startCall(user, CallType.audio),
                    ),
                    // Video Call Button
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkElevatedSurface : AppColors.surfaceSecondary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.videocam_rounded,
                          color: AppColors.cyanDark,
                          size: 18,
                        ),
                      ),
                      tooltip: 'Video call ${user.name}',
                      onPressed: () => _startCall(user, CallType.video),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    },
    );
  }
}
