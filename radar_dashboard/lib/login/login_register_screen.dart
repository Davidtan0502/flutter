import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:radar_dashboard/login/terms_and_condition.dart';

// Define snackbar types for different styling (moved outside class)
enum SnackbarType { success, error, warning, info }

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({super.key});

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLogin = true;
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool termsAccepted = false;
  bool showTermsError = false;

  // Form fields
  String email = '';
  String password = '';
  String confirmPassword = '';
  String firstName = '';
  String lastName = '';
  String phoneNumber = '';
  DateTime? dateOfBirth;

  // Security features
  bool _isPasswordStrong = false;
  final RegExp _passwordRegex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$');

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (!isLogin) {
      if (!termsAccepted) {
        setState(() => showTermsError = true);
        _showSnackbar("Please accept the terms and conditions to continue", SnackbarType.error);
        return;
      }
      if (!_isPasswordStrong) {
        _showSnackbar("Password must include uppercase, lowercase, number, and special character", SnackbarType.error);
        return;
      }
      if (password != confirmPassword) {
        _showSnackbar('Passwords do not match. Please check and try again.', SnackbarType.error);
        return;
      }
    }

    setState(() {
      isLoading = true;
      showTermsError = false;
    });

    try {
      if (isLogin) {
        // LOGIN FLOW
        final result = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (!result.user!.emailVerified) {
          _showSnackbar("Please verify your email before logging in. Check your inbox for the verification link.", SnackbarType.warning);
          await _auth.signOut();
          return;
        }

        final userDoc = await _firestore
            .collection('dashboard_users')
            .doc(result.user!.uid)
            .get();

        if (!userDoc.exists) {
          _showSnackbar('Account not found. Please register first.', SnackbarType.error);
          return;
        }

        final userRole = userDoc.data()?['role'];
        if (userRole != 'admin' && userRole != 'user') {
          _showSnackbar('Access denied. Invalid user permissions.', SnackbarType.error);
          return;
        }

        _showSnackbar('Login successful! Redirecting to dashboard...', SnackbarType.success);
        await Future.delayed(const Duration(seconds: 1));

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/$userRole-dashboard');
      } else {
        // REGISTER FLOW
        final result = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        const assignedRole = 'user';
        await _firestore.collection('dashboard_users').doc(result.user!.uid).set({
          'uid': result.user!.uid,
          'email': email,
          'role': assignedRole,
          'personal_details': {
            'firstName': firstName,
            'lastName': lastName,
            'phoneNumber': phoneNumber,
            'dateOfBirth':
                dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
            'lastUpdated': Timestamp.now(),
          },
          'security': {
            'passwordStrength': _calculatePasswordStrength(password),
            'accountCreated': Timestamp.now(),
            'lastPasswordChange': Timestamp.now(),
          },
          'createdAt': Timestamp.now(),
        });

        await result.user!.sendEmailVerification();

        _showSnackbar(
          "Account created successfully! Please check your email for verification instructions.",
          SnackbarType.success,
        );

        await _auth.signOut();
        setState(() {
          isLogin = true;
        });
      }
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors with user-friendly messages
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = "No account found with this email address. Please check your email or register for a new account.";
          break;
        case 'wrong-password':
          errorMessage = "Incorrect password. Please try again or use the 'Forgot Password' option if you can't remember.";
          break;
        case 'invalid-email':
          errorMessage = "Invalid email address format. Please check and try again.";
          break;
        case 'user-disabled':
          errorMessage = "This account has been disabled. Please contact support for assistance.";
          break;
        case 'email-already-in-use':
          errorMessage = "This email is already registered. Please sign in instead or use a different email address.";
          break;
        case 'operation-not-allowed':
          errorMessage = "Email/password accounts are not enabled. Please contact support.";
          break;
        case 'weak-password':
          errorMessage = "Password is too weak. Please choose a stronger password with at least 8 characters including uppercase, lowercase, numbers, and special characters.";
          break;
        case 'network-request-failed':
          errorMessage = "Network connection failed. Please check your internet connection and try again.";
          break;
        case 'too-many-requests':
          errorMessage = "Too many unsuccessful login attempts. Please try again later or reset your password.";
          break;
        case 'invalid-credential':
          errorMessage = "The authentication credential is invalid. Please check your email and password.";
          break;
        default:
          errorMessage = "Authentication failed. Please check your credentials and try again.";
      }
      _showSnackbar(errorMessage, SnackbarType.error);
    } catch (e) {
      _showSnackbar('An unexpected error occurred. Please try again later.', SnackbarType.error);
    } finally {
      setState(() => isLoading = false);
    }
  }

  int _calculatePasswordStrength(String password) {
    int strength = 0;
    if (password.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[a-z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;
    return strength;
  }

  void _showSnackbar(String message, SnackbarType type) {
    Color backgroundColor = Colors.grey.shade700; // Default color
    IconData icon = Icons.info_outline; // Default icon
    
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
        duration: const Duration(seconds: 5), // Increased duration for error messages
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

  // Add a password reset function
  Future<void> _resetPassword() async {
    if (email.isEmpty || !email.contains('@')) {
      _showSnackbar("Please enter a valid email address to reset your password", SnackbarType.error);
      return;
    }
    
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showSnackbar("Password reset email sent! Check your inbox for instructions.", SnackbarType.success);
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = "No account found with this email address.";
          break;
        case 'invalid-email':
          errorMessage = "Invalid email address format.";
          break;
        default:
          errorMessage = "Failed to send password reset email. Please try again.";
      }
      _showSnackbar(errorMessage, SnackbarType.error);
    } catch (e) {
      _showSnackbar("An error occurred. Please try again later.", SnackbarType.error);
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
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                          validator: (val) => val != null &&
                                  val.contains('@') &&
                                  val.contains('.')
                              ? null
                              : 'Enter a valid email address',
                          onSaved: (val) => email = val!.trim(),
                        ),
                        const SizedBox(height: 20),

                        // Password
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTextField(
                              label: 'PASSWORD',
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
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Password is required';
                                }
                                if (val.length < 8) {
                                  return 'Minimum 8 characters required';
                                }
                                if (!_passwordRegex.hasMatch(val)) {
                                  return 'Include uppercase, lowercase, number & special character';
                                }
                                return null;
                              },
                              onChanged: (val) {
                                setState(() {
                                  _isPasswordStrong =
                                      _passwordRegex.hasMatch(val);
                                });
                              },
                              onSaved: (val) => password = val!,
                            ),
                            const SizedBox(height: 8),
                            if (!isLogin)
                              PasswordStrengthIndicator(
                                strength:
                                    _calculatePasswordStrength(password),
                              ),
                          ],
                        ),

                        // Forgot Password link (only shown in login mode)
                        if (isLogin) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
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
                            validator: (val) =>
                                val != null && val == password
                                    ? null
                                    : 'Passwords do not match',
                            onSaved: (val) => confirmPassword = val!,
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
                            keyboardType: TextInputType.name,
                            prefixIcon: Icons.person_outline,
                            validator: (val) => val != null && val.length >= 2
                                ? null
                                : 'Enter a valid first name',
                            onSaved: (val) => firstName = val!,
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            label: 'LAST NAME',
                            keyboardType: TextInputType.name,
                            prefixIcon: Icons.person_outline,
                            validator: (val) => val != null && val.length >= 2
                                ? null
                                : 'Enter a valid last name',
                            onSaved: (val) => lastName = val!,
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            label: 'PHONE NUMBER',
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone_outlined,
                            validator: (val) => val != null && val.length >= 10
                                ? null
                                : 'Enter a valid phone number',
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

                          // Terms and Conditions
                          Row(
                            children: [
                              Checkbox(
                                value: termsAccepted,
                                onChanged: null, // Disabled manually
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final agreed = await Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (context, animation, secondaryAnimation) =>
                                            const TermsAndConditionsScreen(),
                                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                          return FadeTransition(
                                            opacity: CurvedAnimation(
                                              parent: animation,
                                              curve: Curves.easeInOut,
                                            ),
                                            child: child,
                                          );
                                        },
                                        transitionDuration: const Duration(milliseconds: 400),
                                      ),
                                    );

                                    if (agreed == true) {
                                      setState(() {
                                        termsAccepted = true;
                                        showTermsError = false;
                                      });
                                    }
                                  },
                                  child: const Text(
                                    'I accept the terms and conditions',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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

                        const SizedBox(height: 28),

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
                          onPressed: () => setState(() {
                            isLogin = !isLogin;
                            showTermsError = false;
                          }),
                          child: Text(
                            isLogin
                                ? 'Need an account? Register here'
                                : 'Already have an account? Sign in here',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
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
    TextInputType? keyboardType,
    bool obscure = false,
    IconData? prefixIcon,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      style: const TextStyle(color: Colors.black87),
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      onSaved: onSaved,
      onChanged: onChanged,
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

class PasswordStrengthIndicator extends StatelessWidget {
  final int strength;

  const PasswordStrengthIndicator({super.key, required this.strength});

  @override
  Widget build(BuildContext context) {
    if (strength == 0) {
      return const SizedBox.shrink();
    }

    List<Color> colors = [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.lightGreen,
      Colors.green
    ];
    List<String> labels = [
      "Very Weak",
      "Weak",
      "Fair",
      "Strong",
      "Very Strong"
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Password Strength",
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: strength / 5,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation(colors[strength - 1]),
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 4),
        Text(
          labels[strength - 1],
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors[strength - 1],
          ),
        ),
      ],
    );
  }
}