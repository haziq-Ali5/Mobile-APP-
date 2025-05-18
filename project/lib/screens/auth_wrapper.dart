import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:project/providers/auth_provider.dart';
import 'package:project/screens/home_screen.dart';
import 'package:project/screens/login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Show splash screen while checking auth state
    if (authProvider.isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }

    // Navigate to home or login based on user state
    return authProvider.user != null ? HomeScreen() : LoginScreen();
  }
}
