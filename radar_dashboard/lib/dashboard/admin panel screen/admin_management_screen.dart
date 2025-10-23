import 'package:flutter/material.dart';
import 'package:radar_dashboard/login/login_register_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:radar_dashboard/navigation/main_navigation.dart';
import 'package:radar_dashboard/dashboard/admin%20panel%20screen/user_management_service.dart';
import 'package:radar_dashboard/dashboard/admin%20panel%20screen/admin_incident_report_screen.dart';
import 'package:radar_dashboard/supabase_config.dart';

class AdminManagementScreen extends StatefulWidget {
  final int initialSystem;
  final VoidCallback? onMenuPressed;
  
  const AdminManagementScreen({
    super.key, 
    this.initialSystem = 0, 
    this.onMenuPressed,
  });

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> with SingleTickerProviderStateMixin {
  late int _selectedSystem;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  final SupabaseClient _supabase = Supabase.instance.client;
  final SupabaseClient _supabaseAdmin = SupabaseClient(
    SupabaseConfig.url,
    SupabaseConfig.serviceRoleKey,
  );
  
  bool _isRefreshing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _selectedSystem = widget.initialSystem;
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Get the appropriate client based on system type
  SupabaseClient get _currentClient => _selectedSystem == 0 ? _supabaseAdmin : _supabase;
  

  // Role management methods using admin client
  Future<bool> _promoteToModerator(String userId) async {
    try {
      final response = await _supabaseAdmin
          .from('dashboard_users')
          .update({'role': 'moderator'})
          .eq('id', userId);

      return response != null;
    } catch (e) {
      debugPrint('Error promoting to moderator: $e');
      _showCustomSnackBar(
        'Failed to promote user to moderator',
        Icons.error_rounded,
        Colors.red,
      );
      return false;
    }
  }

  Future<bool> _demoteToUser(String userId) async {
    try {
      final response = await _supabaseAdmin
          .from('dashboard_users')
          .update({'role': 'user'})
          .eq('id', userId);

      return response != null;
    } catch (e) {
      debugPrint('Error demoting to user: $e');
      _showCustomSnackBar(
        'Failed to demote user',
        Icons.error_rounded,
        Colors.red,
      );
      return false;
    }
  }

  // Getters for system configuration
  String get _currentTable => _selectedSystem == 0 ? 'dashboard_users' : 'app_users';
  String get _systemTitle => _selectedSystem == 0 ? 'Dashboard System' : 'Radar App System';
  String get _systemDescription => _selectedSystem == 0 
      ? 'Manage dashboard user roles and permissions' 
      : 'Manage mobile app users and emergency data';

  void _onSystemChanged(int system) {
    _animationController.reset();
    setState(() {
      _selectedSystem = system;
      _searchQuery = '';
      _searchController.clear();
    });
    _animationController.forward();
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
  }

  void _onClearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      _showCustomSnackBar(
        'Data refreshed successfully',
        Icons.check_circle_rounded,
        Colors.green,
      );
    } catch (e) {
      _showCustomSnackBar(
        'Failed to refresh data',
        Icons.error_rounded,
        Colors.red,
      );
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  void _viewUsersOnMap() {
    _showCustomSnackBar(
      'Opening map view...',
      Icons.map_rounded,
      Colors.blue,
    );
  }

  void _showCustomSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.signOut();
      
      // Navigate to login screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
        (route) => false,
      );
      
      _showCustomSnackBar(
        'Signed out successfully',
        Icons.logout_rounded,
        Colors.green,
      );
    } catch (e) {
      debugPrint('Error signing out: $e');
      _showCustomSnackBar(
        'Failed to sign out',
        Icons.error_rounded,
        Colors.red,
      );
    }
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              Text(
                'Sign Out',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _signOut();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      appBar: _buildAppBar(),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: RefreshIndicator(
                onRefresh: _refreshData,
                backgroundColor: Theme.of(context).colorScheme.surface,
                color: Theme.of(context).colorScheme.primary,
                displacement: 40,
                strokeWidth: 3,
                child: _buildBody(),
              ),
            ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        _selectedSystem == 0 ? 'DASHBOARD USER MANAGEMENT' : 'RADAR APP USER MANAGEMENT',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      backgroundColor: const Color(0xFF2C5282),
      elevation: 0,
      centerTitle: true,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2C5282),
              const Color(0xFF1E3A5F),
            ],
          ),
        ),
      ),
      actions: [
        _buildAppBarActions(),
      ],
    );
  }

  Widget _buildAppBarActions() {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: _isRefreshing
              ? Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.8)),
                    ),
                  ),
                )
              : Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                    onPressed: _refreshData,
                    tooltip: 'Refresh data',
                  ),
                ),
        ),
        if (_selectedSystem == 1) 
          Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
            child: IconButton(
              icon: const Icon(Icons.map_rounded, color: Colors.white, size: 20),
              onPressed: _viewUsersOnMap,
              tooltip: 'View users on map',
            ),
          ),
        // Add Sign Out button
        Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
          ),
          child: IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
            onPressed: _showSignOutDialog,
            tooltip: 'Sign out',
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isSmallScreen = constraints.maxHeight < 600;
        
        return CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSystemToggle(),
                    SizedBox(height: isSmallScreen ? 20.0 : 24.0),
                    _buildHeaderSection(isSmallScreen),
                    SizedBox(height: isSmallScreen ? 20.0 : 24.0),
                    if (_selectedSystem == 1) _buildSearchSection(),
                    SizedBox(height: isSmallScreen ? 20.0 : 24.0),
                    _buildUsersHeader(isSmallScreen),
                    SizedBox(height: isSmallScreen ? 16.0 : 20.0),
                    _buildLiveStats(), // Keep the statistics chips
                  ],
                ),
              ),
            ),
            _buildUsersList(),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        );
      },
    );
  }

  Widget _buildSystemToggle() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 400;
              
              return isNarrow 
                  ? Column(
                      children: [
                        _SystemToggleButton(
                          title: "Dashboard",
                          subtitle: "Admin Panel",
                          isSelected: _selectedSystem == 0,
                          icon: Icons.dashboard_rounded,
                          gradient: const [
                            Color(0xFF667EEA),
                            Color(0xFF764BA2),
                          ],
                          onTap: () => _onSystemChanged(0),
                          isSmall: isNarrow,
                        ),
                        _SystemToggleButton(
                          title: "Radar App",
                          subtitle: "Mobile Users",
                          isSelected: _selectedSystem == 1,
                          icon: Icons.radar_rounded,
                          gradient: const [
                            Color(0xFF11998E),
                            Color(0xFF38EF7D),
                          ],
                          onTap: () => _onSystemChanged(1),
                          isSmall: isNarrow,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _SystemToggleButton(
                            title: "Dashboard",
                            subtitle: "Admin Panel",
                            isSelected: _selectedSystem == 0,
                            icon: Icons.dashboard_rounded,
                            gradient: const [
                              Color(0xFF667EEA),
                              Color(0xFF764BA2),
                            ],
                            onTap: () => _onSystemChanged(0),
                            isSmall: isNarrow,
                          ),
                        ),
                        Expanded(
                          child: _SystemToggleButton(
                            title: "Radar App",
                            subtitle: "Mobile Users",
                            isSelected: _selectedSystem == 1,
                            icon: Icons.radar_rounded,
                            gradient: const [
                              Color(0xFF11998E),
                              Color(0xFF38EF7D),
                            ],
                            onTap: () => _onSystemChanged(1),
                            isSmall: isNarrow,
                          ),
                        ),
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(bool isSmallScreen) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
      shadowColor: Colors.black.withOpacity(0.1),
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 24 : 28),
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 400;
            
            return isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 18 : 22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _selectedSystem == 0
                                ? [const Color(0xFF667EEA).withOpacity(0.15), const Color(0xFF764BA2).withOpacity(0.08)]
                                : [const Color(0xFF11998E).withOpacity(0.15), const Color(0xFF38EF7D).withOpacity(0.08)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_selectedSystem == 0 ? const Color(0xFF667EEA) : const Color(0xFF11998E)).withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _selectedSystem == 0 ? Icons.dashboard_rounded : Icons.radar_rounded,
                          size: isSmallScreen ? 40 : 44,
                          color: _selectedSystem == 0 ? const Color(0xFF667EEA) : const Color(0xFF11998E),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 20 : 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _selectedSystem == 0
                                    ? [const Color(0xFF667EEA).withOpacity(0.1), const Color(0xFF764BA2).withOpacity(0.05)]
                                    : [const Color(0xFF11998E).withOpacity(0.1), const Color(0xFF38EF7D).withOpacity(0.05)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (_selectedSystem == 0 ? const Color(0xFF667EEA) : const Color(0xFF11998E)).withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              _systemTitle.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 16 : 18,
                                fontWeight: FontWeight.w800,
                                color: _selectedSystem == 0 ? const Color(0xFF667EEA) : const Color(0xFF11998E),
                                letterSpacing: 1.5,
                                height: 1.2,
                              ),
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          Text(
                            _systemDescription,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              fontSize: isSmallScreen ? 14 : 15,
                              height: 1.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 18 : 22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _selectedSystem == 0
                                ? [const Color(0xFF667EEA).withOpacity(0.15), const Color(0xFF764BA2).withOpacity(0.08)]
                                : [const Color(0xFF11998E).withOpacity(0.15), const Color(0xFF38EF7D).withOpacity(0.08)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_selectedSystem == 0 ? const Color(0xFF667EEA) : const Color(0xFF11998E)).withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _selectedSystem == 0 ? Icons.dashboard_rounded : Icons.radar_rounded,
                          size: isSmallScreen ? 40 : 44,
                          color: _selectedSystem == 0 ? const Color(0xFF667EEA) : const Color(0xFF11998E),
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 20 : 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _selectedSystem == 0
                                      ? [const Color(0xFF667EEA).withOpacity(0.1), const Color(0xFF764BA2).withOpacity(0.05)]
                                      : [const Color(0xFF11998E).withOpacity(0.1), const Color(0xFF38EF7D).withOpacity(0.05)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (_selectedSystem == 0 ? const Color(0xFF667EEA) : const Color(0xFF11998E)).withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                _systemTitle.toUpperCase(),
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16 : 18,
                                  fontWeight: FontWeight.w800,
                                  color: _selectedSystem == 0 ? const Color(0xFF667EEA) : const Color(0xFF11998E),
                                  letterSpacing: 1.5,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 16),
                            Text(
                              _systemDescription,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                fontSize: isSmallScreen ? 14 : 15,
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
          },
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Hero(
      tag: 'search_bar',
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(16),
        shadowColor: Colors.black.withOpacity(0.1),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search users by email, name, role, or address...',
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_rounded, 
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.clear_rounded, 
                          size: 18, 
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                        ),
                      ),
                      onPressed: _onClearSearch,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
            onChanged: _onSearchChanged,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // Updated: Removed only the counter container but keep the statistics
  Widget _buildUsersHeader(bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _selectedSystem == 0
                    ? [const Color(0xFF667EEA).withOpacity(0.15), const Color(0xFF764BA2).withOpacity(0.08)]
                    : [const Color(0xFF11998E).withOpacity(0.15), const Color(0xFF38EF7D).withOpacity(0.08)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_selectedSystem == 0 ? const Color(0xFF667EEA) : const Color(0xFF11998E)).withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              _selectedSystem == 0 ? Icons.admin_panel_settings_rounded : Icons.people_alt_rounded,
              size: isSmallScreen ? 20 : 22,
              color: _selectedSystem == 0 ? const Color(0xFF667EEA) : const Color(0xFF11998E),
            ),
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedSystem == 0 ? "DASHBOARD USERS" : "RADAR APP USERS",
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 17,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _selectedSystem == 0 ? "Administrative access management" : "Mobile user management & monitoring",
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _currentClient
          .from(_currentTable)
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _buildLoadingState(),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Stream error: ${snapshot.error}');
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _buildErrorState(snapshot.error.toString()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(),
          );
        }

        final users = snapshot.data!;
        final displayUsers = _selectedSystem == 1 ? _filterRadarUsers(users) : users;

        if (_selectedSystem == 1 && displayUsers.isEmpty && _searchQuery.isNotEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _buildNoResultsState(),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final user = displayUsers[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _selectedSystem == 0 
                      ? _DashboardUserCard(
                          key: ValueKey(user['id']),
                          userData: user,
                          onUserDeleted: _refreshData,
                          promoteToModerator: _promoteToModerator,
                          demoteToUser: _demoteToUser,
                        )
                      : _RadarAppUserCard(
                          key: ValueKey(user['id']),
                          userData: user,
                          searchQuery: _searchQuery,
                          onUserDeleted: _refreshData,
                        ),
                ),
              );
            },
            childCount: displayUsers.length,
          ),
        );
      },
    );
  }

  // KEEP the statistics chips below the users header
  Widget _buildLiveStats() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _currentClient.from(_currentTable).stream(primaryKey: ['id']),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildLoadingText();
        final users = snapshot.data!;
        final filteredUsers = _selectedSystem == 1 ? _filterRadarUsers(users) : users;
        return _buildStatsChips(users, filteredUsers);
      },
    );
  }

  Widget _buildLoadingText() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 20,
          height: 20,
          padding: const EdgeInsets.all(2),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Loading statistics...',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsChips(List<Map<String, dynamic>> allUsers, List<Map<String, dynamic>> filteredUsers) {
    final chips = _selectedSystem == 1 
        ? _buildRadarSystemChips(allUsers, filteredUsers)
        : _buildDashboardSystemChips(allUsers);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 400;
        
        return Wrap(
          spacing: isNarrow ? 10 : 12,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: chips,
        );
      },
    );
  }

  List<Widget> _buildRadarSystemChips(List<Map<String, dynamic>> allUsers, List<Map<String, dynamic>> filteredUsers) {
    final activeUsers = filteredUsers.where((user) => _isUserActive(user)).length;
    final verifiedUsers = filteredUsers.where((user) => user['is_verified'] == true).length;
    final residents = filteredUsers.where((user) => user['user_category'] == 'RESIDENT').length;
    final employees = filteredUsers.where((user) => user['user_category'] == 'EMPLOYEE').length;
    final students = filteredUsers.where((user) => user['user_category'] == 'STUDENT').length;

    return [
      _buildStatChip('${filteredUsers.length}', 'Total Users', Icons.people_alt_rounded, Colors.blue, 
          subtitle: _searchQuery.isNotEmpty ? '/${allUsers.length}' : null),
      _buildStatChip('$activeUsers', 'Active Now', Icons.online_prediction_rounded, Colors.green),
      _buildStatChip('$verifiedUsers', 'Verified', Icons.verified_rounded, Colors.purple),
      _buildStatChip('$residents', 'Residents', Icons.home_rounded, Colors.orange),
      if (employees > 0) _buildStatChip('$employees', 'Employees', Icons.work_rounded, Colors.teal),
      if (students > 0) _buildStatChip('$students', 'Students', Icons.school_rounded, Colors.indigo),
    ];
  }

  List<Widget> _buildDashboardSystemChips(List<Map<String, dynamic>> allUsers) {
    final moderatorCount = allUsers.where((user) => _isModerator(user)).length;
    final activeModerators = allUsers.where((user) => _isModerator(user) && _isUserActive(user)).length;
    final userCount = allUsers.where((user) => !_isModerator(user)).length;

    return [
      _buildStatChip('${allUsers.length}', 'Total Users', Icons.people_rounded, Colors.blue),
      _buildStatChip('$moderatorCount', 'Moderators', Icons.admin_panel_settings_rounded, Colors.purple),
      _buildStatChip('$activeModerators', 'Active Moderators', Icons.online_prediction_rounded, Colors.green),
      _buildStatChip('$userCount', 'Regular Users', Icons.person_rounded, Colors.teal),
    ];
  }

  Widget _buildStatChip(String value, String label, IconData icon, Color color, {String? subtitle}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isSmall = constraints.maxWidth < 400;
        
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 12 : 14,
            vertical: isSmall ? 8 : 10,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.12),
                color.withOpacity(0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(isSmall ? 5 : 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: isSmall ? 16 : 18, color: color),
              ),
              SizedBox(width: isSmall ? 8 : 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: isSmall ? 16 : 18,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: isSmall ? 10 : 11,
                            color: color.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isSmall ? 11 : 12,
                      color: color.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ... (Rest of the methods remain the same - loading, error, empty states)

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    Theme.of(context).colorScheme.primary.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading ${_selectedSystem == 0 ? 'dashboard' : 'radar app'} users...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we fetch the latest data',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.withOpacity(0.1),
                    Colors.red.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.error_outline_rounded, size: 40, color: Colors.red.withOpacity(0.7)),
            ),
            const SizedBox(height: 24),
            Text(
              'Connection Error',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'We encountered an issue while loading user data',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.1)),
              ),
              child: Text(
                error.length > 120 ? '${error.substring(0, 120)}...' : error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.red.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry Connection'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.surfaceContainer,
                    Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.5),
                ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.people_outline_rounded,
                size: 50,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              "No Users Found",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedSystem == 0 
                  ? "Dashboard users will appear here once they are added to the system"
                  : "Radar app users will appear here once they register and verify their accounts",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Check Again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.surfaceContainer,
                    Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.5),
                ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 50,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              "No Results Found",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'No users match your search for\n'),
                  TextSpan(
                    text: '"$_searchQuery"',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try adjusting your search terms or check for spelling errors",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _onClearSearch,
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('Clear Search'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _refreshData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterRadarUsers(List<Map<String, dynamic>> users) {
    if (_searchQuery.isEmpty) return users;
    
    final query = _searchQuery.toLowerCase();
    return users.where((user) {
      final email = user['email']?.toString().toLowerCase() ?? '';
      final firstName = user['first_name']?.toString().toLowerCase() ?? '';
      final lastName = user['last_name']?.toString().toLowerCase() ?? '';
      final middleName = user['middle_name']?.toString().toLowerCase() ?? '';
      final fullName = '$firstName $middleName $lastName'.toLowerCase().trim();
      final role = user['role']?.toString().toLowerCase() ?? '';
      final address = user['address']?.toString().toLowerCase() ?? '';
      final phone = user['phone']?.toString().toLowerCase() ?? '';
      final userCategory = user['user_category']?.toString().toLowerCase() ?? '';
      final status = user['status']?.toString().toLowerCase() ?? '';

      return email.contains(query) ||
             firstName.contains(query) ||
             lastName.contains(query) ||
             middleName.contains(query) ||
             fullName.contains(query) ||
             role.contains(query) ||
             address.contains(query) ||
             phone.contains(query) ||
             userCategory.contains(query) ||
             status.contains(query);
    }).toList();
  }

  bool _isUserActive(Map<String, dynamic> user) {
    final lastActive = user['last_active'];
    if (lastActive != null) {
      final lastActiveTime = DateTime.tryParse(lastActive.toString());
      if (lastActiveTime != null) {
        final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
        return lastActiveTime.isAfter(twentyFourHoursAgo);
      }
    }
    
    final updatedAt = user['updated_at'];
    if (updatedAt != null) {
      final updatedTime = DateTime.tryParse(updatedAt.toString());
      if (updatedTime != null) {
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        return updatedTime.isAfter(sevenDaysAgo);
      }
    }
    
    return false;
  }

  bool _isModerator(Map<String, dynamic> user) {
    return user['role'] == 'moderator';
  }

  Color _getBackgroundColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : const Color(0xFFF8FAFC);
  }

  void _navigateBackToMain() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => NavigationScreen(
        isDarkMode: false,
        onToggleTheme: (bool value) { 
          // Add your theme toggle logic here or pass it down
        },
        userRole: 'admin',
      )),
      (route) => false,
    );
  }
}

class _SystemToggleButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
  final bool isSmall;

  const _SystemToggleButton({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: gradient.first.withOpacity(0.1),
        highlightColor: gradient.first.withOpacity(0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutQuart,
          padding: EdgeInsets.all(isSmall ? 18 : 22),
          decoration: BoxDecoration(
            gradient: isSelected 
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  )
                : null,
            color: isSelected ? null : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected ? [
              BoxShadow(
                color: gradient.first.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 1,
              )
            ] : [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isSmall ? 10 : 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.2) : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon, 
                  color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.6), 
                  size: isSmall ? 22 : 26
                ),
              ),
              SizedBox(height: isSmall ? 10 : 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: isSmall ? 14 : 16,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isSmall ? 4 : 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: isSmall ? 10 : 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white.withOpacity(0.8) : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ... (Keep all your existing _DashboardUserCard, _RadarAppUserCard, _UserData, _DetailRow classes)
// They remain exactly the same as in your original code

class _DashboardUserCard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback? onUserDeleted;
  final Future<bool> Function(String) promoteToModerator;
  final Future<bool> Function(String) demoteToUser;

  const _DashboardUserCard({
    super.key,
    required this.userData,
    this.onUserDeleted,
    required this.promoteToModerator,
    required this.demoteToUser,
  });

  @override
  State<_DashboardUserCard> createState() => __DashboardUserCardState();
}

class __DashboardUserCardState extends State<_DashboardUserCard> {
  bool _updating = false;

  Future<void> _updateUserRole(String? newRole) async {
    if (newRole == null || newRole == widget.userData['role']) return;

    setState(() => _updating = true);
    
    try {
      bool success;
      if (newRole == 'moderator') {
        success = await widget.promoteToModerator(widget.userData['id']);
      } else {
        success = await widget.demoteToUser(widget.userData['id']);
      }

      if (success) {
        _showSuccessSnackbar('User role updated to $newRole');
        widget.onUserDeleted?.call();
      } else {
        _showErrorSnackbar('Failed to update role. Please try again.');
      }
    } catch (e) {
      _showErrorSnackbar('Failed to update role: $e');
    } finally {
      setState(() => _updating = false);
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _deleteUserAccount() async {
    await UserManagementService.deleteUserAccount(
      context: context,
      userId: widget.userData['id'],
      userEmail: widget.userData['email'] ?? 'Unknown User',
      onSuccess: () {
        widget.onUserDeleted?.call();
      },
    );
  }

  void _viewUserDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dashboard User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow(title: 'Email:', value: widget.userData['email'] ?? 'N/A'),
              _DetailRow(title: 'User ID:', value: widget.userData['id'] ?? 'N/A'),
              _DetailRow(title: 'Role:', value: widget.userData['role'] ?? 'user'),
              _DetailRow(
                title: 'Created:', 
                value: _formatTimestamp(widget.userData['created_at'])
              ),
              _DetailRow(
                title: 'Last Login:', 
                value: _formatTimestamp(widget.userData['last_login'])
              ),
              _DetailRow(
                title: 'Status:', 
                value: _getOnlineStatusText(widget.userData['last_login'])
              ),
              if (widget.userData['name'] != null) 
                _DetailRow(title: 'Name:', value: widget.userData['name']),
              if (widget.userData['department'] != null) 
                _DetailRow(title: 'Department:', value: widget.userData['department']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: _deleteUserAccount,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Never';
    
    if (timestamp is String) {
      final dateTime = DateTime.tryParse(timestamp);
      return dateTime != null ? DateFormat('MMM d, y - h:mm a').format(dateTime) : 'Invalid date';
    } else if (timestamp is DateTime) {
      return DateFormat('MMM d, y - h:mm a').format(timestamp);
    }
    
    return 'Never';
  }

  bool _isUserOnline(dynamic lastLogin) {
    if (lastLogin == null) return false;
    
    DateTime lastLoginTime;
    
    if (lastLogin is String) {
      final parsed = DateTime.tryParse(lastLogin);
      if (parsed == null) return false;
      lastLoginTime = parsed;
    } else if (lastLogin is DateTime) {
      lastLoginTime = lastLogin;
    } else {
      return false;
    }
    
    final timeThreshold = const Duration(minutes: 5);
    final thresholdTime = DateTime.now().subtract(timeThreshold);
    
    return lastLoginTime.isAfter(thresholdTime);
  }

  String _getOnlineStatusText(dynamic lastLogin) {
    return _isUserOnline(lastLogin) ? 'Online' : 'Offline';
  }

  Color _getOnlineStatusColor(dynamic lastLogin) {
    return _isUserOnline(lastLogin) ? Colors.green : Colors.grey;
  }

  String _getTimeSinceLastActivity(dynamic lastLogin) {
    if (lastLogin == null) return 'Never active';
    
    DateTime lastActivity;
    
    if (lastLogin is String) {
      final parsed = DateTime.tryParse(lastLogin);
      if (parsed == null) return 'Never active';
      lastActivity = parsed;
    } else if (lastLogin is DateTime) {
      lastActivity = lastLogin;
    } else {
      return 'Never active';
    }
    
    final now = DateTime.now();
    final difference = now.difference(lastActivity);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'moderator':
        return Colors.purple;
      case 'user':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'moderator':
        return Icons.admin_panel_settings;
      case 'user':
        return Icons.person;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = _getUserData();
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatusIndicator(userData.isOnline, userData.onlineStatusColor),
              const SizedBox(width: 8),
              _buildRoleIcon(userData.role, userData.roleColor),
              const SizedBox(width: 12),
              _buildUserInfo(userData),
              _buildActions(userData.role, userData.roleColor),
            ],
          ),
          const SizedBox(height: 8),
          _buildRoleBadge(userData.role, userData.roleColor),
        ],
      ),
    );
  }

  _UserData _getUserData() {
    final email = widget.userData['email'] ?? 'No email';
    final role = widget.userData['role'] ?? 'user';
    final createdAt = widget.userData['created_at'];
    final lastLogin = widget.userData['last_login'];
    final name = widget.userData['name'] ?? '';
    final department = widget.userData['department'] ?? '';
    final isOnline = _isUserOnline(lastLogin);
    final onlineStatusColor = _getOnlineStatusColor(lastLogin);
    final onlineStatusText = _getOnlineStatusText(lastLogin);
    final timeSinceActivity = _getTimeSinceLastActivity(lastLogin);
    final roleColor = _getRoleColor(role);

    return _UserData(
      email: email,
      role: role,
      createdAt: createdAt,
      lastLogin: lastLogin,
      name: name,
      department: department,
      isOnline: isOnline,
      onlineStatusColor: onlineStatusColor,
      onlineStatusText: onlineStatusText,
      timeSinceActivity: timeSinceActivity,
      roleColor: roleColor,
    );
  }

  Widget _buildStatusIndicator(bool isOnline, Color statusColor) {
    return Tooltip(
      message: isOnline ? 'Online' : 'Offline',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: statusColor,
          shape: BoxShape.circle,
          boxShadow: [
            if (isOnline)
              BoxShadow(
                color: statusColor.withOpacity(0.5),
                blurRadius: 4,
                spreadRadius: 2,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleIcon(String role, Color roleColor) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: roleColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _getRoleIcon(role),
        size: 18,
        color: roleColor,
      ),
    );
  }

  Widget _buildUserInfo(_UserData userData) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            userData.email,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (userData.name.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              userData.name,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (userData.department.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              userData.department,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Created: ${_formatTimestamp(userData.createdAt)}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          if (userData.lastLogin != null) ...[
            const SizedBox(height: 2),
            Text(
              'Last login: ${_formatTimestamp(userData.lastLogin)}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: userData.onlineStatusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                userData.onlineStatusText,
                style: TextStyle(
                  fontSize: 11,
                  color: userData.onlineStatusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '• ${userData.timeSinceActivity}',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions(String role, Color roleColor) {
    if (_updating) {
      return const SizedBox(
        width: 20, 
        height: 20, 
        child: CircularProgressIndicator(strokeWidth: 2)
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRoleDropdown(role, roleColor),
        const SizedBox(width: 8),
        _buildDeleteButton(),
        const SizedBox(width: 4),
        _buildInfoButton(),
      ],
    );
  }

  Widget _buildRoleDropdown(String role, Color roleColor) {
    final validRole = role == 'admin' ? 'user' : role;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: roleColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: roleColor.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validRole,
          icon: const Icon(Icons.arrow_drop_down, size: 16),
          dropdownColor: Theme.of(context).colorScheme.surface,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: roleColor,
          ),
          onChanged: _updateUserRole,
          items: const [
            DropdownMenuItem(value: 'user', child: Text('USER')),
            DropdownMenuItem(value: 'moderator', child: Text('MODERATOR')),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return IconButton(
      icon: const Icon(Icons.delete_outline, size: 18),
      onPressed: _deleteUserAccount,
      tooltip: 'Delete user',
      color: Colors.red,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildInfoButton() {
    return IconButton(
      icon: const Icon(Icons.info_outline, size: 18),
      onPressed: () => _viewUserDetails(context),
      tooltip: 'View details',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildRoleBadge(String role, Color roleColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: roleColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: roleColor.withOpacity(0.3)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: roleColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _RadarAppUserCard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String searchQuery;
  final VoidCallback? onUserDeleted;

  const _RadarAppUserCard({
    super.key,
    required this.userData,
    this.searchQuery = '',
    this.onUserDeleted,
  });

  @override
  State<_RadarAppUserCard> createState() => __RadarAppUserCardState();
}

class __RadarAppUserCardState extends State<_RadarAppUserCard> {
  int _incidentCount = 0;
  bool _loadingIncidents = false;
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadIncidentCount();
  }

  Future<void> _loadIncidentCount() async {
    setState(() => _loadingIncidents = true);
    try {
      final userId = widget.userData['id'];
      if (userId != null) {
        final incidentsResponse = await _supabase
            .from('incidents')
            .select()
            .eq('user_id', userId);
        
        setState(() => _incidentCount = incidentsResponse.length);
      }
    } catch (e) {
      debugPrint('Error loading incidents: $e');
    } finally {
      setState(() => _loadingIncidents = false);
    }
  }

  Future<void> _deleteUserAccount() async {
    await UserManagementService.deleteUserAccount(
      context: context,
      userId: widget.userData['id'],
      userEmail: widget.userData['email'] ?? 'Unknown User',
      onSuccess: () {
        widget.onUserDeleted?.call();
      },
    );
  }

  void _viewUserDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow(title: 'Email:', value: widget.userData['email'] ?? 'N/A'),
              _DetailRow(title: 'User ID:', value: widget.userData['id'] ?? 'N/A'),
              _DetailRow(title: 'First Name:', value: widget.userData['first_name'] ?? 'N/A'),
              _DetailRow(title: 'Last Name:', value: widget.userData['last_name'] ?? 'N/A'),
              _DetailRow(title: 'Middle Name:', value: widget.userData['middle_name'] ?? 'N/A'),
              _DetailRow(title: 'Phone:', value: widget.userData['phone'] ?? 'N/A'),
              _DetailRow(title: 'Role:', value: widget.userData['role'] ?? 'user'),
              _DetailRow(title: 'Status:', value: widget.userData['status'] ?? 'active'),
              _DetailRow(title: 'User Category:', value: widget.userData['user_category'] ?? 'N/A'),
              _DetailRow(title: 'Date of Birth:', value: widget.userData['dob'] ?? 'N/A'),
              _DetailRow(title: 'Blood Type:', value: widget.userData['blood_type'] ?? 'N/A'),
              _DetailRow(title: 'Height:', value: widget.userData['height'] ?? 'N/A'),
              _DetailRow(title: 'Weight:', value: widget.userData['weight'] ?? 'N/A'),
              _DetailRow(
                title: 'Created:', 
                value: _formatTimestamp(widget.userData['created_at'])
              ),
              _DetailRow(
                title: 'Updated:', 
                value: _formatTimestamp(widget.userData['updated_at'])
              ),
              _DetailRow(title: 'Verified:', value: widget.userData['is_verified'] == true ? 'Yes' : 'No'),
              _DetailRow(title: 'Incidents Reported:', value: '$_incidentCount'),
              if (widget.userData['address'] != null) 
                _DetailRow(title: 'Address:', value: '${widget.userData['address']}'),
              if (widget.userData['resident_address'] != null) 
                _DetailRow(title: 'Resident Address:', value: '${widget.userData['resident_address']}'),
              if (widget.userData['work_address'] != null) 
                _DetailRow(title: 'Work Address:', value: '${widget.userData['work_address']}'),
              if (widget.userData['home_address'] != null) 
                _DetailRow(title: 'Home Address:', value: '${widget.userData['home_address']}'),
              if (widget.userData['school_address'] != null) 
                _DetailRow(title: 'School Address:', value: '${widget.userData['school_address']}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => _viewUserIncidents(context),
            child: const Text('View Incidents'),
          ),
          TextButton(
            onPressed: _deleteUserAccount,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  void _viewUserIncidents(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminIncidentReportScreen(
          userId: widget.userData['id'],
          userEmail: widget.userData['email'] ?? 'Unknown User',
          userName: '${widget.userData['first_name'] ?? ''} ${widget.userData['last_name'] ?? ''}'.trim(),
          userAddress: widget.userData['address'] ?? 'No address provided',
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Never';
    
    if (timestamp is String) {
      final dateTime = DateTime.tryParse(timestamp);
      return dateTime != null ? DateFormat('MMM d, y - h:mm a').format(dateTime) : 'Invalid date';
    } else if (timestamp is DateTime) {
      return DateFormat('MMM d, y - h:mm a').format(timestamp);
    }
    
    return 'Never';
  }

  String _getFullName() {
    final firstName = widget.userData['first_name'] ?? '';
    final middleName = widget.userData['middle_name'] ?? '';
    final lastName = widget.userData['last_name'] ?? '';
    
    if (firstName.isEmpty && lastName.isEmpty) return 'No Name';
    
    if (middleName.isNotEmpty) {
      return '$firstName $middleName $lastName';
    } else {
      return '$firstName $lastName';
    }
  }

  Color _getStatusColor() {
    final status = widget.userData['status'] ?? 'active';
    switch (status) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.grey;
      case 'suspended':
        return Colors.orange;
      case 'banned':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getCategoryColor() {
    final category = widget.userData['user_category'] ?? 'RESIDENT';
    switch (category) {
      case 'RESIDENT':
        return Colors.blue;
      case 'EMPLOYEE':
        return Colors.green;
      case 'STUDENT':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = _getFullName();
    final statusColor = _getStatusColor();
    final categoryColor = _getCategoryColor();
    final userCategory = widget.userData['user_category'] ?? 'RESIDENT';
    final status = widget.userData['status'] ?? 'active';
    final isVerified = widget.userData['is_verified'] == true;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Status indicator
              Tooltip(
                message: 'User Status',
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Category icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: categoryColor.withAlpha(51),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getCategoryIcon(userCategory),
                  size: 20,
                  color: categoryColor,
                ),
              ),
              const SizedBox(width: 12),

              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.userData['email'] ?? 'No email',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified)
                          const Icon(Icons.verified, size: 16, color: Colors.blue),
                      ],
                    ),
                    if (fullName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        fullName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      'Created: ${_formatTimestamp(widget.userData['created_at'])}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    if (widget.userData['updated_at'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Last updated: ${_formatTimestamp(widget.userData['updated_at'])}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      'Category: $userCategory • Status: ${status.toUpperCase()} • Incidents: ${_loadingIncidents ? '...' : _incidentCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Status: ${_getStatusText(statusColor)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${_getTimeSinceLastActivity(widget.userData['updated_at'])}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isVerified)
                    Tooltip(
                      message: 'Verified User',
                      child: const Icon(Icons.verified, size: 18, color: Colors.blue),
                    ),
                  IconButton(
                    icon: const Icon(Icons.list_alt, size: 18),
                    onPressed: () => _viewUserIncidents(context),
                    tooltip: 'View incidents',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: _deleteUserAccount,
                    tooltip: 'Delete user',
                    color: Colors.red,
                  ),
                  IconButton(
                    icon: const Icon(Icons.info, size: 18),
                    onPressed: () => _viewUserDetails(context),
                    tooltip: 'View details',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String userCategory) {
    switch (userCategory) {
      case 'RESIDENT':
        return Icons.home;
      case 'EMPLOYEE':
        return Icons.work;
      case 'STUDENT':
        return Icons.school;
      default:
        return Icons.person;
    }
  }

  String _getStatusText(Color statusColor) {
    if (statusColor == Colors.green) return 'Active';
    if (statusColor == Colors.grey) return 'Inactive';
    if (statusColor == Colors.orange) return 'Suspended';
    if (statusColor == Colors.red) return 'Banned';
    return 'Unknown';
  }

  String _getTimeSinceLastActivity(dynamic lastLogin) {
    if (lastLogin == null) return 'Never active';
    
    DateTime lastActivity;
    
    if (lastLogin is String) {
      final parsed = DateTime.tryParse(lastLogin);
      if (parsed == null) return 'Never active';
      lastActivity = parsed;
    } else if (lastLogin is DateTime) {
      lastActivity = lastLogin;
    } else {
      return 'Never active';
    }
    
    final now = DateTime.now();
    final difference = now.difference(lastActivity);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}

class _UserData {
  final String email;
  final String role;
  final dynamic createdAt;
  final dynamic lastLogin;
  final String name;
  final String department;
  final bool isOnline;
  final Color onlineStatusColor;
  final String onlineStatusText;
  final String timeSinceActivity;
  final Color roleColor;

  _UserData({
    required this.email,
    required this.role,
    required this.createdAt,
    required this.lastLogin,
    required this.name,
    required this.department,
    required this.isOnline,
    required this.onlineStatusColor,
    required this.onlineStatusText,
    required this.timeSinceActivity,
    required this.roleColor,
  });
}

class _DetailRow extends StatelessWidget {
  final String title;
  final String value;

  const _DetailRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}