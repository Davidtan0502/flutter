import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Add Supabase import
import 'package:radar_dashboard/login/login_register_screen.dart';
import 'package:radar_dashboard/screens/profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onMenuPressed;
  final bool isDarkMode;
  final ValueChanged<bool> onToggleTheme;

  const SettingsScreen({
    super.key,
    required this.onMenuPressed,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationsEnabled = true;
  final SupabaseClient _supabase = Supabase.instance.client; // Add Supabase client

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionCard(
                  title: 'Preferences',
                  children: [
                    SwitchListTile(
                      value: widget.isDarkMode,
                      onChanged: widget.onToggleTheme,
                      title: const Text('Dark Mode'),
                      secondary: const Icon(Icons.brightness_6_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: 'Account',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Profile'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock_reset_outlined),
                      title: const Text('Reset Password'),
                      onTap: _handlePasswordReset,
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_forever, color: Colors.red),
                      title: const Text(
                        'Delete Account',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: _handleDeleteAccount,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: widget.onMenuPressed,
      ),
      title: const Text('SETTINGS'),
      centerTitle: true,
      backgroundColor: const Color(0xFF2C5282),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.dashboard_outlined, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _handlePasswordReset() async {
    final user = _supabase.auth.currentUser;
    if (user?.email == null) {
      _showSnackbar('No email found for password reset');
      return;
    }

    try {
      await _supabase.auth.resetPasswordForEmail(user!.email!);
      _showSnackbar('Password reset email sent! Check your inbox.');
    } catch (e) {
      _showSnackbar('Error sending reset email: $e');
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
            'This will permanently delete your account and all associated data. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete user data from dashboard_users table first
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          await _supabase
              .from('dashboard_users')
              .delete()
              .eq('id', userId);
        }

        // Then delete the auth user
        await _supabase.auth.admin.deleteUser(
          _supabase.auth.currentUser!.id,
        );

        // Sign out and navigate to login
        await _supabase.auth.signOut();
        
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (context) => const LoginRegisterScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        _showSnackbar('Error deleting account: $e');
        
        // Even if there's an error, sign out and go to login
        await _supabase.auth.signOut();
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

  void _showSnackbar(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}