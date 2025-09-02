import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:radar_dashboard/dashboard/dashboard_screen.dart';
import 'package:radar_dashboard/screens/analytics_screen.dart';
import 'package:radar_dashboard/screens/emergencies_screen.dart';
import 'package:radar_dashboard/screens/mapping_screen.dart';
import 'package:radar_dashboard/screens/settings_screen.dart';

class NavigationScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onToggleTheme;
  final String userRole; // <-- NEW

  const NavigationScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.userRole, // <-- NEW
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  late final List<NavigationItem> _navigationItems;

  @override
  void initState() {
    super.initState();

    // All items
    final allItems = [
      NavigationItem(
        title: 'Dashboard',
        icon: Icons.dashboard_outlined,
        screenBuilder: (onMenuPressed) => DashboardScreen(onMenuPressed: onMenuPressed),
      ),
      NavigationItem(
        title: 'Incident Reports',
        icon: Icons.emergency_outlined,
        screenBuilder: (onMenuPressed) => EmergenciesScreen(onMenuPressed: onMenuPressed),
        hasFloatingAction: true,
      ),
      NavigationItem(
        title: 'Hazard Mapping',
        icon: Icons.map_outlined,
        screenBuilder: (onMenuPressed) => MapMonitoringpingScreen(onMenuPressed: onMenuPressed),
      ),
      NavigationItem(
        title: 'Analytics',
        icon: Icons.analytics_outlined,
        screenBuilder: (onMenuPressed) => AnalyticsScreen(onMenuPressed: onMenuPressed)
      ),
      // NavigationItem(
      //   title: 'Users',
      //   icon: Icons.people_alt_outlined,
      //   screenBuilder: (_) => const UsersManagementScreen(),
      // ),
      NavigationItem(
        title: 'System Settings',
        icon: Icons.settings_outlined,
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
      _navigationItems = allItems.where((item) =>
        item.title == 'Dashboard' || item.title == 'Incident Reports'
      ).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildAppDrawer(),
      body: _buildCurrentScreenWithTransition(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildCurrentScreenWithTransition() {
    return PageTransitionSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
        return FadeTransition(opacity: primaryAnimation, child: child);
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_selectedIndex),
        child: _navigationItems[_selectedIndex].screenBuilder(() {
          _scaffoldKey.currentState?.openDrawer();
        }),
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (!_navigationItems[_selectedIndex].hasFloatingAction) return null;

    return FloatingActionButton(
      onPressed: _handleNewEmergency,
      child: const Icon(Icons.add_alert_outlined),
    );
  }

  Widget _buildAppDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF2C5282),
      elevation: 4,
      child: Column(
        children: [
          _buildDrawerHeader(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF9F9F9),
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ..._navigationItems.map(_buildDrawerItem),
                  const Divider(color: Colors.grey, height: 32, thickness: 0.5),
                  // Add logout if needed
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return DrawerHeader(
      decoration: const BoxDecoration(color: Color(0xFF2C5282)),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PROJECT RADAR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Emergency Response System',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blueGrey[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'VERSION 1.0.0',
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(NavigationItem item) {
    final isSelected = !item.isLogout && _navigationItems.indexOf(item) == _selectedIndex;

    return ListTile(
      leading: Icon(
        item.icon,
        color: isSelected ? Colors.blue[600] : Colors.blueGrey[600],
      ),
      title: Text(
        item.title,
        style: TextStyle(
          color: isSelected ? Colors.blue[600] : Colors.blueGrey[800],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 14,
        ),
      ),
      selected: isSelected,
      hoverColor: Colors.blue[50],
      onTap: () => item.isLogout ? _showLogoutDialog() : _handleDrawerItemTap(item),
    );
  }

  void _handleDrawerItemTap(NavigationItem item) {
    final index = _navigationItems.indexOf(item);
    if (index >= 0) {
      setState(() => _selectedIndex = index);
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _performLogout,
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _performLogout() {
    Navigator.of(context)
      ..pop()
      ..pop();
    // TODO: Add actual logout logic here
  }

  void _handleNewEmergency() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: const Text('New Emergency Report Form'),
      ),
    );
  }
}

class NavigationItem {
  final String title;
  final IconData icon;
  final Widget Function(VoidCallback onMenuPressed) screenBuilder;
  final bool hasFloatingAction;
  final bool isLogout;

  NavigationItem({
    required this.title,
    required this.icon,
    required this.screenBuilder,
    this.hasFloatingAction = false,
    this.isLogout = false,
  });
}
