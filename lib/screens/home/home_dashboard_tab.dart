import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/call_history_provider.dart';
import '../../providers/call_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/user_avatar.dart';
import '../call/audio_call_screen.dart';
import '../call/video_call_screen.dart';
import '../search/search_screen.dart';

class HomeDashboardTab extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToContacts;
  final VoidCallback onNavigateToCalls;
  final VoidCallback? onNavigateToProfile;

  const HomeDashboardTab({
    super.key,
    required this.onNavigateToContacts,
    required this.onNavigateToCalls,
    this.onNavigateToProfile,
  });

  @override
  ConsumerState<HomeDashboardTab> createState() => _HomeDashboardTabState();
}

class _HomeDashboardTabState extends ConsumerState<HomeDashboardTab> {
  String? _callingUserId;

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

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF07111F) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF0D1B2A) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? const Color(0xFF24364A) : const Color(0xFFE2E8F0);
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const brandBlue = Color(0xFF075FEA);
    const brandCyan = Color(0xFF00CFF3);

    final currentUser = ref.watch(currentUserProvider);
    final contactsAsync = ref.watch(filteredContactsProvider);
    final historyAsync = ref.watch(callHistoryNotifierProvider);
    final frequentContacts = ref.watch(frequentContactsProvider);

    // Completely null-safe user greeting & name resolution
    final rawName = currentUser?.name.trim() ?? '';
    final hasName = rawName.isNotEmpty;
    final firstName = hasName ? rawName.split(RegExp(r'\s+')).first : 'there';
    final greetingTitle = '${_getTimeGreeting()}, $firstName 👋';
    const greetingSubtitle = 'Stay connected with your people.';

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: brandBlue,
          onRefresh: () async {
            ref.invalidate(contactsListProvider);
            ref.invalidate(contactsStreamProvider);
            await ref.read(callHistoryNotifierProvider.notifier).loadHistory();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // 1. HEADER: Greeting, Subtitle, and Top-Right Profile Avatar
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greetingTitle,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          greetingSubtitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: widget.onNavigateToProfile,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: brandBlue.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: UserAvatar(
                        name: hasName ? rawName : 'User',
                        photoUrl: currentUser?.photoUrl,
                        radius: 24,
                        isOnline: currentUser?.isOnline ?? true,
                        showBadge: true,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 2. SEARCH: "Search people..."
              GestureDetector(
                onTap: _openSearch,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: secondaryTextColor,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Search people...',
                          style: TextStyle(
                            fontSize: 15,
                            color: secondaryTextColor,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF13253A) : const Color(0xFFEAF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Find',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: brandBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 3. QUICK ACTIONS: Audio Call & Video Call Cards
              Row(
                children: [
                  // Audio Call Action
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.onNavigateToContacts,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF075FEA), Color(0xFF0284C7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: brandBlue.withValues(alpha: 0.28),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.phone_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Audio Call',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'High quality voice',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Video Call Action
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.onNavigateToContacts,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0891B2), Color(0xFF00CFF3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: brandCyan.withValues(alpha: 0.28),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.videocam_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Video Call',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'HD video calling',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 4. ONLINE CONTACTS / QUICK CONNECT SECTION (Optional, safe fallback)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Online Contacts',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onNavigateToContacts,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'See All',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: brandBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              contactsAsync.when(
                data: (contacts) {
                  final onlineContacts = contacts.where((u) => u.isOnline).toList();
                  if (onlineContacts.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.people_outline_rounded, size: 20, color: secondaryTextColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No contacts online right now.',
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryTextColor,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: widget.onNavigateToContacts,
                            child: const Text(
                              'Browse',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: brandBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: onlineContacts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final user = onlineContacts[index];
                        final uName = user.name.trim();
                        final uDisplayName = uName.isNotEmpty ? uName : 'User';
                        final uFirst = uDisplayName.split(RegExp(r'\s+')).first;

                        return GestureDetector(
                          onTap: () => _startCall(user, CallType.audio),
                          child: Column(
                            children: [
                              UserAvatar(
                                name: uDisplayName,
                                photoUrl: user.photoUrl,
                                radius: 26,
                                isOnline: true,
                                showBadge: true,
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 68,
                                child: Text(
                                  uFirst,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: primaryTextColor,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => Container(
                  height: 60,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: brandBlue),
                  ),
                ),
                error: (_, __) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 18, color: secondaryTextColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Contacts offline mode',
                          style: TextStyle(fontSize: 13, color: secondaryTextColor),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.invalidate(contactsListProvider);
                          ref.invalidate(contactsStreamProvider);
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(40, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Retry', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 4.5. FREQUENTLY CALLED / RECENT CONTACTS SECTION (Bonus 5)
              if (frequentContacts.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Frequently Called',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                    Text(
                      '${frequentContacts.length} contacts',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 156,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: frequentContacts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final contact = frequentContacts[index];
                      return Container(
                        width: 130,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UserAvatar(
                              name: contact.name,
                              photoUrl: contact.avatar,
                              radius: 19,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              contact.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${contact.callCount} calls • ${contact.lastCallTimeFormatted}',
                              style: TextStyle(
                                fontSize: 10,
                                color: secondaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    final target = UserModel(
                                      id: contact.userId,
                                      name: contact.name,
                                      email: '',
                                      phone: '',
                                      photoUrl: contact.avatar,
                                      isOnline: true,
                                      lastSeen: contact.lastCallTime,
                                      createdAt: contact.lastCallTime,
                                    );
                                    _startCall(target, CallType.audio);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF13253A) : const Color(0xFFEAF2FF),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.phone_rounded, size: 14, color: brandBlue),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () {
                                    final target = UserModel(
                                      id: contact.userId,
                                      name: contact.name,
                                      email: '',
                                      phone: '',
                                      photoUrl: contact.avatar,
                                      isOnline: true,
                                      lastSeen: contact.lastCallTime,
                                      createdAt: contact.lastCallTime,
                                    );
                                    _startCall(target, CallType.video);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0D3338) : const Color(0xFFE0F7FA),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.videocam_rounded, size: 14, color: Color(0xFF0097A7)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 5. RECENT CALLS SECTION
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent calls',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onNavigateToCalls,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: brandBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Independently handled async states for Recent Calls
              historyAsync.when(
                data: (calls) {
                  final recentCalls = calls.take(5).toList();
                  if (recentCalls.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF13253A) : const Color(0xFFEAF2FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.phone_missed_rounded,
                              size: 32,
                              color: brandBlue,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No recent calls',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your recent calls will appear here.',
                            style: TextStyle(
                              fontSize: 13,
                              color: secondaryTextColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            ),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                            label: const Text(
                              'Find someone to call',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            onPressed: widget.onNavigateToContacts,
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: recentCalls.map((call) {
                      final currentUserId = currentUser?.id ?? '';
                      final isOutgoing = call.callerId == currentUserId || call.direction == CallDirection.outgoing;
                      final rawDisplayName = (isOutgoing ? call.calleeName : call.callerName).trim();
                      final displayName = rawDisplayName.isNotEmpty ? rawDisplayName : 'Unknown User';
                      final displayPhoto = isOutgoing ? call.calleePhoto : call.callerPhoto;
                      final targetUserId = isOutgoing ? call.calleeId : call.callerId;
                      final isBusyWithThisCall = _callingUserId == targetUserId;

                      IconData directionIcon;
                      Color directionColor;
                      if (call.isMissed) {
                        directionIcon = Icons.call_missed_rounded;
                        directionColor = AppColors.error;
                      } else if (isOutgoing) {
                        directionIcon = Icons.call_made_rounded;
                        directionColor = brandBlue;
                      } else {
                        directionIcon = Icons.call_received_rounded;
                        directionColor = AppColors.success;
                      }

                      final durationText = call.durationSeconds > 0
                          ? ' • ${DateFormatter.formatDuration(call.durationSeconds)}'
                          : '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: UserAvatar(
                            name: displayName,
                            photoUrl: displayPhoto,
                            radius: 22,
                          ),
                          title: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: call.isMissed ? AppColors.error : primaryTextColor,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Icon(directionIcon, size: 14, color: directionColor),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${call.callType == CallType.video ? 'Video' : 'Audio'} • ${DateFormatter.formatCallTime(call.startedAt)}$durationText',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          trailing: isBusyWithThisCall
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: brandBlue),
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.phone_rounded,
                                        color: isDark ? const Color(0xFF3B82F6) : brandBlue,
                                        size: 20,
                                      ),
                                      tooltip: 'Call $displayName',
                                      onPressed: () {
                                        final targetUser = UserModel(
                                          id: targetUserId,
                                          name: displayName,
                                          email: '$displayName@connectcall.io',
                                          photoUrl: displayPhoto,
                                          lastSeen: DateTime.now(),
                                        );
                                        _startCall(targetUser, CallType.audio);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.videocam_rounded,
                                        color: Color(0xFF00A9CC),
                                        size: 22,
                                      ),
                                      tooltip: 'Video call $displayName',
                                      onPressed: () {
                                        final targetUser = UserModel(
                                          id: targetUserId,
                                          name: displayName,
                                          email: '$displayName@connectcall.io',
                                          photoUrl: displayPhoto,
                                          lastSeen: DateTime.now(),
                                        );
                                        _startCall(targetUser, CallType.video);
                                      },
                                    ),
                                  ],
                                ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => Container(
                  height: 100,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: brandBlue),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Loading recent calls...',
                        style: TextStyle(fontSize: 13, color: secondaryTextColor),
                      ),
                    ],
                  ),
                ),
                error: (error, _) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.sync_problem_rounded,
                        size: 36,
                        color: secondaryTextColor,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Unable to load recent calls',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Check your network connection and retry.',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () {
                          ref.read(callHistoryNotifierProvider.notifier).loadHistory();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
