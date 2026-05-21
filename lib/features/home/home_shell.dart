import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jagt_app/providers/auth_provider.dart';
import 'package:jagt_app/models/user_profile.dart';
import 'package:jagt_app/features/home/home_page.dart';
import 'package:jagt_app/features/map/presentation/pages/map_page.dart';
import 'package:jagt_app/features/calendar/presentation/pages/calendar_page.dart';
import 'package:jagt_app/features/chat/presentation/pages/chat_list_page.dart';
import 'package:jagt_app/features/profile/presentation/pages/profile_page.dart';
import 'package:jagt_app/services/app_update_service.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;
  bool _updateChecked = false;

  @override
  Widget build(BuildContext context) {
    if (!_updateChecked) {
      _updateChecked = true;
      Future.microtask(() => AppUpdateService.checkForUpdate(context));
    }

    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Fejl: $e')),
      ),
      data: (profile) {
        if (profile == null) {
          return const Scaffold(
            body: Center(child: Text('Profil ikke fundet')),
          );
        }

        final tabs = _buildTabs(profile);
        final safeIndex = _currentIndex.clamp(0, tabs.length - 1);

        return Scaffold(
          body: IndexedStack(
            index: safeIndex,
            children: tabs.map((t) => t.page).toList(),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            destinations: tabs
                .map((t) => NavigationDestination(
                      icon: Icon(t.icon),
                      selectedIcon: Icon(t.selectedIcon),
                      label: t.label,
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  List<_TabItem> _buildTabs(UserProfile profile) {
    return [
      const _TabItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'Hjem',
        page: HomePage(),
      ),
      const _TabItem(
        icon: Icons.map_outlined,
        selectedIcon: Icons.map,
        label: 'Kort',
        page: MapPage(),
      ),
      const _TabItem(
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month,
        label: 'Kalender',
        page: CalendarPage(),
      ),
      const _TabItem(
        icon: Icons.chat_outlined,
        selectedIcon: Icons.chat,
        label: 'Chat',
        page: ChatListPage(),
      ),
      const _TabItem(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'Profil',
        page: ProfilePage(),
      ),
    ];
  }
}

class _TabItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget page;

  const _TabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.page,
  });
}
