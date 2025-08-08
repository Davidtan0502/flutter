import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({super.key});

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;

  bool isLogin = true;
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  String email = '';
  String password = '';
  String confirmPassword = '';
  String role = 'user';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: const Color(0xFF2C5282),
      end: const Color.fromARGB(255, 29, 56, 88),
    ).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => isLoading = true);

    try {
      if (isLogin) {
        final result = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final userDoc = await _firestore
            .collection('dashboard_users')
            .doc(result.user!.uid)
            .get();

        if (!userDoc.exists || userDoc['role'] == null) {
          _showSnackbar('User role not found.');
          return;
        }

        final userRole = userDoc['role'];
        _showSnackbar('Login successful! Redirecting...');
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pushReplacementNamed(context, '/$userRole-dashboard');
      } else {
        if (password != confirmPassword) {
          _showSnackbar('Passwords do not match.');
          return;
        }

        final result = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await _firestore.collection('dashboard_users').doc(result.user!.uid).set({
          'uid': result.user!.uid,
          'email': email,
          'role': role,
          'createdAt': Timestamp.now(),
        });

        _showSnackbar('Account created! Redirecting...');
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pushReplacementNamed(context, '/$role-dashboard');
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
          style: const TextStyle(color: Colors.white, fontFamily: 'Arial'),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) => Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_colorAnimation.value ?? Colors.black, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('RADAR: Rapid Action for Disaster Aid Resource',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
                                  color: Colors.black,
                                  fontFamily: 'Arial',
                                )),
                        const SizedBox(height: 8),
                        Text('Stay Alert, Stay Alive!',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 16,
                              fontFamily: 'Arial',
                            )),
                        const SizedBox(height: 24),
                        Text(
                          isLogin ? 'Welcome Back' : 'Create Account',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Arial',
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(
                          label: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) =>
                              val != null && val.contains('@') && val.contains('.')
                                  ? null
                                  : 'Enter a valid email',
                          onSaved: (val) => email = val!.trim(),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Password',
                          obscure: obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.black,
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
                          const SizedBox(height: 16),
                          _buildTextField(
                            label: 'Confirm Password',
                            obscure: obscureConfirmPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.black,
                              ),
                              onPressed: () => setState(() =>
                                  obscureConfirmPassword = !obscureConfirmPassword),
                            ),
                            validator: (val) => val != null && val.length >= 6
                                ? null
                                : 'Re-enter your password',
                            onSaved: (val) => confirmPassword = val!,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: role,
                            dropdownColor: Colors.white,
                            decoration: const InputDecoration(
                              labelText: 'Select Role',
                              labelStyle: TextStyle(color: Colors.black),
                            ),
                            style: const TextStyle(
                                color: Colors.black, fontFamily: 'Arial'),
                            items: const [
                              DropdownMenuItem(
                                value: 'user',
                                child: Text('User',
                                    style: TextStyle(color: Colors.black)),
                              ),
                              DropdownMenuItem(
                                value: 'admin',
                                child: Text('Admin',
                                    style: TextStyle(color: Colors.black)),
                              ),
                            ],
                            onChanged: (val) => setState(() => role = val!),
                          ),
                        ],
                        const SizedBox(height: 32),
                        isLoading
                            ? const CircularProgressIndicator(color: Colors.black)
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 40, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _submit,
                                child: Text(
                                  isLogin ? 'Login' : 'Register',
                                  style: const TextStyle(
                                      fontFamily: 'Arial',
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() => isLogin = !isLogin),
                          child: Text(
                            isLogin
                                ? 'Don\'t have an account? Register'
                                : 'Already have an account? Login',
                            style: const TextStyle(
                              color: Colors.black,
                              fontFamily: 'Arial',
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Road Safety: A Small Effort, A Big Difference. Slow Down, Save Lives.',
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 12,
                            fontFamily: 'Arial',
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
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
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
  }) {
    return TextFormField(
      style: const TextStyle(color: Colors.black, fontFamily: 'Arial'),
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      onSaved: onSaved,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black, fontFamily: 'Arial'),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.black),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
