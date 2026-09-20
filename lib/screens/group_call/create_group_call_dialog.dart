import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../models/call_model.dart' show CallType;
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_call_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/user_avatar.dart';
import 'group_call_screen.dart';

class CreateGroupCallDialog extends ConsumerStatefulWidget {
  const CreateGroupCallDialog({super.key});

  @override
  ConsumerState<CreateGroupCallDialog> createState() => _CreateGroupCallDialogState();
}

class _CreateGroupCallDialogState extends ConsumerState<CreateGroupCallDialog> {
  final _titleController = TextEditingController(text: 'Team Sync');
  final Set<UserModel> _selectedContacts = {};
  CallType _selectedCallType = CallType.video;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _startGroupCall() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    if (_selectedContacts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 2 contacts for a group call (3+ participants).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = ref.read(groupCallServiceProvider);
      final groupCall = await service.createGroupCall(
        title: _titleController.text.trim(),
        host: currentUser,
        selectedContacts: _selectedContacts.toList(),
        callType: _selectedCallType,
      );

      final joined = await service.joinGroupCall(groupCall, currentUser.id);

      if (joined && mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GroupCallScreen()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to group call.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(filteredContactsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'New Group Call',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Call Title',
                hintText: 'e.g. Design Review',
                prefixIcon: const Icon(Icons.group_rounded),
                filled: true,
                fillColor: isDark ? AppColors.darkElevatedSurface : AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.roundedLg,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Video Call')),
                    selected: _selectedCallType == CallType.video,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCallType = CallType.video);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Audio Call')),
                    selected: _selectedCallType == CallType.audio,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCallType = CallType.audio);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Select Participants (${_selectedContacts.length} selected, min 2):',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: contactsAsync.when(
                data: (contacts) {
                  if (contacts.isEmpty) {
                    return const Center(child: Text('No contacts available'));
                  }

                  return ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      final isSelected = _selectedContacts.contains(contact);

                      return CheckboxListTile(
                        value: isSelected,
                        secondary: UserAvatar(
                          name: contact.name,
                          photoUrl: contact.photoUrl,
                          radius: 18,
                        ),
                        title: Text(contact.name),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedContacts.add(contact);
                            } else {
                              _selectedContacts.remove(contact);
                            }
                          });
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.phone_in_talk_rounded),
                label: Text(
                  _isLoading
                      ? 'Starting...'
                      : 'Start Group ${_selectedCallType == CallType.video ? "Video" : "Audio"} Call (${_selectedContacts.length + 1})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _isLoading ? null : _startGroupCall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
