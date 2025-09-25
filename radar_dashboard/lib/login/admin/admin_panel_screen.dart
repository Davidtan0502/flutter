import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:radar_dashboard/dashboard/dashboard_screen.dart';
import 'package:radar_dashboard/login/admin/mobile_user_card.dart';
import 'package:radar_dashboard/login/admin/dashboard_user_card.dart';
import 'package:radar_dashboard/login/admin/users_search_bar.dart';
import 'package:radar_dashboard/login/admin/users_statistics.dart';
import 'package:radar_dashboard/login/admin/system_toggle.dart';
import 'package:radar_dashboard/navigation/main_navigation.dart';

class AdminPanelScreen extends StatefulWidget {
  final int initialSystem; // 0 = Dashboard, 1 = Radar
  const AdminPanelScreen({super.key, this.initialSystem = 0});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  late int _selectedSystem;
  String _searchQuery = '';

  String get _currentCollection => _selectedSystem == 0 ? 'dashboard_users' : 'users';
  String get _systemTitle => _selectedSystem == 0 ? 'Dashboard System' : 'Radar App System';
  String get _systemDescription => _selectedSystem == 0 
      ? 'Manage dashboard user roles and permissions' 
      : 'Manage mobile app users and emergency data';

  @override
  void initState() {
    super.initState();
    _selectedSystem = widget.initialSystem; // set from constructor
  }

  void _onSystemChanged(int system) {
    setState(() {
      _selectedSystem = system;
      _searchQuery = ''; // Clear search when switching systems
    });
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
  }

  void _onClearSearch() {
    setState(() => _searchQuery = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      appBar: _buildAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surfaceContainerHighest,
              Theme.of(context).colorScheme.surfaceContainer,
            ],
          ),
        ),
        child: SingleChildScrollView( // Wrap entire content in SingleChildScrollView
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // System Selection Toggle
              SystemToggle(
                selectedSystem: _selectedSystem,
                onSystemChanged: _onSystemChanged,
              ),
              const SizedBox(height: 24), // Increased spacing
              
              // Header Section - Made larger
              _buildHeaderSection(),
              const SizedBox(height: 32), // Increased spacing
              
              // Statistics Cards - Made larger
              Container(
                height: 150, // Increased height
                child: UsersStatisticsSection(
                  collection: _currentCollection,
                  systemType: _selectedSystem,
                  searchQuery: _searchQuery,
                ),
              ),
              const SizedBox(height: 32), // Increased spacing
              
              // Search Bar (only for Radar App System)
              if (_selectedSystem == 1) 
                Container(
                  height: 60, // Increased height
                  child: UsersSearchBar(
                    searchQuery: _searchQuery,
                    onSearchChanged: _onSearchChanged,
                    onClearSearch: _onClearSearch,
                  ),
                ),
              if (_selectedSystem == 1) const SizedBox(height: 24), // Increased spacing
              
              // Users List - Made larger with expanded height
              Container(
                height: MediaQuery.of(context).size.height * 0.7, // Increased height
                child: _buildUsersList(),
              ),
              const SizedBox(height: 20), // Extra padding at bottom
            ],
          ),
        ),
      ),
    );
  }

AppBar _buildAppBar() {
  return AppBar(
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () {
        // Navigate back to NavigationScreen which contains the main nav
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => NavigationScreen(
            isDarkMode: false, // You'll need to get these values properly
            onToggleTheme: (bool value) { 
              // Add your theme toggle logic here or pass it down
            },
            userRole: 'admin', // You'll need to get the actual user role
          )),
          (route) => false,
        );
      },
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

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(24), // Increased padding
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20), // Larger border radius
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15), // Stronger shadow
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(20), // Increased padding
            decoration: BoxDecoration(
              color: const Color(0xFF2C5282).withOpacity(0.15), // More opaque
              shape: BoxShape.circle,
            ),
            child: Icon(
              _selectedSystem == 0 ? Icons.dashboard : Icons.radar,
              size: 40, // Larger icon
              color: const Color(0xFF2C5282),
            ),
          ),
          const SizedBox(width: 20), // Increased spacing
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _systemTitle.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24, // Larger font
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C5282),
                    letterSpacing: 1.2, // More letter spacing
                  ),
                ),
                const SizedBox(height: 8), // Increased spacing
                Text(
                  _systemDescription,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 16, // Larger font
                  ),
                ),
                const SizedBox(height: 12), // Increased spacing
                _buildLiveStats(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(_currentCollection).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildLoadingText();
        }

        final users = snapshot.data!.docs;
        final filteredUsers = _selectedSystem == 1 ? _filterRadarUsers(users) : users;
        
        return _buildStatsChips(users, filteredUsers);
      },
    );
  }

  Widget _buildLoadingText() {
    return Text(
      'Loading statistics...',
      style: TextStyle(
        fontSize: 14, // Larger font
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildStatsChips(List<QueryDocumentSnapshot> allUsers, List<QueryDocumentSnapshot> filteredUsers) {
    if (_selectedSystem == 1) {
      final activeUsers = filteredUsers.where((user) => _isUserActive(user)).length;
      final emergencyReports = _calculateEmergencyReports(filteredUsers);

      return Wrap(
        spacing: 12, // Increased spacing
        runSpacing: 8, // Increased spacing
        children: [
          _buildStatChip('Users: ${filteredUsers.length}', Colors.blue),
          _buildStatChip('Active: $activeUsers', Colors.green),
          _buildStatChip('Emergencies: $emergencyReports', Colors.orange),
          if (_searchQuery.isNotEmpty) 
            _buildStatChip('Filtered', Colors.purple),
        ],
      );
    } else {
      final adminCount = allUsers.where((user) => _isAdmin(user)).length;

      return Wrap(
        spacing: 12, // Increased spacing
        runSpacing: 8, // Increased spacing
        children: [
          _buildStatChip('Total Users: ${allUsers.length}', Colors.blue),
          _buildStatChip('Admins: $adminCount', Colors.purple),
          _buildStatChip('Users: ${allUsers.length - adminCount}', Colors.green),
        ],
      );
    }
  }

  Widget _buildStatChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Increased padding
      decoration: BoxDecoration(
        color: color.withOpacity(0.15), // More opaque
        borderRadius: BorderRadius.circular(16), // Larger border radius
        border: Border.all(color: color.withOpacity(0.4)), // Thicker border
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14, // Larger font
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

Widget _buildUsersList() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection(_currentCollection)
        .orderBy(_selectedSystem == 0 ? 'email' : 'createdAt', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _buildLoadingState();
      }

      if (snapshot.hasError) {
        return _buildErrorState(snapshot.error.toString());
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return _buildEmptyState();
      }

      final users = snapshot.data!.docs;
      final displayUsers = _selectedSystem == 1 ? _filterRadarUsers(users) : users;

      if (_selectedSystem == 1 && displayUsers.isEmpty && _searchQuery.isNotEmpty) {
        return _buildNoResultsState();
      }

      return _buildUsersCard(displayUsers, users.length);
    },
  );
}

Widget _buildUsersCard(List<QueryDocumentSnapshot> displayUsers, int totalUsers) {
  return Card(
    elevation: 6,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Container(
      constraints: BoxConstraints(
        minHeight: 200, // Minimum height to prevent being too small
        maxHeight: MediaQuery.of(context).size.height * 0.7, // Maximum height
      ),
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUsersHeader(displayUsers.length, totalUsers),
          const SizedBox(height: 20),
          Expanded( // This will take remaining space but respect maxHeight constraint
            child: ListView.separated(
              itemCount: displayUsers.length,
              separatorBuilder: (context, index) => const Divider(height: 16, thickness: 1),
              itemBuilder: (context, index) {
                final user = displayUsers[index];
                final data = user.data() as Map<String, dynamic>;
                
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: _selectedSystem == 0 
                      ? DashboardUserCard(user: user, data: data)
                      : RadarAppUserCard(
                          user: user, 
                          data: data,
                          searchQuery: _searchQuery,
                        ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildUsersHeader(int displayCount, int totalCount) {
    return Row(
      children: [
        Text(
          _selectedSystem == 0 ? "DASHBOARD USERS" : "RADAR APP USERS",
          style: const TextStyle(
            fontSize: 18, // Larger font
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C5282),
            letterSpacing: 1.2, // More letter spacing
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$displayCount users',
              style: TextStyle(
                fontSize: 16, // Larger font
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_selectedSystem == 1 && _searchQuery.isNotEmpty)
              Text(
                '$totalCount total',
                style: const TextStyle(
                  fontSize: 14, // Larger font
                  color: Colors.grey,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(strokeWidth: 3), // Thicker stroke
          const SizedBox(height: 20), // Increased spacing
          Text(
            'Loading ${_selectedSystem == 0 ? 'dashboard' : 'radar app'} users...',
            style: TextStyle(
              fontSize: 18, // Larger font
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
          const Icon(Icons.error_outline, size: 80, color: Colors.red), // Larger icon
          const SizedBox(height: 20), // Increased spacing
          const Text(
            'Failed to load users',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // Larger font
          ),
          const SizedBox(height: 12), // Increased spacing
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20), // Added padding
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14, // Larger font
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
              ),
            ),
          ),
          const SizedBox(height: 20), // Increased spacing
          ElevatedButton(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), // Larger button
            ),
            child: const Text('Try Again', style: TextStyle(fontSize: 16)), // Larger font
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
          Icon(Icons.people_outline, size: 80, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)), // Larger icon
          const SizedBox(height: 20), // Increased spacing
          Text(
            "No ${_selectedSystem == 0 ? 'dashboard' : 'radar app'} users found",
            style: TextStyle(
              fontSize: 18, // Larger font
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
            ),
          ),
          const SizedBox(height: 12), // Increased spacing
          Text(
            "Users will appear here once they register",
            style: TextStyle(
              fontSize: 14, // Larger font
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
          Icon(Icons.search_off, size: 80, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)), // Larger icon
          const SizedBox(height: 20), // Increased spacing
          Text(
            "No users found for \"$_searchQuery\"",
            style: TextStyle(
              fontSize: 18, // Larger font
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
            ),
          ),
          const SizedBox(height: 12), // Increased spacing
          Text(
            "Try adjusting your search terms",
            style: TextStyle(
              fontSize: 14, // Larger font
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
            ),
          ),
          const SizedBox(height: 20), // Increased spacing
          ElevatedButton(
            onPressed: _onClearSearch,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), // Larger button
            ),
            child: const Text('Clear Search', style: TextStyle(fontSize: 16)), // Larger font
          ),
        ],
      ),
    );
  }

  // Helper methods
  List<QueryDocumentSnapshot> _filterRadarUsers(List<QueryDocumentSnapshot> users) {
    if (_searchQuery.isEmpty) return users;
    
    return users.where((userDoc) {
      final userData = userDoc.data() as Map<String, dynamic>;
      final email = userData['email']?.toString().toLowerCase() ?? '';
      final name = userData['name']?.toString().toLowerCase() ?? '';
      final role = userData['role']?.toString().toLowerCase() ?? '';
      final address = userData['address']?.toString().toLowerCase() ?? '';

      return email.contains(_searchQuery) ||
             name.contains(_searchQuery) ||
             role.contains(_searchQuery) ||
             address.contains(_searchQuery);
    }).toList();
  }

  bool _isUserActive(QueryDocumentSnapshot user) {
    final data = user.data() as Map<String, dynamic>;
    final lastActive = data['lastActive'] as Timestamp?;
    if (lastActive == null) return false;
    final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
    return lastActive.toDate().isAfter(twentyFourHoursAgo);
  }

  int _calculateEmergencyReports(List<QueryDocumentSnapshot> users) {
    return users.fold<int>(0, (total, user) {
      final data = user.data() as Map<String, dynamic>;
      return total + ((data['emergencyReports'] ?? 0) as int);
    });
  }

  bool _isAdmin(QueryDocumentSnapshot user) {
    final data = user.data() as Map<String, dynamic>;
    return data['role'] == 'admin';
  }

  void _viewUsersOnMap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening map view...'),
        backgroundColor: Color(0xFF2C5282),
      ),
    );
  }
}