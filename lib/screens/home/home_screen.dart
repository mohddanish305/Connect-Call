import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/call_model.dart';
import '../../providers/call_provider.dart';
import '../call/incoming_call_screen.dart';
import '../contacts/contacts_screen.dart';
import '../history/call_history_screen.dart';
import '../profile/profile_screen.dart';
import 'home_dashboard_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Listen for incoming call events
    ref.listen(callControllerProvider, (previous, next) {
      if (next.status == CallStatus.ringing &&
          next.call?.direction == CallDirection.incoming &&
          (previous == null || previous.status != CallStatus.ringing)) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const IncomingCallScreen(),
            fullscreenDialog: true,
          ),
        );
      }
    });

    final tabs = [
      HomeDashboardTab(
        onNavigateToContacts: () => setState(() => _currentIndex = 1),
        onNavigateToCalls: () => setState(() => _currentIndex = 2),
      ),
      const ContactsScreen(),
      const CallHistoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.border,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: isDark ? AppColors.primaryBlueLight : AppColors.primaryBlue,
          unselectedItemColor: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline_rounded),
              activeIcon: Icon(Icons.people_rounded),
              label: 'Contacts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.phone_outlined),
              activeIcon: Icon(Icons.phone_rounded),
              label: 'Calls',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
