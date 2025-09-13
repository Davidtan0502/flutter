import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  String email = '';
  String password = '';
  String confirmPassword = '';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => isLoading = true);

    try {
      if (isLogin) {
        // LOGIN FLOW
        final result = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (!result.user!.emailVerified) {
          _showSnackbar("Please verify your email before logging in.");
          await _auth.signOut();
          return;
        }

        final userDoc = await _firestore
            .collection('dashboard_users')
            .doc(result.user!.uid)
            .get();

        if (!userDoc.exists) {
          _showSnackbar('Account not registered in dashboard.');
          return;
        }

        final userRole = userDoc.data()?['role'];
        if (userRole != 'admin' && userRole != 'user') {
          _showSnackbar('Invalid user role.');
          return;
        }

        _showSnackbar('Login successful! Redirecting...');
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pushReplacementNamed(context, '/$userRole-dashboard');
      } else {
        // REGISTER FLOW
        if (password != confirmPassword) {
          _showSnackbar('Passwords do not match.');
          return;
        }

        final result = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // 🔹 Force default role = user
        const assignedRole = 'user';

        await _firestore.collection('dashboard_users').doc(result.user!.uid).set({
          'uid': result.user!.uid,
          'email': email,
          'role': assignedRole,
          'createdAt': Timestamp.now(),
        });

        // 🔹 Send email verification
        await result.user!.sendEmailVerification();

        _showSnackbar(
          "Account created! Please verify your email before signing in.",
        );

        // 🔹 Force logout until verified
        await _auth.signOut();

        // Back to login mode
        setState(() {
          isLogin = true;
        });
      }
    } on FirebaseAuthException catch (e) {
      _showSnackbar(e.message ?? 'Authentication failed.');
    } catch (e) {
      _showSnackbar('Something went wrong.');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.black87,
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
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
              Color(0xFF2C5282), // Dark blue
              Color(0xFF3182CE), // Medium blue
              Color(0xFFE3F2FD), // Light blue
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
                        // Header with Icon
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

                        // Email Field
                        _buildTextField(
                          label: 'EMAIL ADDRESS',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                          validator: (val) =>
                              val != null && val.contains('@') && val.contains('.')
                                  ? null
                                  : 'Enter a valid email address',
                          onSaved: (val) => email = val!.trim(),
                        ),
                        const SizedBox(height: 20),

                        // Password Field
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
                            onPressed: () =>
                                setState(() => obscurePassword = !obscurePassword),
                          ),
                          validator: (val) => val != null && val.length >= 6
                              ? null
                              : 'Minimum 6 characters required',
                          onSaved: (val) => password = val!,
                        ),

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
                                  obscureConfirmPassword = !obscureConfirmPassword),
                            ),
                            validator: (val) => val != null && val.length >= 6
                                ? null
                                : 'Re-enter your password',
                            onSaved: (val) => confirmPassword = val!,
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

                        // Toggle between Login/Register
                        TextButton(
                          onPressed: () => setState(() => isLogin = !isLogin),
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
                        // Footer Note
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
  }) {
    return TextFormField(
      style: const TextStyle(color: Colors.black87),
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      onSaved: onSaved,
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
