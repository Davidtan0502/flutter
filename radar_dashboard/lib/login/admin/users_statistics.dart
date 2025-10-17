// users_statistics.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsersStatisticsSection extends StatelessWidget {
  final String collection;
  final int systemType;
  final String searchQuery;

  const UsersStatisticsSection({
    super.key,
    required this.collection,
    required this.systemType,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from(collection)
          .stream(primaryKey: ['id']),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildLoadingStats();
        }

        final users = snapshot.data!;
        final filteredUsers = systemType == 1 ? _filterRadarUsers(users) : users;
        
        return systemType == 1 
            ? _buildRadarAppStats(filteredUsers, users.length)
            : _buildDashboardStats(users);
      },
    );
  }

  Widget _buildLoadingStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(3, (index) => _StatCard.loading()),
    );
  }

  Widget _buildRadarAppStats(List<Map<String, dynamic>> users, int totalUsers) {
    final emergencyReports = _calculateEmergencyReports(users);
    final activeUsers = users.where((user) => _isUserActive(user)).length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatCard(
          title: "Users", 
          value: users.length.toString(), 
          icon: Icons.people, 
          color: Colors.blue,
          isFiltered: searchQuery.isNotEmpty,
          totalCount: totalUsers,
        ),
        _StatCard(
          title: "Active (24h)", 
          value: activeUsers.toString(), 
          icon: Icons.online_prediction, 
          color: Colors.green,
        ),
        _StatCard(
          title: "Emergencies", 
          value: emergencyReports.toString(), 
          icon: Icons.warning, 
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildDashboardStats(List<Map<String, dynamic>> users) {
    final adminCount = users.where((user) => _isAdmin(user)).length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatCard(title: "Total Users", value: users.length.toString(), icon: Icons.people, color: Colors.blue),
        _StatCard(title: "Admins", value: adminCount.toString(), icon: Icons.admin_panel_settings, color: Colors.purple),
        _StatCard(title: "Users", value: (users.length - adminCount).toString(), icon: Icons.person, color: Colors.green),
      ],
    );
  }

  // Helper methods
  List<Map<String, dynamic>> _filterRadarUsers(List<Map<String, dynamic>> users) {
    if (searchQuery.isEmpty) return users;
    
    return users.where((user) {
      final email = user['email']?.toString().toLowerCase() ?? '';
      final name = user['name']?.toString().toLowerCase() ?? '';
      final role = user['role']?.toString().toLowerCase() ?? '';
      final address = user['address']?.toString().toLowerCase() ?? '';

      return email.contains(searchQuery) ||
             name.contains(searchQuery) ||
             role.contains(searchQuery) ||
             address.contains(searchQuery);
    }).toList();
  }

  bool _isUserActive(Map<String, dynamic> user) {
    final lastActive = user['last_active'];
    if (lastActive == null) return false;
    
    DateTime lastActiveTime;
    
    // Handle different timestamp formats
    if (lastActive is String) {
      final parsed = DateTime.tryParse(lastActive);
      if (parsed == null) return false;
      lastActiveTime = parsed;
    } else if (lastActive is DateTime) {
      lastActiveTime = lastActive;
    } else {
      return false;
    }
    
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
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isFiltered;
  final int? totalCount;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isFiltered = false,
    this.totalCount,
  });

  const _StatCard.loading() : 
    title = 'Loading',
    value = '--',
    icon = Icons.hourglass_empty,
    color = Colors.grey,
    isFiltered = false,
    totalCount = null;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isFiltered ? Border.all(color: color, width: 2) : null,
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              if (isFiltered)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.purple,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.filter_alt, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (totalCount != null && isFiltered)
            Text(
              '/$totalCount',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}