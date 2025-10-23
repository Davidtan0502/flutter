import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:radar_dashboard/dashboard/admin%20panel%20screen/admin_management_screen.dart';
import 'package:radar_dashboard/login/reset_password_screen.dart';
import 'package:radar_dashboard/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:radar_dashboard/login/login_register_screen.dart';
import 'package:radar_dashboard/login/terms_and_condition.dart';
import 'package:radar_dashboard/navigation/main_navigation.dart';
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
        // Valid user found, navigate to appropriate screen
        _navigateToUserScreen(userRole);
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

      // Allow 'admin', 'moderator', or 'user' roles
      if (userRole != 'admin' && userRole != 'moderator' && userRole != 'user') {
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

      // Allow 'admin', 'moderator', or 'user' roles
      if (userRole != 'admin' && userRole != 'moderator' && userRole != 'user') {
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

  void _navigateToUserScreen(String userRole) {
    final routeName = _getUserRoute(userRole);
    debugPrint('Navigating to: $routeName for role: $userRole');
    
    // Use a post-frame callback to ensure safe navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        routeName,
        (route) => false,
      );
    });
  }

  String _getUserRoute(String userRole) {
    switch (userRole) {
      case 'admin':
        return '/admin-management'; // Admin goes only to admin management
      case 'moderator':
        return '/moderator-dashboard';
      case 'user':
        return '/user-dashboard';
      default:
        return '/login';
    }
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
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/register': (context) => const LoginRegisterScreen(), 
        '/admin-management': (context) => AdminManagementScreen(),
        '/moderator-dashboard': (context) => NavigationScreen(
              isDarkMode: isDarkMode,
              onToggleTheme: toggleTheme,
              userRole: 'moderator',
            ),
        '/user-dashboard': (context) => NavigationScreen(
              isDarkMode: isDarkMode,
              onToggleTheme: toggleTheme,
              userRole: 'user',
            ),
        '/terms': (context) => const TermsAndConditionsScreen(),
      },
      
      onGenerateRoute: (settings) {
        debugPrint('🔄 Route requested: ${settings.name}');
        
        String routeName = settings.name ?? '/';
        
        // Handle hash-based URLs (/#/reset-password)
        if (routeName.startsWith('/#')) {
          routeName = routeName.substring(2);
          debugPrint('🌐 Converted hash route to: $routeName');
        }
        
        // Handle query parameters for multi-app support
        final uri = Uri.parse(routeName.contains('://') ? routeName : 'http://localhost$routeName');
        
        debugPrint('🔗 URI path: ${uri.path}');
        debugPrint('🔗 URI fragment: ${uri.fragment}');
        debugPrint('🔗 URI query: ${uri.query}');
        
        // Check if this is a password reset flow
        if (uri.path == '/reset-password' || 
            uri.fragment.contains('type=recovery') ||
            uri.query.contains('type=recovery')) {
          debugPrint('🎯 Password reset flow detected');
          return MaterialPageRoute(builder: (context) => const ResetPasswordScreen());
        }
        
        // Handle regular routes
        switch (uri.path) {
          case '/reset-password':
            debugPrint('🎯 Navigating to ResetPasswordScreen');
            return MaterialPageRoute(builder: (context) => const ResetPasswordScreen());
          case '/login':
            return MaterialPageRoute(builder: (context) => const LoginRegisterScreen());
          default:
            return MaterialPageRoute(builder: (context) => const AuthWrapper());
        }
      },
      
      // Add this to handle initial route
      initialRoute: '/',
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isCheckingAuth = false;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
    _checkResetPasswordUrl(); // Add this line
  }

    void _checkResetPasswordUrl() {
    if (!_isLoading) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kIsWeb) {
        final currentUrl = Uri.base.toString();
        final fragment = Uri.base.fragment;
        
        debugPrint('🔗 Current URL: $currentUrl');
        debugPrint('🔗 Fragment: $fragment');
        
        // Check if this is a reset password callback
        if (fragment.contains('access_token') || 
            fragment.contains('type=recovery') ||
            fragment.contains('reset-password')) {
          debugPrint('🎯 Reset password link detected!');
          
          // Navigate to reset password screen
          Navigator.of(context).pushReplacementNamed('/reset-password');
        }
      }
    });
  }

  Future<void> _checkInitialAuth() async {
    // Prevent multiple simultaneous auth checks
    if (_isCheckingAuth) return;
    _isCheckingAuth = true;

    try {
      debugPrint('=== Starting initial auth check ===');
      
      final currentUser = _supabase.auth.currentUser;
      debugPrint('Current user: ${currentUser?.email}');
      debugPrint('User ID: ${currentUser?.id}');
      
      if (currentUser != null) {
        // Check email confirmation (with development mode bypass)
        final emailConfirmed = currentUser.emailConfirmedAt != null || _isDevelopmentMode();
        
        if (!emailConfirmed) {
          debugPrint('Email not confirmed - signing out');
          await _safeSignOut();
          _finishLoading();
          return;
        }

        debugPrint('Email confirmed, checking user role...');
        
        // Get user role
        final userRole = await _getUserRoleSafe(currentUser.id);
        debugPrint('User role result: $userRole');
        
        if (userRole != null && _isValidRole(userRole)) {
          debugPrint('User authorized with role: $userRole - navigating to appropriate screen');
          
          // Use a small delay to ensure context is ready
          await Future.delayed(const Duration(milliseconds: 100));
          
          if (mounted) {
            _navigateToUserScreen(userRole);
            return; // Important: return here to prevent finishing loading
          }
        } else {
          debugPrint('User not authorized or invalid role - signing out');
          await _safeSignOut();
        }
      } else {
        debugPrint('No current user found');
      }
      
      _finishLoading();
      
    } catch (e, stackTrace) {
      debugPrint('Auth check error: $e');
      debugPrint('Stack trace: $stackTrace');
      await _safeSignOut();
      _finishLoading();
    } finally {
      _isCheckingAuth = false;
    }
  }

  Future<String?> _getUserRoleSafe(String userId) async {
    try {
      debugPrint('Fetching user role from dashboard_users table...');
      
      final response = await _supabase
          .from('dashboard_users')
          .select('role, email')
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 10));

      final userRole = response['role'] as String?;
      final userEmail = response['email'] as String?;
      
      debugPrint('User role query successful - Email: $userEmail, Role: $userRole');
      
      return userRole;
      
    } on PostgrestException catch (e) {
      debugPrint('Postgrest error: ${e.message}');
      
      // Handle RLS infinite recursion
      if (e.message?.contains('infinite recursion') == true) {
        debugPrint('RLS recursion detected, trying service role...');
        return await _getUserRoleWithServiceRole(userId);
      }
      // Handle "no rows returned" error
      else if (e.message?.contains('PGRST116') == true || e.message?.contains('row not found') == true) {
        debugPrint('User not found in dashboard_users table');
        return null;
      } else {
        debugPrint('Other database error, trying service role...');
        return await _getUserRoleWithServiceRole(userId);
      }
    } on TimeoutException {
      debugPrint('Timeout getting user role, trying service role...');
      return await _getUserRoleWithServiceRole(userId);
    } catch (e) {
      debugPrint('Unexpected error getting user role: $e');
      return await _getUserRoleWithServiceRole(userId);
    }
  }

  Future<String?> _getUserRoleWithServiceRole(String userId) async {
    try {
      debugPrint('Using service role to get user role...');
      
      final adminClient = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.serviceRoleKey
      );
      
      final response = await adminClient
          .from('dashboard_users')
          .select('role, email')
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 10));

      final userRole = response['role'] as String?;
      final userEmail = response['email'] as String?;
      
      debugPrint('Service role query successful - Email: $userEmail, Role: $userRole');
      
      return userRole;
      
    } catch (e) {
      debugPrint('Service role method failed: $e');
      return null;
    }
  }

  bool _isValidRole(String role) {
    return role == 'admin' || role == 'moderator' || role == 'user';
  }

  void _navigateToUserScreen(String userRole) {
    debugPrint('Navigating to screen for role: $userRole');
    
    String routeName;
    switch (userRole) {
      case 'admin':
        routeName = '/admin-management'; // Admin goes only to admin management
        break;
      case 'moderator':
        routeName = '/moderator-dashboard';
        break;
      case 'user':
        routeName = '/user-dashboard';
        break;
      default:
        routeName = '/login';
    }
    
    // Use Navigator to navigate and replace the AuthWrapper
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(routeName);
      }
    });
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
      debugPrint('Signed out successfully');
    } catch (e) {
      debugPrint('Error during sign out: $e');
    }
  }

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
                'Checking authentication...',
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