import 'package:flutter/material.dart';
import 'package:radar_dashboard/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:radar_dashboard/login/login_register_screen.dart';
import 'package:radar_dashboard/login/terms_and_condition.dart';
import 'package:radar_dashboard/navigation/main_navigation.dart';
import 'package:radar_dashboard/login/admin/admin_panel_screen.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase with correct parameters for v2.10.3
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    debug: true, // Optional: for debugging
  );

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkMode') ?? false;

  runApp(ProjectRadarApp(initialDarkMode: isDark));
}

class ProjectRadarApp extends StatefulWidget {
  final bool initialDarkMode;

  const ProjectRadarApp({super.key, required this.initialDarkMode});

  @override
  State<ProjectRadarApp> createState() => _ProjectRadarAppState();
}

class _ProjectRadarAppState extends State<ProjectRadarApp> {
  late bool isDarkMode;
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<AuthState>? _authStateSubscription;

  // Global navigator key to avoid context issues
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    isDarkMode = widget.initialDarkMode;
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    // Set up auth state listener
    _authStateSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      
      debugPrint('Auth state changed: $event');
      
      if (event == AuthChangeEvent.signedIn && session != null) {
        debugPrint('User signed in: ${session.user.email}');
        // Handle user authentication
        _handleUserAuthentication(session.user);
      } else if (event == AuthChangeEvent.signedOut) {
        debugPrint('User signed out');
        _navigateToLogin();
      } else if (event == AuthChangeEvent.userUpdated) {
        debugPrint('User updated');
        final user = _supabase.auth.currentUser;
        if (user != null) {
          _handleUserAuthentication(user);
        }
      }
    });

    // Check if user is already authenticated when app starts
    await _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    try {
      final currentSession = _supabase.auth.currentSession;
      if (currentSession != null) {
        debugPrint('Current session found: ${currentSession.user.email}');
        await _handleUserAuthentication(currentSession.user);
      } else {
        // No session found, ensure we're at login screen
        _navigateToLogin();
      }
    } catch (e) {
      debugPrint('Initial auth check error: $e');
      _navigateToLogin();
    }
  }

  Future<void> _handleUserAuthentication(User user) async {
    try {
      // Step 1: Update last login (non-critical, can fail)
      await _updateUserLastLogin(user.id);
      
      // Step 2: Get user role with proper error handling
      final userRole = await _getUserRoleWithFallback(user.id);
      
      if (userRole != null) {
        // Valid user found, navigate to dashboard
        _navigateToDashboard(userRole);
      } else {
        // User not found or RLS error
        debugPrint('User not authorized for dashboard access');
        await _safeSignOut();
        _navigateToLogin();
      }
    } catch (e) {
      debugPrint('Error handling user authentication: $e');
      await _safeSignOut();
      _navigateToLogin();
    }
  }

  Future<void> _updateUserLastLogin(String userId) async {
    try {
      final response = await _supabase
          .from('dashboard_users')
          .update({
            'last_login': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      if (response.error != null) {
        debugPrint('Error updating last login: ${response.error!.message}');
      } else {
        debugPrint('User last login updated: $userId');
      }
    } catch (e) {
      debugPrint('Exception updating user last login: $e');
      // Non-critical error, continue with authentication
    }
  }

  Future<String?> _getUserRoleWithFallback(String userId) async {
    try {
      debugPrint('Fetching user role for: $userId');
      
      final userData = await _supabase
          .from('dashboard_users')
          .select('role, email')
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 5));

      final userRole = userData['role'] as String?;
      final userEmail = userData['email'] as String?;
      
      debugPrint('User role check - Email: $userEmail, Role: $userRole');
      
      // Validate that user exists and has a valid role
      if (userRole == null) {
        debugPrint('User role is null');
        return null;
      }

      // Only allow 'admin' or 'user' roles
      if (userRole != 'admin' && userRole != 'user') {
        debugPrint('Invalid user role: $userRole');
        return null;
      }

      return userRole;
      
    } on PostgrestException catch (e) {
      // Handle RLS infinite recursion specifically
      if (e.message.contains('infinite recursion')) {
        debugPrint('RLS infinite recursion detected - using fallback');
        // Try to get user role with a different approach
        return await _getUserRoleFallback(userId);
      }
      // Handle "no rows returned" error
      else if (e.message.contains('PGRST116') || e.message.contains('row not found')) {
        debugPrint('User not found in dashboard_users table');
        return null;
      } else {
        debugPrint('Database error getting user role: ${e.message}');
        return await _getUserRoleFallback(userId);
      }
    } on TimeoutException {
      debugPrint('Timeout getting user role');
      return await _getUserRoleFallback(userId);
    } catch (e) {
      debugPrint('Unexpected error getting user role: $e');
      return await _getUserRoleFallback(userId);
    }
  }

  Future<String?> _getUserRoleFallback(String userId) async {
    try {
      debugPrint('Using fallback method to get user role');
      
      // Try a different approach - use service role to bypass RLS
      final adminClient = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.serviceRoleKey
      );
      
      final userData = await adminClient
          .from('dashboard_users')
          .select('role, email')
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 5));

      final userRole = userData['role'] as String?;
      final userEmail = userData['email'] as String?;
      
      debugPrint('Fallback user role - Email: $userEmail, Role: $userRole');
      
      if (userRole == null) {
        return null;
      }

      if (userRole != 'admin' && userRole != 'user') {
        return null;
      }

      return userRole;
      
    } catch (e) {
      debugPrint('Fallback method also failed: $e');
      return null;
    }
  }

  Future<void> _safeSignOut() async {
    try {
      await _supabase.auth.signOut();
      debugPrint('User signed out successfully');
    } catch (e) {
      debugPrint('Error during sign out: $e');
    }
  }

  void _navigateToDashboard(String userRole) {
    final routeName = userRole == 'admin' ? '/admin-dashboard' : '/user-dashboard';
    debugPrint('Navigating to: $routeName');
    
    // Use a post-frame callback to ensure safe navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        routeName,
        (route) => false,
      );
    });
  }

  void _navigateToLogin() {
    debugPrint('Navigating to login');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    });
  }

  void toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = value;
    });
    await prefs.setBool('isDarkMode', value);
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project RADAR',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginRegisterScreen(),
        '/admin-dashboard': (context) => NavigationScreen(
              isDarkMode: isDarkMode,
              onToggleTheme: toggleTheme,
              userRole: 'admin',
            ),
        '/user-dashboard': (context) => NavigationScreen(
              isDarkMode: isDarkMode,
              onToggleTheme: toggleTheme,
              userRole: 'user',
            ),
        '/admin-panel': (context) => const AdminPanelScreen(),
        '/terms': (context) => const TermsAndConditionsScreen(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const LoginRegisterScreen(),
        );
      },
    );
  }
}

// Improved Auth wrapper with better error handling
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _loadingMessage;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      _updateLoadingMessage('Initializing...');
      await Future.delayed(const Duration(milliseconds: 800));
      
      final currentUser = _supabase.auth.currentUser;
      debugPrint('Auth check - Current user: $currentUser');
      
      if (currentUser != null) {
        // Check if email is confirmed or if we're in development mode
        final emailConfirmed = currentUser.emailConfirmedAt != null || _isDevelopmentMode();
        
        if (!emailConfirmed) {
          debugPrint('Email not confirmed yet');
          _updateLoadingMessage('Please verify your email...');
          await Future.delayed(const Duration(seconds: 2));
          await _safeSignOut();
          _finishLoading();
          return;
        }

        _updateLoadingMessage('Checking permissions...');
        
        // Get user role with proper error handling
        final userRole = await _getUserRoleSafe(currentUser.id);
        
        if (userRole != null) {
          _updateLoadingMessage('Welcome back!...');
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Navigate to dashboard
          if (mounted) {
            Navigator.of(context).pushReplacementNamed(
              userRole == 'admin' ? '/admin-dashboard' : '/user-dashboard',
            );
          }
          return;
        } else {
          debugPrint('User not authorized for dashboard access');
          _updateLoadingMessage('Access denied...');
          await Future.delayed(const Duration(seconds: 1));
          await _safeSignOut();
        }
      }
      
      // If we get here, user is not authenticated or not authorized
      debugPrint('User not authenticated or not authorized, going to login');
      _finishLoading();
      
    } catch (e) {
      debugPrint('Auth check error: $e');
      await _safeSignOut();
      _finishLoading();
    }
  }

  Future<String?> _getUserRoleSafe(String userId) async {
    try {
      final userData = await _supabase
          .from('dashboard_users')
          .select('role, email')
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 5));

      final userRole = userData['role'] as String?;
      final userEmail = userData['email'] as String?;
      
      debugPrint('User role check - Email: $userEmail, Role: $userRole');
      
      // Validate that user exists and has a valid role
      if (userRole == null) {
        return null;
      }

      // Only allow 'admin' or 'user' roles
      if (userRole != 'admin' && userRole != 'user') {
        return null;
      }

      return userRole;
      
    } on PostgrestException catch (e) {
      // Handle RLS infinite recursion
      if (e.message.contains('infinite recursion')) {
        debugPrint('RLS recursion detected, using service role fallback');
        return await _getUserRoleWithServiceRole(userId);
      }
      // Handle "no rows returned" error
      else if (e.message.contains('PGRST116') || e.message.contains('row not found')) {
        debugPrint('User not found in dashboard_users table');
        return null;
      } else {
        debugPrint('Database error: ${e.message}');
        return await _getUserRoleWithServiceRole(userId);
      }
    } on TimeoutException {
      debugPrint('Timeout getting user role');
      return await _getUserRoleWithServiceRole(userId);
    } catch (e) {
      debugPrint('Unexpected error: $e');
      return await _getUserRoleWithServiceRole(userId);
    }
  }

  Future<String?> _getUserRoleWithServiceRole(String userId) async {
    try {
      debugPrint('Using service role to get user role');
      
      final adminClient = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.serviceRoleKey
      );
      
      final userData = await adminClient
          .from('dashboard_users')
          .select('role, email')
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 5));

      final userRole = userData['role'] as String?;
      final userEmail = userData['email'] as String?;
      
      debugPrint('Service role check - Email: $userEmail, Role: $userRole');
      
      if (userRole == null) {
        return null;
      }

      if (userRole != 'admin' && userRole != 'user') {
        return null;
      }

      return userRole;
      
    } catch (e) {
      debugPrint('Service role method also failed: $e');
      return null;
    }
  }

  void _updateLoadingMessage(String message) {
    if (mounted) {
      setState(() {
        _loadingMessage = message;
      });
    }
  }

  void _finishLoading() {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _safeSignOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Error during sign out: $e');
    }
  }

  // Helper method to check if we're in development mode
  bool _isDevelopmentMode() {
    return SupabaseConfig.url.contains('localhost') || 
           SupabaseConfig.url.contains('127.0.0.1') ||
           !SupabaseConfig.url.contains('supabase.co');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'PROJECT RADAR',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _loadingMessage ?? 'Checking authentication...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const LoginRegisterScreen();
  }
}