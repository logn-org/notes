import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart'; // Import AuthService

// --- screens/login_screen.dart ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false; // State to manage loading indicator

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      await authService.signInWithGoogle();
      // Navigation is handled by AuthWrapper, no need to check result here
    } catch (e) {
      // Error handling is done within AuthService, but you could show a snackbar here too
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign-in failed. Please try again.')),
      );
    } finally {
      // Ensure loading indicator is hidden even if the widget is removed
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Add background styling for a "stunning UI"
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.yellow.shade200, Colors.yellow.shade500], // Adjusted gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo or Title (Example with Icon)
              Icon(
                Icons.lightbulb_outline, // Keep-like icon
                size: 80,
                color: Colors.yellow.shade800,
              ),
              const SizedBox(height: 20),
              Text(
                'Flutter Keep',
                style: TextStyle(
                  fontSize: 36, // Larger font
                  fontWeight: FontWeight.w600, // Slightly less bold
                  color: Colors.grey.shade800,
                  letterSpacing: 1.2, // Add some spacing
                ),
              ),
              const SizedBox(height: 60), // Increased spacing

              // Google Sign-In Button with Loading Indicator
              _isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  : ElevatedButton.icon(
                      icon: Image.asset(
                        'assets/google_logo.png', // Ensure this asset exists
                        height: 24.0,
                        // Add errorBuilder for robustness
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.login, size: 24),
                      ),
                      label: const Text('Sign in with Google'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), // Increased padding
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        elevation: 3, // Add slight elevation
                      ),
                      onPressed: _signIn, // Call the _signIn method
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
