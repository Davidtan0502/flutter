import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:radar_dashboard/dashboard/dashboard_screen.dart';
import 'package:radar_dashboard/screens/analytics_screen.dart';
import 'package:radar_dashboard/screens/incident_report_screen.dart';
import 'package:radar_dashboard/screens/mapping_screen.dart';
import 'package:radar_dashboard/screens/settings_screen.dart';
import 'package:radar_dashboard/login/login_register_screen.dart';
import 'package:radar_dashboard/notifications/notification_screen.dart'; // Import the notification screen

class NavigationScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onToggleTheme;
  final String userRole;

  const NavigationScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.userRole,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  int _previousIndex = 0;

  late final List<NavigationItem> _navigationItems;
  final Map<int, Widget> _screenCache = {};

  @override
  void initState() {
    super.initState();

    // All navigation items
    final allItems = [
      NavigationItem(
        title: 'Dashboard',
        icon: Icons.dashboard_rounded,
        screenBuilder: (onMenuPressed) =>
            DashboardScreen(onMenuPressed: onMenuPressed),
      ),
      NavigationItem(
        title: 'Incident Reports',
        icon: Icons.emergency_rounded,
        screenBuilder: (onMenuPressed) => EmergenciesScreen(
          onMenuPressed: onMenuPressed,
          userRole: widget.userRole,
        ),
        hasFloatingAction: true,
      ),
      NavigationItem(
        title: 'Maps',
        icon: Icons.map_rounded,
        screenBuilder: (onMenuPressed) =>
            MapMonitoringpingScreen(onMenuPressed: onMenuPressed),
      ),
      NavigationItem(
        title: 'Analytics',
        icon: Icons.analytics_rounded,
        screenBuilder: (onMenuPressed) =>
            AnalyticsScreen(onMenuPressed: onMenuPressed),
      ),
      // Add Notifications screen for admin only
      if (widget.userRole == 'admin')
        NavigationItem(
          title: 'Notifications',
          icon: Icons.notifications_rounded,
          screenBuilder: (onMenuPressed) =>
              NotificationScreen(onMenuPressed: onMenuPressed),
        ),
      NavigationItem(
        title: 'Settings',
        icon: Icons.settings_rounded,
        screenBuilder: (onMenuPressed) => SettingsScreen(
          onMenuPressed: onMenuPressed,
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
    ];

    // Filter based on role
    if (widget.userRole == 'admin') {
      _navigationItems = allItems;
    } else {
      _navigationItems = allItems
          .where((item) =>
              item.title == 'Dashboard' ||
              item.title == 'Incident Reports' ||
              item.title == 'Analytics' ||
              item.title == 'Settings')
          .toList();
    }

    // Pre-cache first screen
    _getScreen(0);
  }

  Widget _getScreen(int index) {
    if (!_screenCache.containsKey(index)) {
      _screenCache[index] = _navigationItems[index].screenBuilder(() {
        _scaffoldKey.currentState?.openDrawer();
      });
    }
    return _screenCache[index]!;
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildAppDrawer(),
      body: _buildCurrentScreenWithSlideTransition(),
    );
  }

  /// Smooth sliding effect using SharedAxisTransition
  Widget _buildCurrentScreenWithSlideTransition() {
    return PageTransitionSwitcher(
      duration: const Duration(milliseconds: 350),
      reverse: _selectedIndex < _previousIndex,
      transitionBuilder: (Widget child, Animation<double> animation,
          Animation<double> secondaryAnimation) {
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_selectedIndex),
        child: _getScreen(_selectedIndex),
      ),
    );
  }

  Widget _buildAppDrawer() {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: colorScheme.surface,
      elevation: 8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
      ),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
          children: [
            _buildDrawerHeader(colorScheme),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: ListView(
                  padding: const EdgeInsets.only(top: 16),
                  children: [
                    ..._navigationItems
                        .asMap()
                        .entries
                        .map((entry) =>
                            _buildDrawerItem(entry.value, entry.key, colorScheme)),
                    const Divider(height: 32, thickness: 1),
                    _buildSignOutTile(colorScheme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(ColorScheme colorScheme) {
    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2C5282),
              Color(0xFF3182CE),
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PROJECT RADAR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
                shadows: [
                  Shadow(
                    blurRadius: 5,
                    color: Colors.black.withOpacity(0.35),
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Emergency Response System',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'VERSION 1.0.0',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
      NavigationItem item, int index, ColorScheme colorScheme) {
    final isSelected = index == _selectedIndex;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          item.icon,
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurface.withOpacity(0.7),
          size: 24,
        ),
        title: Text(
          item.title,
          style: TextStyle(
            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        selected: isSelected,
        hoverColor: colorScheme.primary.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () => _handleDrawerItemTap(item, index),
      ),
    );
  }

  Widget _buildSignOutTile(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(
          Icons.logout_rounded,
          color: colorScheme.error,
          size: 24,
        ),
        title: Text(
          'Sign Out',
          style: TextStyle(
            color: colorScheme.error,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: _handleSignOut,
      ),
    );
  }

  void _handleDrawerItemTap(NavigationItem item, int index) {
    if (index >= 0 && index != _selectedIndex) {
      setState(() {
        _previousIndex = _selectedIndex;
        _selectedIndex = index;
      });
    }
    _scaffoldKey.currentState?.closeDrawer();
  }

  void _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginRegisterScreen()),
          (route) => false,
        );
      }
    }
  }
}

class NavigationItem {
  final String title;
  final IconData icon;
  final Widget Function(VoidCallback onMenuPressed) screenBuilder;
  final bool hasFloatingAction;

  NavigationItem({
    required this.title,
    required this.icon,
    required this.screenBuilder,
    this.hasFloatingAction = false,
  });
}