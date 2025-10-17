import 'package:flutter/material.dart';
import 'package:radar_dashboard/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:radar_dashboard/login/terms_and_condition.dart';

// Define snackbar types for different styling
enum SnackbarType { success, error, warning, info }

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({super.key});

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool isLogin = true;
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool termsAccepted = false;
  bool showTermsError = false;
  bool isResettingPassword = false;

  // Form fields
  String email = '';
  String password = '';
  String confirmPassword = '';
  String firstName = '';
  String lastName = '';
  String phoneNumber = '';
  DateTime? dateOfBirth;

  // Track field focus for real-time validation
  final Map<String, bool> _fieldTouched = {
    'email': false,
    'password': false,
    'confirmPassword': false,
    'firstName': false,
    'lastName': false,
    'phoneNumber': false,
  };

  // Enhanced password validation with Google-like security
  final PasswordSecurityManager _passwordManager = PasswordSecurityManager();

  // Mark field as touched when user interacts with it
  void _markFieldTouched(String fieldName) {
    if (!_fieldTouched[fieldName]!) {
      setState(() {
        _fieldTouched[fieldName] = true;
      });
    }
  }

  // Validate field in real-time if it's been touched
  String? _validateField(String fieldName, String? value) {
    if (!_fieldTouched[fieldName]! && value!.isEmpty) {
      return null; // Don't validate untouched empty fields
    }

    switch (fieldName) {
      case 'email':
        if (value == null || value.isEmpty) {
          return 'Email address is required';
        }
        if (!value.contains('@') || !value.contains('.')) {
          return 'Enter a valid email address';
        }
        return null;

      case 'password':
        final validation = _passwordManager.validatePassword(value);
        return validation.isValid ? null : validation.errorMessage;

      case 'confirmPassword':
        if (value == null || value.isEmpty) {
          return 'Please confirm your password';
        }
        if (value != password) {
          return 'Passwords do not match';
        }
        return null;

      case 'firstName':
        if (value == null || value.isEmpty) {
          return 'First name is required';
        }
        if (value.length < 2) {
          return 'First name must be at least 2 characters';
        }
        return null;

      case 'lastName':
        if (value == null || value.isEmpty) {
          return 'Last name is required';
        }
        if (value.length < 2) {
          return 'Last name must be at least 2 characters';
        }
        return null;

      case 'phoneNumber':
        if (value == null || value.isEmpty) {
          return 'Phone number is required';
        }
        if (value.length < 10) {
          return 'Phone number must be at least 10 digits';
        }
        return null;

      default:
        return null;
    }
  }

  Future<void> _submit() async {
    // Mark all fields as touched to trigger validation
    setState(() {
      for (var field in _fieldTouched.keys) {
        _fieldTouched[field] = true;
      }
      showTermsError = false;
    });

    if (!_formKey.currentState!.validate()) {
      _showSnackbar("Please fix the validation errors before submitting", SnackbarType.warning);
      return;
    }
    
    _formKey.currentState!.save();

    if (!isLogin) {
      // Enhanced registration validation
      final validationResult = _validateRegistration();
      if (!validationResult.isValid) {
        _showSnackbar(validationResult.errorMessage!, SnackbarType.error);
        return;
      }

      // Additional password security checks
      final securityCheck = _passwordManager.performSecurityChecks(
        password: password,
        email: email,
        firstName: firstName,
        lastName: lastName,
      );
      if (!securityCheck.isSecure) {
        _showSnackbar(securityCheck.message, SnackbarType.error);
        return;
      }
    }

    setState(() => isLoading = true);

    try {
      if (isLogin) {
        await _handleLogin();
      } else {
        await _handleRegistration();
      }
    } on AuthException catch (e) {
      _handleAuthException(e);
    } catch (e) {
      _showSnackbar('An unexpected error occurred. Please try again later.', SnackbarType.error);
      debugPrint('Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  RegistrationValidationResult _validateRegistration() {
    if (!termsAccepted) {
      setState(() => showTermsError = true);
      return RegistrationValidationResult(
        isValid: false,
        errorMessage: "Please accept the terms and conditions to continue",
      );
    }

    final passwordValidation = _passwordManager.validatePassword(password);
    if (!passwordValidation.isValid) {
      return RegistrationValidationResult(
        isValid: false,
        errorMessage: passwordValidation.errorMessage,
      );
    }

    if (password != confirmPassword) {
      return RegistrationValidationResult(
        isValid: false,
        errorMessage: 'Passwords do not match. Please check and try again.',
      );
    }

    return RegistrationValidationResult(isValid: true);
  }

Future<void> _handleLogin() async {
  final response = await _supabase.auth.signInWithPassword(
    email: email,
    password: password,
  );

  if (response.user == null) {
    _showSnackbar('Login failed. Please check your credentials.', SnackbarType.error);
    return;
  }

  try {
    // Query dashboard_users table for user role - uses users_select_own_profile policy
    final userData = await _supabase
        .from('dashboard_users') 
        .select('role, email, personal_details')
        .eq('id', response.user!.id)
        .single();

    final userRole = userData['role'] as String?;
    
    // If user doesn't exist in dashboard_users
    if (userRole == null) {
      _showSnackbar('Access denied. User not found in dashboard system.', SnackbarType.error);
      await _supabase.auth.signOut();
      return;
    }

    // Validate role
    if (userRole != 'admin' && userRole != 'user') {
      _showSnackbar('Access denied. Invalid user permissions.', SnackbarType.error);
      await _supabase.auth.signOut();
      return;
    }

    // Update user's last login timestamp - uses users_update_own_profile policy
    await _updateUserLastLogin(response.user!.id);

    _showSnackbar('Login successful! Welcome back.', SnackbarType.success);
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/${userRole}_dashboard');

  } on PostgrestException catch (e) {
    debugPrint('Database error during login: ${e.message}');
    
    if (e.message.contains('PGRST116')) { // No rows returned
      _showSnackbar('Access denied. User not found in dashboard system.', SnackbarType.error);
      await _supabase.auth.signOut();
    } else if (e.message.contains('row-level security policy')) {
      _showSnackbar('Access denied. Insufficient permissions.', SnackbarType.error);
      await _supabase.auth.signOut();
    } else {
      _showSnackbar('Login error. Please try again.', SnackbarType.error);
    }
  } catch (e) {
    debugPrint('Unexpected error during login: $e');
    _showSnackbar('An unexpected error occurred. Please try again.', SnackbarType.error);
  }
}

Future<void> _handleRegistration() async {
  final response = await _supabase.auth.signUp(
    email: email,
    password: password,
    data: {'type': 'dashboard'}
  );

  if (response.user == null) {
    _showSnackbar('Registration failed. Please try again.', SnackbarType.error);
    return;
  }

  // Show verification email sent message immediately
  _showSnackbar(
    'Verification email sent! Please check your inbox to verify your email address.',
    SnackbarType.success
  );

  const assignedRole = 'user'; // Always 'user' for new registrations
  
  try {
    // IMPORTANT: Use the service role client to bypass RLS for initial profile creation
    final adminClient = SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.serviceRoleKey // Make sure this is set in your config
    );

    // Create user profile in dashboard_users table using service role
    await adminClient.from('dashboard_users').insert({
      'id': response.user!.id,
      'email': email,
      'role': assignedRole,
      'personal_details': {
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'lastUpdated': DateTime.now().toIso8601String(),
      },
      'security': {
        'passwordStrength': _passwordManager.calculatePasswordStrength(password),
        'passwordHash': _passwordManager.generatePasswordHash(password),
        'commonPasswordCheck': _passwordManager.isCommonPassword(password),
        'accountCreated': DateTime.now().toIso8601String(),
        'lastPasswordChange': DateTime.now().toIso8601String(),
        'passwordHistory': [_passwordManager.generatePasswordHash(password)],
      },
      'created_at': DateTime.now().toIso8601String(),
      'last_login': DateTime.now().toIso8601String(),
    });

    debugPrint('User profile created successfully in dashboard_users with role: $assignedRole');

    _showSnackbar(
      "Account created successfully! Please check your email to verify your account.",
      SnackbarType.success,
    );

    _resetForm();
    setState(() {
      isLogin = true;
    });

  } on PostgrestException catch (e) {
    debugPrint('Database error during registration: ${e.message}');
    
    // Even if database insert fails, the auth user was created and email was sent
    _showSnackbar(
      'Account created! Please sign in after verifying your email.',
      SnackbarType.success
    );
    _resetForm();
    setState(() => isLogin = true);
  } catch (e) {
    debugPrint('Unexpected error during profile creation: $e');
    _showSnackbar(
      'Account created! Please check your email for verification.',
      SnackbarType.success
    );
    _resetForm();
    setState(() => isLogin = true);
  }
}
  // Add this method to update user's last login timestamp
Future<void> _updateUserLastLogin(String userId) async {
  try {
    await _supabase
        .from('dashboard_users')
        .update({
          'last_login': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
    debugPrint('User last login updated: $userId');
  } catch (e) {
    debugPrint('Error updating user last login: $e');
    // Non-critical error, don't disrupt login flow
  }
}

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      password = '';
      confirmPassword = '';
      termsAccepted = false;
      showTermsError = false;
      // Reset touched fields
      for (var field in _fieldTouched.keys) {
        _fieldTouched[field] = false;
      }
    });
  }

  void _handleAuthException(AuthException e) {
    String errorMessage;
    switch (e.message) {
      case 'Invalid login credentials':
        errorMessage = "Invalid email or password. Please check your credentials.";
        break;
      case 'Email not confirmed':
        errorMessage = "Please confirm your email address before logging in.";
        break;
      case 'User already registered':
        errorMessage = "This email is already registered. Please sign in instead.";
        break;
      case 'Weak password':
        errorMessage = "Password is too weak. Please choose a stronger password.";
        break;
      case 'Password should be at least 6 characters':
        errorMessage = "Password must be at least 6 characters long.";
        break;
      default:
        errorMessage = e.message;
    }
    _showSnackbar(errorMessage, SnackbarType.error);
  }

  void _showSnackbar(String message, SnackbarType type) {
    Color backgroundColor = Colors.grey.shade700;
    IconData icon = Icons.info_outline;
    
    switch (type) {
      case SnackbarType.success:
        backgroundColor = Colors.green.shade700;
        icon = Icons.check_circle_outline;
        break;
      case SnackbarType.error:
        backgroundColor = Colors.red.shade700;
        icon = Icons.error_outline;
        break;
      case SnackbarType.warning:
        backgroundColor = Colors.orange.shade700;
        icon = Icons.warning_amber_outlined;
        break;
      case SnackbarType.info:
        backgroundColor = Colors.blue.shade700;
        icon = Icons.info_outline;
        break;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: backgroundColor,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != dateOfBirth) {
      setState(() {
        dateOfBirth = picked;
      });
    }
  }

  // Enhanced Terms and Conditions flow with modern aesthetics
  void _showTermsPreview() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 16,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade50,
                  Colors.white,
                  Colors.grey.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.security,
                        color: Colors.blue.shade700,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Terms & Conditions",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Preview Content
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade100.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTermItem(
                          icon: Icons.privacy_tip_outlined,
                          title: "Privacy & Data Protection",
                          description: "Your data is encrypted and protected with enterprise-grade security measures.",
                        ),
                        const SizedBox(height: 12),
                        _buildTermItem(
                          icon: Icons.assignment_outlined,
                          title: "Service Agreement",
                          description: "By using this service, you agree to our terms of service and acceptable use policy.",
                        ),
                        const SizedBox(height: 12),
                        _buildTermItem(
                          icon: Icons.emergency_outlined,
                          title: "Emergency Response",
                          description: "This system is designed for critical disaster response operations.",
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade400),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            "Not Now",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 4,
                          ),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _showFullTermsAndConditions();
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Review Full Terms",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTermItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Colors.blue.shade600,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Show full terms and conditions in an interactive screen
  Future<void> _showFullTermsAndConditions() async {
    final agreed = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const TermsAndConditionsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(curve),
            child: FadeTransition(
              opacity: curve,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
    
    if (agreed == true && mounted) {
      setState(() {
        termsAccepted = true;
        showTermsError = false;
      });
      _showSnackbar("Terms and conditions accepted successfully", SnackbarType.success);
    }
  }

  Future<void> _resetPassword() async {
    if (email.isEmpty || !email.contains('@')) {
      _showResetPasswordDialog();
      return;
    }
    
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _showSnackbar("Please enter a valid email address", SnackbarType.error);
      return;
    }
    
    await _sendPasswordResetEmail(email);
  }

  void _showResetPasswordDialog() {
    final TextEditingController emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Reset Password"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter your email address to receive password reset instructions:"),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email address';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (emailController.text.isEmpty) {
                  _showSnackbar("Please enter your email address", SnackbarType.error);
                  return;
                }
                
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(emailController.text)) {
                  _showSnackbar("Please enter a valid email address", SnackbarType.error);
                  return;
                }
                
                Navigator.of(context).pop();
                await _sendPasswordResetEmail(emailController.text);
              },
              child: const Text("Send Reset Link"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendPasswordResetEmail(String emailAddress) async {
    setState(() => isResettingPassword = true);
    
    try {
      await _supabase.auth.resetPasswordForEmail(emailAddress);
      
      _showSnackbar(
        "Password reset email sent! Check your inbox for instructions. If you don't see it, check your spam folder.",
        SnackbarType.success
      );
      
      if (email.isEmpty) {
        setState(() => email = emailAddress);
      }
      
    } on AuthException catch (e) {
      String errorMessage;
      switch (e.message) {
        case 'User not found':
          errorMessage = "No account found with this email address. Please check your email or register for a new account.";
          break;
        default:
          errorMessage = "Failed to send password reset email. Please try again.";
      }
      _showSnackbar(errorMessage, SnackbarType.error);
    } catch (e) {
      _showSnackbar("An unexpected error occurred. Please try again later.", SnackbarType.error);
    } finally {
      setState(() => isResettingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2C5282),
              Color(0xFF3182CE),
              Color(0xFFE3F2FD),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                elevation: 16,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: Colors.white,
                shadowColor: Colors.black.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.radar,
                              size: 40,
                              color: Colors.blue[800],
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'RADAR DASHBOARD',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.blue[800],
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Rapid Action for Disaster Aid Resource',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Title
                        Text(
                          isLogin ? 'SIGN IN TO DASHBOARD' : 'CREATE ACCOUNT',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Email
                        _buildTextField(
                          label: 'EMAIL ADDRESS',
                          fieldName: 'email',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                          onSaved: (val) => email = val!.trim(),
                        ),
                        const SizedBox(height: 20),

                        // Password
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTextField(
                              label: 'PASSWORD',
                              fieldName: 'password',
                              obscure: obscurePassword,
                              prefixIcon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                    () => obscurePassword = !obscurePassword),
                              ),
                              onSaved: (val) => password = val!,
                              onChanged: (val) {
                                setState(() {
                                  password = val;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            if (!isLogin && password.isNotEmpty)
                              AdvancedPasswordStrengthIndicator(
                                password: password,
                                passwordManager: _passwordManager,
                              ),
                          ],
                        ),

                        // Forgot Password link (only shown in login mode)
                        if (isLogin) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: isResettingPassword
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.0),
                                    child: SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : TextButton(
                                    onPressed: _resetPassword,
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                          ),
                        ],

                        if (!isLogin) ...[
                          const SizedBox(height: 20),
                          _buildTextField(
                            label: 'CONFIRM PASSWORD',
                            fieldName: 'confirmPassword',
                            obscure: obscureConfirmPassword,
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                              onPressed: () => setState(() =>
                                  obscureConfirmPassword =
                                  !obscureConfirmPassword),
                            ),
                            onSaved: (val) => confirmPassword = val!,
                            onChanged: (val) {
                              setState(() {
                                confirmPassword = val;
                              });
                            },
                          ),
                          const SizedBox(height: 20),

                          // Personal Info
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'PERSONAL INFORMATION',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          _buildTextField(
                            label: 'FIRST NAME',
                            fieldName: 'firstName',
                            keyboardType: TextInputType.name,
                            prefixIcon: Icons.person_outline,
                            onSaved: (val) => firstName = val!,
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            label: 'LAST NAME',
                            fieldName: 'lastName',
                            keyboardType: TextInputType.name,
                            prefixIcon: Icons.person_outline,
                            onSaved: (val) => lastName = val!,
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            label: 'PHONE NUMBER',
                            fieldName: 'phoneNumber',
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone_outlined,
                            onSaved: (val) => phoneNumber = val!,
                          ),
                          const SizedBox(height: 16),

                          // DOB
                          InkWell(
                            onTap: () => _selectDate(context),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'DATE OF BIRTH',
                                labelStyle: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                                prefixIcon: Icon(
                                  Icons.calendar_today_outlined,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                enabledBorder: OutlineInputBorder(
                                  borderSide:
                                  BorderSide(color: Colors.grey[400]!),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                      color: Colors.blue, width: 2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dateOfBirth != null
                                        ? DateFormat('MMM dd, yyyy')
                                        .format(dateOfBirth!)
                                        : 'Select your date of birth',
                                    style: TextStyle(
                                      color: dateOfBirth != null
                                          ? Colors.black87
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  Icon(Icons.arrow_drop_down,
                                      color: Colors.grey[600]),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Enhanced Terms and Conditions with modern design
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: termsAccepted ? Colors.green.shade50 : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: termsAccepted ? Colors.green.shade200 : Colors.blue.shade200,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: termsAccepted,
                                  onChanged: (bool? value) {
                                    if (value == true) {
                                      _showTermsPreview();
                                    } else {
                                      setState(() {
                                        termsAccepted = false;
                                        showTermsError = false;
                                      });
                                    }
                                  },
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  fillColor: MaterialStateProperty.resolveWith<Color>(
                                        (Set<MaterialState> states) {
                                      if (states.contains(MaterialState.selected)) {
                                        return Colors.blue.shade700;
                                      }
                                      return Colors.grey.shade300;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: _showTermsPreview,
                                        child: Row(
                                          children: [
                                            Text(
                                              'I accept the Terms and Conditions',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue.shade800,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Icon(
                                              Icons.open_in_new,
                                              color: Colors.blue.shade600,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        termsAccepted 
                                            ? "✓ Terms accepted successfully"
                                            : "Tap to review our terms and conditions",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: termsAccepted ? Colors.green.shade700 : Colors.grey.shade600,
                                          fontStyle: termsAccepted ? FontStyle.normal : FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (termsAccepted)
                                  Icon(
                                    Icons.verified,
                                    color: Colors.green.shade600,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),

                          if (showTermsError && !termsAccepted)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.only(left: 8.0, top: 4.0),
                                child: Text(
                                  "You must accept the terms and conditions",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],

                        const SizedBox(height: 10),

                        // Submit Button
                        isLoading
                            ? const CircularProgressIndicator(color: Colors.blue)
                            : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            onPressed: _submit,
                            child: Text(
                              isLogin ? 'SIGN IN' : 'CREATE ACCOUNT',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Toggle
                        TextButton(
                          onPressed: isLoading ? null : () => setState(() {
                            isLogin = !isLogin;
                            showTermsError = false;
                            _resetForm();
                          }),
                          child: Text(
                            isLogin
                                ? 'Need an account? Register here'
                                : 'Already have an account? Sign in here',
                            style: TextStyle(
                              color: isLoading ? Colors.grey : Colors.blue[700],
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),
                        // Footer
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Text(
                            '🚨 Emergency Monitoring System\nStay connected for real-time disaster response',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String fieldName,
    TextInputType? keyboardType,
    bool obscure = false,
    IconData? prefixIcon,
    Widget? suffixIcon,
    void Function(String?)? onSaved,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      style: const TextStyle(color: Colors.black87),
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: (value) => _validateField(fieldName, value),
      onSaved: onSaved,
      onChanged: onChanged,
      onTap: () => _markFieldTouched(fieldName),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: Colors.grey[600], size: 20)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey[50],
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blue, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

// Enhanced Password Security Manager with Google-like logic
class PasswordSecurityManager {
  final RegExp _passwordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$'
  );

  // Common passwords list (in real app, this would be much larger and possibly fetched from server)
  final Set<String> _commonPasswords = {
    'password', '123456', '12345678', '123456789', '1234567890',
    'qwerty', 'abc123', 'password1', 'admin', 'welcome',
    'monkey', 'letmein', 'dragon', 'baseball', 'football',
    'master', 'hello', 'freedom', 'whatever', 'qwerty123'
  };

  PasswordValidationResult validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return PasswordValidationResult(
        isValid: false,
        errorMessage: 'Password is required',
      );
    }

    // Length check
    if (password.length < 8) {
      return PasswordValidationResult(
        isValid: false,
        errorMessage: 'Password must be at least 8 characters long',
      );
    }

    // Common password check
    if (_commonPasswords.contains(password.toLowerCase())) {
      return PasswordValidationResult(
        isValid: false,
        errorMessage: 'This password is too common. Please choose a more unique password.',
      );
    }

    // Complexity requirements (Google-like)
    if (!_passwordRegex.hasMatch(password)) {
      return PasswordValidationResult(
        isValid: false,
        errorMessage: 'Password must include uppercase, lowercase, number, and special character (@\$!%*?&)',
      );
    }

    // Sequential characters check
    if (_hasSequentialCharacters(password)) {
      return PasswordValidationResult(
        isValid: false,
        errorMessage: 'Password contains sequential characters (like 123, abc)',
      );
    }

    // Repeated characters check
    if (_hasRepeatedCharacters(password)) {
      return PasswordValidationResult(
        isValid: false,
        errorMessage: 'Password contains too many repeated characters',
      );
    }

    return PasswordValidationResult(isValid: true);
  }

  SecurityCheckResult performSecurityChecks({
    required String password,
    required String email,
    required String firstName,
    required String lastName,
  }) {
    // Check if password contains personal information
    if (_containsPersonalInfo(password, email, firstName, lastName)) {
      return SecurityCheckResult(
        isSecure: false,
        message: 'Password should not contain your name, email, or other personal information',
      );
    }

    // Check password strength score
    final strength = calculatePasswordStrength(password);
    if (strength < 3) {
      return SecurityCheckResult(
        isSecure: false,
        message: 'Password is too weak. Please choose a stronger password',
      );
    }

    // Check for keyboard patterns
    if (_containsKeyboardPatterns(password)) {
      return SecurityCheckResult(
        isSecure: false,
        message: 'Password contains common keyboard patterns',
      );
    }

    return SecurityCheckResult(isSecure: true, message: 'Password meets security requirements');
  }

  bool _hasSequentialCharacters(String password) {
    // Check for sequential numbers
    for (int i = 0; i < password.length - 2; i++) {
      final current = password.codeUnitAt(i);
      final next = password.codeUnitAt(i + 1);
      final nextNext = password.codeUnitAt(i + 2);
      
      if (next == current + 1 && nextNext == current + 2) {
        return true;
      }
      if (next == current - 1 && nextNext == current - 2) {
        return true;
      }
    }
    return false;
  }

  bool _hasRepeatedCharacters(String password) {
    // Check for 3 or more repeated characters
    for (int i = 0; i < password.length - 2; i++) {
      if (password[i] == password[i + 1] && password[i] == password[i + 2]) {
        return true;
      }
    }
    return false;
  }

  bool _containsPersonalInfo(String password, String email, String firstName, String lastName) {
    final cleanPassword = password.toLowerCase();
    final cleanEmail = email.split('@').first.toLowerCase();
    final cleanFirstName = firstName.toLowerCase();
    final cleanLastName = lastName.toLowerCase();

    if (cleanPassword.contains(cleanEmail) && cleanEmail.length > 2) return true;
    if (cleanPassword.contains(cleanFirstName) && cleanFirstName.length > 2) return true;
    if (cleanPassword.contains(cleanLastName) && cleanLastName.length > 2) return true;
    
    return false;
  }

  bool _containsKeyboardPatterns(String password) {
    const patterns = [
      'qwerty', 'asdfgh', 'zxcvbn', '123456', '!@#\$%^',
      'qazwsx', 'edcrfv', 'tgbnhy', 'yhnujm', '1qaz2wsx'
    ];
    
    final cleanPassword = password.toLowerCase();
    return patterns.any((pattern) => cleanPassword.contains(pattern));
  }

  bool isCommonPassword(String password) {
    return _commonPasswords.contains(password.toLowerCase());
  }

  int calculatePasswordStrength(String password) {
    int strength = 0;
    
    // Length bonus
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;
    if (password.length >= 16) strength++;
    
    // Character type bonuses
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[a-z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;
    
    // Deductions for weak patterns
    if (_hasSequentialCharacters(password)) strength = strength > 0 ? strength - 1 : 0;
    if (_hasRepeatedCharacters(password)) strength = strength > 0 ? strength - 1 : 0;
    if (isCommonPassword(password)) strength = 0;
    
    return strength.clamp(0, 5);
  }

  String generatePasswordHash(String password) {
    // In a real app, this would use proper hashing like bcrypt
    // This is a simplified version for demonstration
    return 'hash_${password.length}_${DateTime.now().millisecondsSinceEpoch}';
  }
}

// Advanced Password Strength Indicator with detailed feedback
class AdvancedPasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final PasswordSecurityManager passwordManager;

  const AdvancedPasswordStrengthIndicator({
    super.key,
    required this.password,
    required this.passwordManager,
  });

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final strength = passwordManager.calculatePasswordStrength(password);
    final requirements = _getPasswordRequirements(password);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Strength',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: strength / 5,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation(_getStrengthColor(strength)),
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            _getStrengthLabel(strength),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _getStrengthColor(strength),
            ),
          ),
          const SizedBox(height: 8),
          ...requirements.map((req) => _buildRequirementRow(req)),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(PasswordRequirement req) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            req.met ? Icons.check_circle : Icons.radio_button_unchecked,
            color: req.met ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            req.description,
            style: TextStyle(
              fontSize: 11,
              color: req.met ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  List<PasswordRequirement> _getPasswordRequirements(String password) {
    return [
      PasswordRequirement(
        met: password.length >= 8,
        description: 'At least 8 characters',
      ),
      PasswordRequirement(
        met: RegExp(r'[A-Z]').hasMatch(password),
        description: 'One uppercase letter',
      ),
      PasswordRequirement(
        met: RegExp(r'[a-z]').hasMatch(password),
        description: 'One lowercase letter',
      ),
      PasswordRequirement(
        met: RegExp(r'[0-9]').hasMatch(password),
        description: 'One number',
      ),
      PasswordRequirement(
        met: RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password),
        description: 'One special character',
      ),
      PasswordRequirement(
        met: !passwordManager.isCommonPassword(password),
        description: 'Not a common password',
      ),
    ];
  }

  Color _getStrengthColor(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStrengthLabel(int strength) {
    switch (strength) {
      case 0:
        return "Very Weak";
      case 1:
        return "Weak";
      case 2:
        return "Fair";
      case 3:
        return "Good";
      case 4:
        return "Strong";
      case 5:
        return "Very Strong";
      default:
        return "Unknown";
    }
  }
}

// Data Classes
class PasswordValidationResult {
  final bool isValid;
  final String? errorMessage;

  PasswordValidationResult({
    required this.isValid,
    this.errorMessage,
  });
}

class RegistrationValidationResult {
  final bool isValid;
  final String? errorMessage;

  RegistrationValidationResult({
    required this.isValid,
    this.errorMessage,
  });
}

class SecurityCheckResult {
  final bool isSecure;
  final String message;

  SecurityCheckResult({
    required this.isSecure,
    required this.message,
  });
}

class PasswordRequirement {
  final bool met;
  final String description;

  PasswordRequirement({
    required this.met,
    required this.description,
  });
}