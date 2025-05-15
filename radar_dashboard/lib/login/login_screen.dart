import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool showSignUp = false;
  bool showPassword = false;
  bool showConfirmPassword = false;

  // Controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final signupEmailController = TextEditingController();
  final signupPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // Constants
  static const primaryColor = Color(0xFF007BFF);
  static const secondaryColor = Color(0xFF0056b3);
  static const backgroundColor = Color(0xFFF6F5F7);
  static const inputFillColor = Color(0xFFefefef);
  static const panelAnimationDuration = Duration(milliseconds: 600);
  static const panelAnimationCurve = Curves.easeInOut;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    signupEmailController.dispose();
    signupPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Container(
          width: 800,
          height: 500,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: const [
              BoxShadow(
                blurRadius: 10,
                color: Colors.black12,
                spreadRadius: 2,
              )
            ],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              // Sign In Panel
              AnimatedPositioned(
                duration: panelAnimationDuration,
                curve: panelAnimationCurve,
                left: showSignUp ? -screenWidth : 0,
                child: _buildSignInPanel(),
              ),
              // Sign Up Panel
              AnimatedPositioned(
                duration: panelAnimationDuration,
                curve: panelAnimationCurve,
                left: showSignUp ? 0 : screenWidth,
                child: _buildSignUpPanel(),
              ),
              // Side Panel Switcher
              AnimatedAlign(
                duration: panelAnimationDuration,
                curve: panelAnimationCurve,
                alignment: showSignUp ? Alignment.centerLeft : Alignment.centerRight,
                child: _buildSidePanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidePanel() {
    return SizedBox(
      width: 400,
      height: 500,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 80, color: Colors.white),
                const SizedBox(height: 20),
                Text(
                  showSignUp ? "Welcome Back!" : "Hello, Friend!",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  showSignUp
                      ? "Already have an account?"
                      : "Enter your personal details",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => setState(() => showSignUp = !showSignUp),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    showSignUp ? "Sign In" : "Sign Up",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInPanel() {
    return SizedBox(
      width: 400,
      height: 500,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Sign In",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildInput(
              icon: Icons.email,
              hint: "Email",
              controller: emailController,
            ),
            _buildInput(
              icon: Icons.lock,
              hint: "Password",
              controller: passwordController,
              isPassword: true,
              isObscure: !showPassword,
              toggle: () => setState(() => showPassword = !showPassword),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: primaryColor,
              ),
              child: const Text("Sign In"),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {},
              child: const Text("Forgot your password?"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpPanel() {
    return SizedBox(
      width: 400,
      height: 500,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Sign Up",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildInput(
              icon: Icons.email,
              hint: "Email",
              controller: signupEmailController,
            ),
            _buildInput(
              icon: Icons.lock,
              hint: "Password",
              controller: signupPasswordController,
              isPassword: true,
              isObscure: !showPassword,
              toggle: () => setState(() => showPassword = !showPassword),
            ),
            _buildInput(
              icon: Icons.lock,
              hint: "Confirm Password",
              controller: confirmPasswordController,
              isPassword: true,
              isObscure: !showConfirmPassword,
              toggle: () => setState(() => showConfirmPassword = !showConfirmPassword),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: primaryColor,
              ),
              child: const Text("Sign Up"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    bool isPassword = false,
    bool isObscure = false,
    VoidCallback? toggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: isPassword && isObscure,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isObscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: toggle,
                )
              : null,
          hintText: hint,
          filled: true,
          fillColor: inputFillColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 20,
          ),
        ),
      ),
    );
  }
}