import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:radar_dashboard/dashboard/dashboard_screen.dart';
import 'package:radar_dashboard/screens/analytics_screen.dart';
import 'package:radar_dashboard/screens/incidents/incident_report_screen.dart';
import 'package:radar_dashboard/screens/mapping_screen.dart';
import 'package:radar_dashboard/screens/settings_screen.dart';
import 'package:radar_dashboard/login/login_register_screen.dart';
import 'package:radar_dashboard/notifications/notification_screen.dart';
import 'package:radar_dashboard/dashboard/admin%20panel%20screen/admin_management_screen.dart';

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
  final SupabaseClient _supabase = Supabase.instance.client;
  int _selectedIndex = 0;
  int _previousIndex = 0;
  String _userName = 'Loading...';

  late final List<NavigationItem> _navigationItems;
  final Map<int, Widget> _screenCache = {};

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _initializeNavigationItems();
  }

  Future<void> _fetchUserName() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        // Fetch user profile from your profiles table
        final response = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .single();

        // For newer Supabase versions, response is the data directly
        if (response != null) {
          final String? fullName = response['full_name'];
          if (mounted) {
            setState(() {
              _userName = fullName ?? user.email?.split('@').first ?? 'User';
            });
          }
        } else {
          // Fallback to email username if profile not found
          if (mounted) {
            setState(() {
              _userName = user.email?.split('@').first ?? 'User';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching user name: $e');
      // Fallback to email username
      final user = _supabase.auth.currentUser;
      if (mounted) {
        setState(() {
          _userName = user?.email?.split('@').first ?? 'User';
        });
      }
    }
  }

  void _initializeNavigationItems() {
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
        screenBuilder: (onMenuPressed) => IncidentReportScreen(
          onMenuPressed: onMenuPressed,
          userRole: widget.userRole,
        ),
        hasFloatingAction: true,
      ),
      NavigationItem(
        title: 'Maps',
        icon: Icons.map_rounded,
        screenBuilder: (onMenuPressed) =>
            MapMonitoringScreen(onMenuPressed: onMenuPressed),
      ),
      NavigationItem(
        title: 'Analytics',
        icon: Icons.analytics_rounded,
        screenBuilder: (onMenuPressed) =>
            AnalyticsScreen(onMenuPressed: onMenuPressed),
      ),
      // Add Notifications screen for admin and moderator
      NavigationItem(
        title: 'Notifications',
        icon: Icons.notifications_rounded,
        screenBuilder: (onMenuPressed) =>
            NotificationScreen(onMenuPressed: onMenuPressed),
      ),
      // Add Admin Panel only for admin role
      if (widget.userRole == 'admin')
        NavigationItem(
          title: 'Admin Panel',
          icon: Icons.admin_panel_settings_rounded,
          screenBuilder: (onMenuPressed) => AdminManagementScreen(
            onMenuPressed: onMenuPressed,
          ),
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
    if (widget.userRole == 'moderator') {
      // Moderator gets all items except Admin Panel
      _navigationItems = allItems.where((item) => item.title != 'Admin Panel').toList();
    } else if (widget.userRole == 'admin') {
      // Admin gets all items
      _navigationItems = allItems;
    } else {
      // User gets limited items
      _navigationItems = allItems
          .where((item) =>
              item.title == 'Dashboard' ||
              item.title == 'Incident Reports' ||
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
            _buildDrawerHeader(),
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
                            _buildDrawerItem(entry.value, entry.key)),
                    const Divider(height: 32, thickness: 1),
                    _buildUserInfoTile(),
                    _buildSignOutTile(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
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
                    color: Colors.black.withAlpha(89), // 0.35 opacity
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Emergency Response System',
              style: TextStyle(
                color: Colors.white.withAlpha(229), // 0.9 opacity equivalent
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(64), // 0.25 opacity equivalent
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

  Widget _buildDrawerItem(NavigationItem item, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = index == _selectedIndex;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withAlpha(25) // 0.1 opacity equivalent
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          item.icon,
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurface.withAlpha(178), // 0.7 opacity equivalent
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
        hoverColor: colorScheme.primary.withAlpha(12), // 0.05 opacity equivalent
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () => _handleDrawerItemTap(item, index),
      ),
    );
  }

  Widget _buildUserInfoTile() {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Get role display name
    String roleDisplay;
    switch (widget.userRole) {
      case 'admin':
        roleDisplay = 'Administrator';
        break;
      case 'moderator':
        roleDisplay = 'Moderator';
        break;
      case 'user':
        roleDisplay = 'User';
        break;
      default:
        roleDisplay = 'User';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primary.withAlpha(25), // 0.1 opacity equivalent
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person_rounded,
            color: colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          _userName,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          roleDisplay,
          style: TextStyle(
            color: colorScheme.onSurface.withAlpha(178), // 0.7 opacity equivalent
            fontSize: 12,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSignOutTile() {
    final colorScheme = Theme.of(context).colorScheme;
    
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
      try {
        // Use Supabase signOut instead of Firebase
        await _supabase.auth.signOut();
        
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginRegisterScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        debugPrint('Sign out error: $e');
        // Even if there's an error, navigate to login screen
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginRegisterScreen()),
            (route) => false,
          );
        }
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