import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:radar_dashboard/login/admin/mobile_user_card.dart';
import 'dart:async';

class SearchableUsersList extends StatefulWidget {
  const SearchableUsersList({super.key});

  @override
  State<SearchableUsersList> createState() => _SearchableUsersListState();
}

class _SearchableUsersListState extends State<SearchableUsersList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _loading = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final response = await _supabase
          .from('app_users')
          .select()
          .order('created_at', ascending: false);
      
      setState(() => _users = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint('Error loading users: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String value) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce?.cancel();
    
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _searchQuery = value.toLowerCase().trim());
    });
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search users by email, name, role, or address...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  Widget _buildUsersList() {
    if (_loading) {
      return _buildLoadingState();
    }

    final filteredUsers = _filterUsers(_users);

    if (filteredUsers.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isEmpty ? 'No users found' : 'No users found for "$_searchQuery"'
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final userData = filteredUsers[index];
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: RadarAppUserCard(
            userData: userData,
            searchQuery: _searchQuery,
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _filterUsers(List<Map<String, dynamic>> users) {
    if (_searchQuery.isEmpty) return users;
    
    return users.where((userData) {
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

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading users...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadUsers,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _clearSearch,
              child: const Text('Clear Search'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        const SizedBox(height: 16),
        Expanded(child: _buildUsersList()),
      ],
    );
  }
}