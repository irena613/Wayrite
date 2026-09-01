import 'package:flutter/material.dart';
import '../../core/theme/app_icons.dart';
import '../../data/app_store.dart';
import '../feed/feed_screen.dart';
import '../notifications/notifications_screen.dart';
import '../post/create_post_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';

/// Главна навигациска обвивка по најава — bottom navigation со 4 таба
/// (Feed, Пребарување, Нотификации, Профил) + централно FAB копче за
/// креирање нова објава.
///
/// UI flow (целосен граф на апликацијата):
///   Login/Register -> HomeShell
///   HomeShell tabs: Feed | Search | Notifications | Profile
///   HomeShell FAB(+) -> CreatePostScreen -> назад на Feed
///   Feed/Profile -> PostCard tap -> PostDetailScreen (коментари + лајкови)
///   Search -> UserListTile акции -> барање/прифаќање пријателство
///   Notifications -> tap -> PostDetailScreen или SearchScreen
///   Profile -> "Уреди профил" -> EditProfileScreen
///   Profile -> "Одјави се" -> LoginScreen
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    FeedScreen(),
    SearchScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  void _openCreatePost() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreatePost,
        tooltip: 'Нова објава',
        child: const Icon(AppIcons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: ListenableBuilder(
        listenable: appStore,
        builder: (context, _) {
          final unread = appStore.unreadNotificationCount;
          return BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: AppIcons.feed,
                  label: 'Почетна',
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _NavItem(
                  icon: AppIcons.search,
                  label: 'Пребарај',
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                const SizedBox(width: 40), // простор за FAB
                _NavItem(
                  icon: unread > 0 ? AppIcons.notificationsActive : AppIcons.notifications,
                  label: 'Нотиф.',
                  selected: _index == 2,
                  badgeCount: unread,
                  onTap: () {
                    setState(() => _index = 2);
                    appStore.markAllNotificationsRead();
                  },
                ),
                _NavItem(
                  icon: AppIcons.profile,
                  label: 'Профил',
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).bottomNavigationBarTheme.unselectedItemColor;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badgeCount > 0,
              label: Text('$badgeCount'),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
