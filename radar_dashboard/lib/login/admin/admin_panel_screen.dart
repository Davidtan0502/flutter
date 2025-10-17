import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:radar_dashboard/login/admin/mobile_user_card.dart';
import 'package:radar_dashboard/login/admin/dashboard_user_card.dart';
import 'package:radar_dashboard/login/admin/users_search_bar.dart';
import 'package:radar_dashboard/login/admin/users_statistics.dart';
import 'package:radar_dashboard/login/admin/system_toggle.dart';
import 'package:radar_dashboard/navigation/main_navigation.dart';

class AdminPanelScreen extends StatefulWidget {
  final int initialSystem;
  const AdminPanelScreen({super.key, this.initialSystem = 0});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  late int _selectedSystem;
  String _searchQuery = '';
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _selectedSystem = widget.initialSystem;
  }

  // Getters for system configuration
  String get _currentTable => _selectedSystem == 0 ? 'dashboard_users' : 'users';
  String get _systemTitle => _selectedSystem == 0 ? 'Dashboard System' : 'Radar App System';
  String get _systemDescription => _selectedSystem == 0 
      ? 'Manage dashboard user roles and permissions' 
      : 'Manage mobile app users and emergency data';

  void _onSystemChanged(int system) {
    setState(() {
      _selectedSystem = system;
      _searchQuery = '';
    });
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
  }

  void _onClearSearch() {
    setState(() => _searchQuery = '');
  }

  void _viewUsersOnMap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening map view...'),
        backgroundColor: Color(0xFF2C5282),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => _navigateBackToMain(),
      ),
      title: Text(
        _selectedSystem == 0 ? 'DASHBOARD USER MANAGEMENT' : 'RADAR APP USER MANAGEMENT',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: const Color(0xFF2C5282),
      elevation: 4,
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: () => setState(() {}),
          tooltip: 'Refresh data',
        ),
        if (_selectedSystem == 1) 
          IconButton(
            icon: const Icon(Icons.map, color: Colors.white),
            onPressed: _viewUsersOnMap,
            tooltip: 'View users on map',
          ),
      ],
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: _buildBackgroundGradient(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SystemToggle(
              selectedSystem: _selectedSystem,
              onSystemChanged: _onSystemChanged,
            ),
            const SizedBox(height: 24),
            _buildHeaderSection(),
            const SizedBox(height: 32),
            _buildStatisticsSection(),
            const SizedBox(height: 32),
            if (_selectedSystem == 1) ..._buildSearchSection(),
            _buildUsersListSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  BoxDecoration _buildBackgroundGradient() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Theme.of(context).colorScheme.surfaceContainerHighest,
          Theme.of(context).colorScheme.surfaceContainer,
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: _buildCardDecoration(),
      child: Row(
        children: [
          _buildHeaderIcon(),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _systemTitle.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C5282),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _systemDescription,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                _buildLiveStats(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _buildCardDecoration() {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 15,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Widget _buildHeaderIcon() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2C5282).withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _selectedSystem == 0 ? Icons.dashboard : Icons.radar,
        size: 40,
        color: const Color(0xFF2C5282),
      ),
    );
  }

  Widget _buildLiveStats() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from(_currentTable)
          .stream(primaryKey: ['id']),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildLoadingText();
        final users = snapshot.data!;
        final filteredUsers = _selectedSystem == 1 ? _filterRadarUsers(users) : users;
        return _buildStatsChips(users, filteredUsers);
      },
    );
  }

  Widget _buildLoadingText() {
    return Text(
      'Loading statistics...',
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildStatsChips(List<Map<String, dynamic>> allUsers, List<Map<String, dynamic>> filteredUsers) {
    final chips = _selectedSystem == 1 
        ? _buildRadarSystemChips(allUsers, filteredUsers)
        : _buildDashboardSystemChips(allUsers);
    
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: chips,
    );
  }

  List<Widget> _buildRadarSystemChips(List<Map<String, dynamic>> allUsers, List<Map<String, dynamic>> filteredUsers) {
    final activeUsers = filteredUsers.where((user) => _isUserActive(user)).length;
    final emergencyReports = _calculateEmergencyReports(filteredUsers);

    return [
      _buildStatChip('Users: ${filteredUsers.length}', Colors.blue),
      _buildStatChip('Active: $activeUsers', Colors.green),
      _buildStatChip('Emergencies: $emergencyReports', Colors.orange),
      if (_searchQuery.isNotEmpty) _buildStatChip('Filtered', Colors.purple),
    ];
  }

  List<Widget> _buildDashboardSystemChips(List<Map<String, dynamic>> allUsers) {
    final adminCount = allUsers.where((user) => _isAdmin(user)).length;

    return [
      _buildStatChip('Total Users: ${allUsers.length}', Colors.blue),
      _buildStatChip('Admins: $adminCount', Colors.purple),
      _buildStatChip('Users: ${allUsers.length - adminCount}', Colors.green),
    ];
  }

  Widget _buildStatChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Container(
      height: 150,
      child: UsersStatisticsSection(
        collection: _currentTable, // Keep using 'collection' parameter name for compatibility
        systemType: _selectedSystem,
        searchQuery: _searchQuery,
      ),
    );
  }

  List<Widget> _buildSearchSection() {
    return [
      Container(
        height: 60,
        child: UsersSearchBar(
          searchQuery: _searchQuery,
          onSearchChanged: _onSearchChanged,
          onClearSearch: _onClearSearch,
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _buildUsersListSection() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      child: _buildUsersList(),
    );
  }

// In your AdminPanelScreen, update the stream to handle service role
Widget _buildUsersList() {
  return StreamBuilder<List<Map<String, dynamic>>>(
    stream: _supabase
        .from(_currentTable)
        .stream(primaryKey: ['id'])
        .order(_selectedSystem == 0 ? 'email' : 'created_at', ascending: false),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _buildLoadingState();
      }

      if (snapshot.hasError) {
        // Handle RLS policy errors gracefully
        if (snapshot.error.toString().contains('row-level security')) {
          return _buildRLSErrorState();
        }
        return _buildErrorState(snapshot.error.toString());
      }

      if (!snapshot.hasData || snapshot.data!.isEmpty) {
        return _buildEmptyState();
      }

      final users = snapshot.data!;
      final displayUsers = _selectedSystem == 1 ? _filterRadarUsers(users) : users;

      if (_selectedSystem == 1 && displayUsers.isEmpty && _searchQuery.isNotEmpty) {
        return _buildNoResultsState();
      }

      return _buildUsersCard(displayUsers, users.length);
    },
  );
}

// Add RLS error state
Widget _buildRLSErrorState() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.security, size: 80, color: Colors.orange),
        const SizedBox(height: 20),
        const Text(
          'Security Policy Restriction',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Unable to load all users due to security policies. '
            'Only users you have permission to view are shown.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => setState(() {}),
          child: const Text('Retry'),
        ),
      ],
    ),
  );
}
  Widget _buildUsersCard(List<Map<String, dynamic>> displayUsers, int totalUsers) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surfaceContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: BoxConstraints(
            minHeight: 200,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUsersHeader(displayUsers.length, totalUsers),
              _buildUsersListContent(displayUsers),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsersHeader(int displayCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow.withOpacity(0.7),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2C5282).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _selectedSystem == 0 ? Icons.dashboard : Icons.people_alt,
              size: 20,
              color: const Color(0xFF2C5282),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _selectedSystem == 0 ? "DASHBOARD USERS" : "RADAR APP USERS",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: 1.1,
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C5282).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2C5282).withOpacity(0.2),
                  ),
                ),
                child: Text(
                  '$displayCount ${displayCount == 1 ? 'user' : 'users'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C5282),
                  ),
                ),
              ),
              if (_selectedSystem == 1 && _searchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '$totalCount total',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersListContent(List<Map<String, dynamic>> displayUsers) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface.withOpacity(0.5),
              Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.3),
            ],
          ),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.all(12.0),
          itemCount: displayUsers.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8.0),
          itemBuilder: (context, index) {
            final user = displayUsers[index];
            
            return Container(
              padding: const EdgeInsets.all(4.0),
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _selectedSystem == 0 
                  ? DashboardUserCard(
                      userData: user, // Pass the user data directly
                      onUserDeleted: () {
                        setState(() {});
                      },
                    )
                  : RadarAppUserCard(
                      userData: user, // Pass the user data directly
                      searchQuery: _searchQuery,
                      onUserDeleted: () {
                        setState(() {});
                      },
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(strokeWidth: 3),
          const SizedBox(height: 20),
          Text(
            'Loading ${_selectedSystem == 0 ? 'dashboard' : 'radar app'} users...',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.red),
          const SizedBox(height: 20),
          const Text(
            'Failed to load users',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Try Again', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text(
            "No ${_selectedSystem == 0 ? 'dashboard' : 'radar app'} users found",
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Users will appear here once they register",
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text(
            "No users found for \"$_searchQuery\"",
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Try adjusting your search terms",
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _onClearSearch,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Clear Search', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // Helper methods
  List<Map<String, dynamic>> _filterRadarUsers(List<Map<String, dynamic>> users) {
    if (_searchQuery.isEmpty) return users;
    
    final query = _searchQuery.toLowerCase();
    return users.where((user) {
      final email = user['email']?.toString().toLowerCase() ?? '';
      final name = user['name']?.toString().toLowerCase() ?? '';
      final role = user['role']?.toString().toLowerCase() ?? '';
      final address = user['address']?.toString().toLowerCase() ?? '';

      return email.contains(query) ||
             name.contains(query) ||
             role.contains(query) ||
             address.contains(query);
    }).toList();
  }

  bool _isUserActive(Map<String, dynamic> user) {
    final lastActive = user['last_active'];
    if (lastActive == null) return false;
    
    final lastActiveTime = DateTime.tryParse(lastActive.toString());
    if (lastActiveTime == null) return false;
    
    final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
    return lastActiveTime.isAfter(twentyFourHoursAgo);
  }

  int _calculateEmergencyReports(List<Map<String, dynamic>> users) {
    return users.fold<int>(0, (total, user) {
      final reports = user['emergency_reports'];
      return total + (reports is int ? reports : 0);
    });
  }

  bool _isAdmin(Map<String, dynamic> user) {
    return user['role'] == 'admin';
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